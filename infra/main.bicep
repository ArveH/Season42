// The Azure side of the Season42 BFF: a registry to pull the image from, a file share for the
// Logo Store, and the Container App itself.
//
// What this template does NOT own is the substrate it deploys onto — the resource group and the
// Container Apps environment. Those are provisioned once by scripts/azure-setup.sh and passed in
// as parameters. Creating them from here would pull in role assignments and directory-level
// permissions a repository's deploy identity has no business holding, and re-running a template
// that owns the ground it stands on is a much scarier operation than re-running one that does not.
//
// TLS terminates at the Container Apps edge; the container listens on plain HTTP on 8080 and holds
// no certificate (ADR-0010). `allowInsecure: false` below is what keeps cleartext off that edge:
// nothing this server has to say is ever said over http://.

targetScope = 'resourceGroup'

@description('The Container Apps environment to deploy into. Created by scripts/azure-setup.sh; not owned by this template.')
param containerAppEnvironmentName string

@description('Where the registry, the storage account and the app are created. This has to be the Container Apps environment\'s own region — a Container App cannot be created anywhere else — and the default is right whenever the environment is in its own resource group\'s region, which is how scripts/azure-setup.sh creates it. It cannot be read off the environment instead: ARM needs every location resolved before the deployment starts, and an existing resource\'s properties are not known that early.')
param location string = resourceGroup().location

@description('Names the Container App, the managed identity, and the image repository in the registry.')
param appName string = 'season42-bff'

@description('The image the Container App runs. The default is the placeholder Container Apps ships, which is what the very first deployment runs: the registry does not exist until this template has created it, so there is nothing of ours to pull yet. Every deployment after that passes the image it just pushed, so a deployment that leaves this at its default puts the placeholder back.')
param image string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('A TMDB API Read Access Token. Reaches the container as an ACA secret; without one the server refuses to start.')
@secure()
param tmdbAccessToken string

// Where the Azure Files share is mounted inside the container, and what Tmdb:LogoStorePath is
// pointed at. Absolute, so it does not depend on the image's working directory.
var logoStorePath = '/store'

// The registry and the storage account both need a globally unique, lowercase, alphanumeric-only
// name, so both are derived from the resource group rather than asked for. They can share the one
// name because they are in different namespaces. Its length is set by the tighter of the two
// limits: a storage account name may be 24 characters, which 'season42bff' plus a 13-character
// hash is exactly.
var resourceName = 'season42bff${uniqueString(resourceGroup().id)}'
// One name, used three times over: the file share, the environment storage that mounts it, and the
// volume the container mounts. They are three views of the same thing, so they are not three names.
var logoStoreName = 'logostore'

var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d'
)

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2025-01-01' existing = {
  name: containerAppEnvironmentName
}

// A user-assigned identity rather than a system-assigned one, because it has to exist before the
// Container App that uses it: AcrPull is granted to this principal, and the app's first pull
// happens as it is created. A system-assigned identity is only born with the app, which puts the
// grant after the pull that needs it.
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${appName}-identity'
  location: location
}

// ACR rather than GHCR so the app pulls with that managed identity. Admin user off: with it on,
// the registry has a password, and a password that exists is a password that can leak.
resource registry 'Microsoft.ContainerRegistry/registries@2025-04-01' = {
  name: resourceName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

// Whoever deploys this template has to be allowed to write a role assignment, which Contributor
// is not. The deploy identity is therefore also an RBAC Administrator on the resource group,
// under a condition that permits AcrPull and no other role — see stage 7 of scripts/azure-setup.sh.
// ARM re-submits this assignment on every deploy, so the permission is needed even when the
// assignment already exists and the write would change nothing.
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: registry
  name: guid(registry.id, identity.id, acrPullRoleDefinitionId)
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: identity.properties.principalId
    // Stated explicitly so the assignment does not fail while Entra is still catching up with a
    // just-created identity.
    principalType: 'ServicePrincipal'
  }
}

// The Logo Store's disk. It holds a cache and nothing the user owns (ADR-0008) — losing it costs
// fetches — so there is nothing here to back up, and no redundancy beyond the cheapest.
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: resourceName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: logoStoreName
  properties: {
    // The smallest share Azure Files sells. A logo is a few kilobytes and there is one region's
    // worth of them, so this is already orders of magnitude more than the store will ever use.
    shareQuota: 1
  }
}

// Azure Files is SMB, and an account key is the only thing Container Apps can mount it with — the
// one credential in this deployment that has no managed-identity form. It is read here at deploy
// time and never written down: nothing in the repository or in GitHub holds it.
resource logoStoreStorage 'Microsoft.App/managedEnvironments/storages@2025-01-01' = {
  parent: containerAppEnvironment
  name: logoStoreName
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      shareName: logoStoreName
      accessMode: 'ReadWrite'
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2025-01-01' = {
  name: appName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        // External, because the phone is on the internet. TLS terminates here and the container is
        // handed plain HTTP on 8080 (ADR-0010).
        //
        // allowInsecure: false is Container Apps' only cleartext setting, and what it does is
        // answer an http:// request with a 301 to the https:// address. It does not refuse the
        // connection — there is no ACA setting that does — so what the guarantee actually is: no
        // request is ever *served* over cleartext, and the only thing that crosses an http://
        // connection is a redirect with no body. Setting it true would let plain HTTP through to
        // the container, which is the thing being prevented.
        external: true
        targetPort: 8080
        allowInsecure: false
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: identity.id
        }
      ]
      secrets: [
        {
          name: 'tmdb-access-token'
          value: tmdbAccessToken
        }
      ]
    }
    template: {
      containers: [
        {
          name: appName
          image: image
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'Tmdb__AccessToken'
              secretRef: 'tmdb-access-token'
            }
            {
              name: 'Tmdb__LogoStorePath'
              value: logoStorePath
            }
          ]
          volumeMounts: [
            {
              volumeName: logoStoreName
              mountPath: logoStorePath
            }
          ]
          probes: [
            {
              // Liveness only. /health answers for the host and says nothing about the snapshot,
              // deliberately: a replica that has never reached TMDB still answers searches honestly
              // with 503, and calling it unhealthy would turn a degraded service into a dead one
              // (ADR-0010). There is no readiness probe here for the same reason.
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
              }
              initialDelaySeconds: 10
              periodSeconds: 30
            }
          ]
        }
      ]
      volumes: [
        {
          name: logoStoreName
          storageType: 'AzureFile'
          storageName: logoStoreStorage.name
        }
      ]
      scale: {
        // Scaling to zero means a cold start pays the awaited first TMDB fetch, which is the
        // accepted trade: a search is the only thing a stopped BFF costs.
        minReplicas: 0
        // MAX ONE REPLICA IS LOAD-BEARING, NOT A COST DECISION. The Logo Store is
        // write-once-per-path and writes to *.partial before moving into place, but File.Move over
        // SMB is not a local rename; and watch-providers.json is rewritten wholesale every 24 hours
        // by every replica independently. One replica means neither is ever exercised. Before
        // raising this number, revisit the snapshot-write path.
        maxReplicas: 1
      }
    }
  }
  // The one dependency ARM cannot infer, and it is load-bearing: the app pulls its image as it is
  // created, so the grant that lets it pull has to have landed first.
  dependsOn: [
    acrPull
  ]
}

@description('The HTTPS address the app compiles in as its default base URL. Address it as https:// and nothing else: an http:// request gets a redirect and no content.')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('The registry CI pushes to, e.g. season42bffabc123.azurecr.io.')
output registryLoginServer string = registry.properties.loginServer

@description('The registry\'s resource name, for `az acr build` / `az acr login`.')
output registryName string = registry.name

@description('The Container App CI updates the image of.')
output containerAppName string = containerApp.name

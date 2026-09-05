# The BFF as an image: restore, build and publish with the SDK, then run on the chiseled ASP.NET
# runtime. Chiseled because a three-endpoint server has no business shipping a shell, and because
# it runs as a non-root user without being told to.
#
# The image carries no TLS configuration, and that is deliberate: TLS terminates at the fly-proxy
# edge, which hands this container plain HTTP (ADR-0010 for why, ADR-0015 for where).

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# The project file alone first, so a restore is only redone when a dependency changes.
COPY Season42.Bff/Season42.Bff.csproj Season42.Bff/
RUN dotnet restore Season42.Bff/Season42.Bff.csproj

COPY Season42.Bff/ Season42.Bff/
RUN dotnet publish Season42.Bff/Season42.Bff.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0-noble-chiseled AS final
WORKDIR /app
COPY --from=build /app .

# Plain HTTP on 8080. Nothing here holds a certificate.
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Season42.Bff.dll"]

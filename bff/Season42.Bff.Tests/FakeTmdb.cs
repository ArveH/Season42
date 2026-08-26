using System.Net;
using System.Text;

namespace Season42.Bff.Tests;

/// <summary>
/// Stands in for TMDB at the composition root. Every test runs against this: nothing in this
/// test project reaches the network.
/// </summary>
public sealed class FakeTmdb : HttpMessageHandler
{
    private readonly List<HttpRequestMessage> _requests = new();

    public IReadOnlyList<HttpRequestMessage> Requests
    {
        get { lock (_requests) return _requests.ToList(); }
    }

    /// <summary>What the next fetch gets back. Replace to change the answer mid-test.</summary>
    public Func<HttpResponseMessage> Respond { get; set; } = () => Json(DefaultPayload);

    public void RespondWith(string json) => Respond = () => Json(json);

    public void Fail() => Respond = () => new HttpResponseMessage(HttpStatusCode.InternalServerError);

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        lock (_requests) _requests.Add(request);
        return Task.FromResult(Respond());
    }

    private static HttpResponseMessage Json(string body) => new(HttpStatusCode.OK)
    {
        Content = new StringContent(body, Encoding.UTF8, "application/json"),
    };

    /// <summary>
    /// Shaped like TMDB's own answer, per-country priority map and provider ids included, so the
    /// tests can prove what the BFF keeps and what it throws away.
    /// </summary>
    public const string DefaultPayload = """
        {
          "results": [
            {
              "display_priority": 6,
              "logo_path": "/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg",
              "provider_name": "Netflix",
              "provider_id": 8,
              "display_priorities": { "AR": 25, "NO": 6, "US": 8 }
            },
            {
              "display_priority": 2,
              "logo_path": "/97yvRBw1GzX7fXprcF80er19ot.jpg",
              "provider_name": "Disney Plus",
              "provider_id": 337,
              "display_priorities": { "NO": 2, "US": 4 }
            },
            {
              "display_priority": 11,
              "logo_path": "/dQeAar5H991VYporEjUspolDarG.jpg",
              "provider_name": "Apple TV+",
              "provider_id": 350,
              "display_priorities": { "NO": 11 }
            },
            {
              "display_priority": 30,
              "logo_path": "/nEQAdEmJqAeanCkKKJUKAJKNEXW.jpg",
              "provider_name": "NRK TV",
              "provider_id": 383,
              "display_priorities": { "NO": 30 }
            }
          ]
        }
        """;
}

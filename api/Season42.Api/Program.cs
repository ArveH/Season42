var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Fixed test data, served verbatim — the same JSON file the iOS app bundles as its
// first-launch snapshot, copied here from catalog/catalog.json at build time (ADR-0003).
var catalogPath = Path.Combine(AppContext.BaseDirectory, "Data", "catalog.json");

app.MapGet("/catalog", () => Results.File(catalogPath, "application/json"));

app.Run();

public partial class Program;

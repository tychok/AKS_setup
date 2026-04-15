using SampleApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddHealthChecks();

// Register an in-memory product store (replace with a real database in production)
builder.Services.AddSingleton<ProductStore>();

var app = builder.Build();

app.MapControllers();

// Health check endpoints for Kubernetes probes
app.MapHealthChecks("/healthz/ready");
app.MapHealthChecks("/healthz/live");

app.MapGet("/", () => Results.Ok(new { service = "SampleApi", version = "1.0.0" }));

app.Run();

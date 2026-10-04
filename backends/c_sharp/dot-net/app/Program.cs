using Data;
using Microsoft.EntityFrameworkCore;
using Models;

var builder = WebApplication.CreateSlimBuilder(args);
builder.Logging.SetMinimumLevel(LogLevel.Warning);

string Env(string key, string fallback) =>
    Environment.GetEnvironmentVariable(key) is { Length: > 0 } v ? v : fallback;

var connectionString =
    $"Host={Env("DATABASE_HOST", "db")};Port={Env("DATABASE_PORT", "5432")};" +
    $"Database={Env("DATABASE_NAME", "postgres")};Username={Env("DATABASE_USER", "postgres")};" +
    $"Password={Env("DATABASE_PASSWORD", "postgres")};Maximum Pool Size=20";

builder.Services.AddDbContextPool<NoteContext>(o => o.UseNpgsql(connectionString));
builder.WebHost.UseUrls("http://0.0.0.0:8000");

var app = builder.Build();

app.MapGet("/health", async (NoteContext db) =>
{
    try
    {
        await db.Database.MigrateAsync();
        return Results.Text("ok");
    }
    catch (Exception e)
    {
        return Results.Text($"not ready: {e.Message}", statusCode: 503);
    }
});

app.MapGet("/no_db_endpoint/", () => Results.Json(new { message = "No db endpoint" }));

app.MapGet("/notes/", async (NoteContext db, int? limit, int? offset) =>
    await db.Notes.AsNoTracking()
        .OrderBy(n => n.Id)
        .Skip(Math.Max(offset ?? 0, 0))
        .Take(Math.Max(limit ?? 20, 0))
        .ToListAsync());

app.MapGet("/notes/{id:int}", async (NoteContext db, int id) =>
    await db.Notes.AsNoTracking().FirstOrDefaultAsync(n => n.Id == id) is { } note
        ? Results.Ok(note)
        : Results.NotFound("not found"));

app.MapPost("/notes/", async (NoteContext db, Note note) =>
{
    note.Id = 0;
    db.Notes.Add(note);
    await db.SaveChangesAsync();
    return Results.Created($"/notes/{note.Id}", note);
});

app.Run();

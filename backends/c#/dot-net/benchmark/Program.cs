using Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var configuration = builder.Configuration;

builder.Services.AddDbContext<NoteContext>(options =>
    options.UseNpgsql(configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

// Apply migrations
try{
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    var dbContext = services.GetRequiredService<NoteContext>();
    dbContext.Database.Migrate();
    }
}catch (Exception ex)
{
    // Log the exception
    Console.WriteLine($"Migration failed: {ex.Message}");
}

// Custom endpoint for checking if 'note' table exists
app.MapGet("/", async ([FromServices] NoteContext dbContext) =>
{
    var connection = dbContext.Database.GetDbConnection();
    await connection.OpenAsync();
    using var command = connection.CreateCommand();
    command.CommandText = "SELECT 1 FROM information_schema.tables WHERE table_name = 'Notes'";
    var exists = await command.ExecuteScalarAsync();

    if (exists != null)
    {
        return Results.Ok("Server is up and running");
    }
    else
    {
        // Construct a problem response
        return Results.Problem(
            title: "Server error",
            detail: "'note' table does not exist",
            statusCode: 500);
    }
});


app.Run();


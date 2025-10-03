using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;

var builder = WebApplication.CreateBuilder(args);

// Basic configuration
builder.Services.Configure<RouteOptions>(o => o.LowercaseUrls = true);

// Configuration via .env
LoadDotEnv(builder.Environment.ContentRootPath);

// Database configuration from environment
var dbProvider = Environment.GetEnvironmentVariable("DB_PROVIDER")?.Trim().ToLowerInvariant();
var dbHost = Environment.GetEnvironmentVariable("DB_HOST");
var dbPort = Environment.GetEnvironmentVariable("DB_PORT");
var dbName = Environment.GetEnvironmentVariable("DB_NAME");
var dbUser = Environment.GetEnvironmentVariable("DB_USER");
var dbPassword = Environment.GetEnvironmentVariable("DB_PASSWORD");
var dbSslMode = Environment.GetEnvironmentVariable("DB_SSLMODE"); // optional (Postgres)

var dbConfigured = false;

if (dbProvider == "mysql")
{
    var conn = BuildMySqlConnectionString(dbHost, dbPort, dbName, dbUser, dbPassword);
    builder.Services.AddDbContext<MainDbContext>(options =>
        options.UseMySql(conn, ServerVersion.AutoDetect(conn)));
    builder.Services.AddScoped<IUserRepository, EfUserRepository>();
    builder.Services.AddScoped<INewsRepository, EfNewsRepository>();
    dbConfigured = true;
}
else if (dbProvider == "postgres" || dbProvider == "postgresql")
{
    var conn = BuildPostgresConnectionString(dbHost, dbPort, dbName, dbUser, dbPassword, dbSslMode);
    builder.Services.AddDbContext<MainDbContext>(options =>
        options.UseNpgsql(conn));
    builder.Services.AddScoped<IUserRepository, EfUserRepository>();
    builder.Services.AddScoped<INewsRepository, EfNewsRepository>();
    dbConfigured = true;
}

if (!dbConfigured)
{
    // Fallback to in-memory repositories
    builder.Services.AddSingleton<IUserRepository, InMemoryUserRepository>();
    builder.Services.AddSingleton<INewsRepository, InMemoryNewsRepository>();
}

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

// Health
app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

// GML: Custom Auth Integration
app.MapPost("/api/v1/integrations/auth/signin", async (AuthRequest request, IUserRepository users, HttpContext http) =>
{
    if (string.IsNullOrWhiteSpace(request.Login) || string.IsNullOrWhiteSpace(request.Password))
    {
        return Results.Unauthorized(); // 401
    }

    var user = await users.FindByLoginAsync(request.Login);
    if (user is null)
    {
        return Results.NotFound(new { Message = "Пользователь не найден" }); // 404
    }

    if (user.IsBanned)
    {
        var msg = string.IsNullOrWhiteSpace(user.BanReason)
            ? "Пользователь заблокирован"
            : $"Пользователь заблокирован. Причина: {user.BanReason}";
        return Results.StatusCode(StatusCodes.Status403Forbidden, new { Message = msg }); // 403
    }

    // If 2FA is required, GML expects 401 with a specific message prompting 2FA input
    if (user.Require2FA)
    {
        // As per docs, 401 with this message triggers client to ask for 2FA code.
        // Later we can extend the contract to accept and validate a TwoFactorCode.
        return Results.Unauthorized(new { Message = "Введите проверочный код 2FA" }); // 401
    }

    var valid = PasswordHasher.VerifyPassword(request.Password, user.PasswordHash, user.PasswordSalt);
    if (!valid)
    {
        return Results.Unauthorized(new { Message = "Неверный логин или пароль" }); // 401
    }

    // 200 OK — success (response body is optional per docs). Include helpful fields.
    return Results.Ok(new
    {
        Login = user.Login,
        UserUuid = user.UserUuid,
        Message = "Успешная авторизация"
    });
});

// News endpoint for GML import
app.MapGet("/api/news", async (int? limit, int? offset, INewsRepository newsRepo) =>
{
    var items = await newsRepo.GetAsync(limit ?? 10, offset ?? 0);
    var shaped = items.Select(n => new
    {
        id = n.Id,
        title = n.Title,
        description = n.Description,
        createdAt = n.CreatedAt.ToUniversalTime().ToString("o")
    });
    return Results.Ok(shaped);
});

app.Run();

// DTOs and domain below for single-file simplicity. In a real project, split by folders.

record AuthRequest
{
    public string Login { get; init; } = string.Empty;
    public string Password { get; init; } = string.Empty;
}

class User
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Login { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string PasswordSalt { get; set; } = string.Empty;
    public bool Require2FA { get; set; }
    public bool IsBanned { get; set; }
    public string? BanReason { get; set; }
    public Guid UserUuid { get; set; } = Guid.NewGuid();
}

class NewsItem
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

interface IUserRepository
{
    Task<User?> FindByLoginAsync(string login);
}

interface INewsRepository
{
    Task<IReadOnlyList<NewsItem>> GetAsync(int limit, int offset);
}

class InMemoryUserRepository : IUserRepository
{
    private readonly List<User> _users = new();

    public InMemoryUserRepository()
    {
        // Seed: admin (no 2FA), tester (requires 2FA), banned user
        var adminSalt = PasswordHasher.GenerateSalt();
        _users.Add(new User
        {
            Login = "admin",
            PasswordSalt = adminSalt,
            PasswordHash = PasswordHasher.HashPassword("admin123", adminSalt),
            Require2FA = false,
            IsBanned = false
        });

        var testerSalt = PasswordHasher.GenerateSalt();
        _users.Add(new User
        {
            Login = "tester",
            PasswordSalt = testerSalt,
            PasswordHash = PasswordHasher.HashPassword("test123", testerSalt),
            Require2FA = true,
            IsBanned = false
        });

        var bannedSalt = PasswordHasher.GenerateSalt();
        _users.Add(new User
        {
            Login = "banned",
            PasswordSalt = bannedSalt,
            PasswordHash = PasswordHasher.HashPassword("banned123", bannedSalt),
            Require2FA = false,
            IsBanned = true,
            BanReason = "Раздача на спавне"
        });
    }

    public Task<User?> FindByLoginAsync(string login)
    {
        var user = _users.FirstOrDefault(u => string.Equals(u.Login, login, StringComparison.OrdinalIgnoreCase));
        return Task.FromResult(user);
    }
}

class InMemoryNewsRepository : INewsRepository
{
    private readonly List<NewsItem> _items = new();

    public InMemoryNewsRepository()
    {
        _items.Add(new NewsItem { Id = 1, Title = "Заголовок новости", Description = "Содержание новости", CreatedAt = DateTime.UtcNow.AddDays(-2) });
        _items.Add(new NewsItem { Id = 2, Title = "Другая новость", Description = "Текст другой новости", CreatedAt = DateTime.UtcNow.AddDays(-1) });
        _items.Add(new NewsItem { Id = 3, Title = "Третья новость", Description = "Немного текста", CreatedAt = DateTime.UtcNow });
    }

    public Task<IReadOnlyList<NewsItem>> GetAsync(int limit, int offset)
    {
        if (limit < 0) limit = 0;
        if (offset < 0) offset = 0;
        var slice = _items
            .OrderByDescending(n => n.CreatedAt)
            .Skip(offset)
            .Take(limit)
            .ToList();
        return Task.FromResult((IReadOnlyList<NewsItem>)slice);
    }
}

static class PasswordHasher
{
    public static string GenerateSalt()
    {
        var bytes = RandomNumberGenerator.GetBytes(16);
        return Convert.ToBase64String(bytes);
    }

    public static string HashPassword(string password, string salt)
    {
        using var sha256 = SHA256.Create();
        var combined = Encoding.UTF8.GetBytes(password + ":" + salt);
        var hash = sha256.ComputeHash(combined);
        return Convert.ToBase64String(hash);
    }

    public static bool VerifyPassword(string password, string hash, string salt)
    {
        var computed = HashPassword(password, salt);
        return CryptographicOperations.FixedTimeEquals(
            Convert.FromBase64String(hash), Convert.FromBase64String(computed));
    }
}

// Required namespaces
namespace System.Security.Cryptography { }
namespace System.Text { }

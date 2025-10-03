using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;
using Prometheus;

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

// Prometheus metrics
app.UseHttpMetrics();
app.MapMetrics();

// If a database is configured, ensure it exists and seed initial data
using (var scope = app.Services.CreateScope())
{
    var ctx = scope.ServiceProvider.GetService<MainDbContext>();
    if (ctx != null)
    {
        ctx.Database.EnsureCreated();
        SeedDatabase(ctx);
    }
}

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
        var adminLogin = Environment.GetEnvironmentVariable("ADMIN_LOGIN") ?? "admin";
        var adminPassword = Environment.GetEnvironmentVariable("ADMIN_PASSWORD") ?? "admin123";
        bool.TryParse(Environment.GetEnvironmentVariable("ADMIN_REQUIRE2FA"), out var adminRequire2FA);
        bool.TryParse(Environment.GetEnvironmentVariable("ADMIN_IS_BANNED"), out var adminIsBanned);
        var adminBanReason = Environment.GetEnvironmentVariable("ADMIN_BAN_REASON");

        var adminSalt = PasswordHasher.GenerateSalt();
        _users.Add(new User
        {
            Login = adminLogin,
            PasswordSalt = adminSalt,
            PasswordHash = PasswordHasher.HashPassword(adminPassword, adminSalt),
            Require2FA = adminRequire2FA,
            IsBanned = adminIsBanned,
            BanReason = string.IsNullOrWhiteSpace(adminBanReason) ? null : adminBanReason
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


// --- Helpers for .env and connection strings ---
static void LoadDotEnv(string contentRootPath)
{
    try
    {
        var path = Path.Combine(contentRootPath, ".env");
        if (!File.Exists(path)) return;
        foreach (var rawLine in File.ReadAllLines(path))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line)) continue;
            if (line.StartsWith("#")) continue;
            var idx = line.IndexOf('=');
            if (idx <= 0) continue;
            var key = line.Substring(0, idx).Trim();
            var value = line.Substring(idx + 1).Trim();
            // Strip optional surrounding quotes
            if ((value.StartsWith("\"") && value.EndsWith("\"")) || (value.StartsWith("'") && value.EndsWith("'")))
                value = value.Substring(1, value.Length - 2);
            Environment.SetEnvironmentVariable(key, value);
        }
    }
    catch
    {
        // Ignore .env parsing errors on purpose
    }
}

static string BuildMySqlConnectionString(string? host, string? port, string? db, string? user, string? password)
{
    host ??= "localhost";
    port = string.IsNullOrWhiteSpace(port) ? "3306" : port;
    db ??= "exiledcms";
    user ??= "root";
    password ??= string.Empty;
    return $"Server={host};Port={port};Database={db};User={user};Password={password};TreatTinyAsBoolean=true;";
}

static string BuildPostgresConnectionString(string? host, string? port, string? db, string? user, string? password, string? sslMode)
{
    host ??= "localhost";
    port = string.IsNullOrWhiteSpace(port) ? "5432" : port;
    db ??= "exiledcms";
    user ??= "postgres";
    password ??= string.Empty;
    sslMode = string.IsNullOrWhiteSpace(sslMode) ? "Disable" : sslMode;
    return $"Host={host};Port={port};Database={db};Username={user};Password={password};SslMode={sslMode};";
}

// --- EF Core DbContext ---
class MainDbContext : DbContext
{
    public MainDbContext(DbContextOptions<MainDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<NewsItem> News => Set<NewsItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        var user = modelBuilder.Entity<User>();
        user.ToTable("users");
        user.HasKey(u => u.Id);
        user.HasIndex(u => u.Login).IsUnique();
        user.Property(u => u.Login).HasMaxLength(64).IsRequired();
        user.Property(u => u.PasswordHash).HasMaxLength(200).IsRequired();
        user.Property(u => u.PasswordSalt).HasMaxLength(200).IsRequired();
        user.Property(u => u.Require2FA).IsRequired();
        user.Property(u => u.IsBanned).IsRequired();
        user.Property(u => u.BanReason).HasMaxLength(512);
        user.Property(u => u.UserUuid).IsRequired();

        var news = modelBuilder.Entity<NewsItem>();
        news.ToTable("news");
        news.HasKey(n => n.Id);
        news.Property(n => n.Title).HasMaxLength(200).IsRequired();
        news.Property(n => n.Description).HasMaxLength(4000).IsRequired();
        news.Property(n => n.CreatedAt).IsRequired();
    }
}

// --- EF Core Repositories ---
class EfUserRepository : IUserRepository
{
    private readonly MainDbContext _db;
    public EfUserRepository(MainDbContext db) => _db = db;

    public Task<User?> FindByLoginAsync(string login)
    {
        return _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Login.ToLower() == login.ToLower());
    }
}

class EfNewsRepository : INewsRepository
{
    private readonly MainDbContext _db;
    public EfNewsRepository(MainDbContext db) => _db = db;

    public async Task<IReadOnlyList<NewsItem>> GetAsync(int limit, int offset)
    {
        if (limit < 0) limit = 0;
        if (offset < 0) offset = 0;
        var slice = await _db.News
            .AsNoTracking()
            .OrderByDescending(n => n.CreatedAt)
            .Skip(offset)
            .Take(limit)
            .ToListAsync();
        return slice;
    }
}

// --- Database seed ---
static void SeedDatabase(MainDbContext ctx)
{
    if (!ctx.Users.Any())
    {
        var adminLogin = Environment.GetEnvironmentVariable("ADMIN_LOGIN") ?? "admin";
        var adminPassword = Environment.GetEnvironmentVariable("ADMIN_PASSWORD") ?? "admin123";
        bool.TryParse(Environment.GetEnvironmentVariable("ADMIN_REQUIRE2FA"), out var adminRequire2FA);
        bool.TryParse(Environment.GetEnvironmentVariable("ADMIN_IS_BANNED"), out var adminIsBanned);
        var adminBanReason = Environment.GetEnvironmentVariable("ADMIN_BAN_REASON");

        var adminSalt = PasswordHasher.GenerateSalt();
        ctx.Users.Add(new User
        {
            Login = adminLogin,
            PasswordSalt = adminSalt,
            PasswordHash = PasswordHasher.HashPassword(adminPassword, adminSalt),
            Require2FA = adminRequire2FA,
            IsBanned = adminIsBanned,
            BanReason = string.IsNullOrWhiteSpace(adminBanReason) ? null : adminBanReason
        });

        var testerSalt = PasswordHasher.GenerateSalt();
        ctx.Users.Add(new User
        {
            Login = "tester",
            PasswordSalt = testerSalt,
            PasswordHash = PasswordHasher.HashPassword("test123", testerSalt),
            Require2FA = true,
            IsBanned = false
        });

        var bannedSalt = PasswordHasher.GenerateSalt();
        ctx.Users.Add(new User
        {
            Login = "banned",
            PasswordSalt = bannedSalt,
            PasswordHash = PasswordHasher.HashPassword("banned123", bannedSalt),
            Require2FA = false,
            IsBanned = true,
            BanReason = "Раздача на спавне"
        });
    }

    if (!ctx.News.Any())
    {
        ctx.News.AddRange(new[]
        {
            new NewsItem { Id = 1, Title = "Заголовок новости", Description = "Содержание новости", CreatedAt = DateTime.UtcNow.AddDays(-2) },
            new NewsItem { Id = 2, Title = "Другая новость", Description = "Текст другой новости", CreatedAt = DateTime.UtcNow.AddDays(-1) },
            new NewsItem { Id = 3, Title = "Третья новость", Description = "Немного текста", CreatedAt = DateTime.UtcNow }
        });
    }

    ctx.SaveChanges();
}

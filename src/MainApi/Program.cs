using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;
using Prometheus;
using System.Security.Cryptography;
using System.Text;
using Microsoft.OpenApi.Models;
using QRCoder;
using OtpNet;

var builder = WebApplication.CreateBuilder(args);

// Basic configuration
builder.Services.Configure<RouteOptions>(o => o.LowercaseUrls = true);

// Configuration via .env
AppHelpers.LoadDotEnv(builder.Environment.ContentRootPath);



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
    // If using MySQL root user, use the root password from MYSQL_ROOT_PASSWORD to avoid mismatch with DB_PASSWORD
    var effectivePassword = dbPassword;
    if (!string.IsNullOrWhiteSpace(dbUser) && dbUser.Equals("root", StringComparison.OrdinalIgnoreCase))
    {
        var rootPwd = Environment.GetEnvironmentVariable("MYSQL_ROOT_PASSWORD");
        if (!string.IsNullOrWhiteSpace(rootPwd))
        {
            effectivePassword = rootPwd;
        }
    }
    var conn = AppHelpers.BuildMySqlConnectionString(dbHost, dbPort, dbName, dbUser, effectivePassword);
    // Avoid opening a DB connection during service registration (ServerVersion.AutoDetect connects immediately).
    // Use Pomelo's ServerVersion.AutoDetect for broad compatibility across package versions.
    builder.Services.AddDbContext<MainDbContext>(options =>
        options.UseMySql(conn, ServerVersion.AutoDetect(conn)));
    builder.Services.AddScoped<IUserRepository, EfUserRepository>();
    builder.Services.AddScoped<INewsRepository, EfNewsRepository>();
    dbConfigured = true;
}
else if (dbProvider == "postgres" || dbProvider == "postgresql")
{
    var conn = AppHelpers.BuildPostgresConnectionString(dbHost, dbPort, dbName, dbUser, dbPassword, dbSslMode);
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
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "ExiledProject CMS API",
        Version = "v1",
        Description = "Core API for ExiledProject CMS (GML integration, auth, news, health, metrics)."
    });
});

var app = builder.Build();

var swaggerEnabled = string.Equals(Environment.GetEnvironmentVariable("SWAGGER_ENABLED"), "true", StringComparison.OrdinalIgnoreCase);

if (app.Environment.IsDevelopment() || swaggerEnabled)
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "ExiledProject CMS API v1");
        c.RoutePrefix = "swagger"; // served at /swagger
    });
}

// Static files for minimal frontend
app.UseDefaultFiles();
app.UseStaticFiles();

// Optional HTTPS redirection (disabled by default for containers)
var httpsRedirectEnabled = string.Equals(Environment.GetEnvironmentVariable("HTTPS_REDIRECT_ENABLED"), "true", StringComparison.OrdinalIgnoreCase);
if (httpsRedirectEnabled)
{
    app.UseHttpsRedirection();
}

// Prometheus metrics
app.UseHttpMetrics();
app.MapMetrics();

// If a database is configured, ensure it exists and seed initial data
try
{
    using var scope = app.Services.CreateScope();
    var ctx = scope.ServiceProvider.GetService<MainDbContext>();
    if (ctx != null)
    {
        ctx.Database.EnsureCreated();
        AppHelpers.SeedDatabase(ctx);
    }
}
catch (Exception ex)
{
    Console.WriteLine($"[Startup] Warning: database initialization failed: {ex.GetType().Name} - {ex.Message}");
    // Continue running; repository calls may fail until DB becomes available.
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
        return Results.Json(new { Message = msg }, statusCode: StatusCodes.Status403Forbidden); // 403
    }

    // If 2FA is required, GML expects 401 with a specific message prompting 2FA input
    if (user.Require2FA)
    {
        // As per docs, 401 with this message triggers client to ask for 2FA code.
        // Later we can extend the contract to accept and validate a TwoFactorCode.
        return Results.Json(new { Message = "Введите проверочный код 2FA" }, statusCode: StatusCodes.Status401Unauthorized); // 401
    }

    var valid = PasswordHasher.VerifyPassword(request.Password, user.PasswordHash, user.PasswordSalt);
    if (!valid)
    {
        return Results.Json(new { Message = "Неверный логин или пароль" }, statusCode: StatusCodes.Status401Unauthorized); // 401
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
    // 2FA fields
    public string? TwoFactorSecret { get; set; }
    public bool TwoFactorEnabled { get; set; }
    public bool MustSetup2FA { get; set; }
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
    Task UpdateAsync(User user);
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
            Require2FA = false,
            TwoFactorEnabled = false,
            MustSetup2FA = true,
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

    public Task UpdateAsync(User user)
    {
        var existing = _users.FirstOrDefault(u => u.Id == user.Id || string.Equals(u.Login, user.Login, StringComparison.OrdinalIgnoreCase));
        if (existing != null)
        {
            existing.PasswordHash = user.PasswordHash;
            existing.PasswordSalt = user.PasswordSalt;
            existing.Require2FA = user.Require2FA;
            existing.IsBanned = user.IsBanned;
            existing.BanReason = user.BanReason;
            existing.UserUuid = user.UserUuid;
            existing.TwoFactorSecret = user.TwoFactorSecret;
            existing.TwoFactorEnabled = user.TwoFactorEnabled;
            existing.MustSetup2FA = user.MustSetup2FA;
        }
        return Task.CompletedTask;
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
        user.Property(u => u.TwoFactorSecret).HasMaxLength(200);
        user.Property(u => u.TwoFactorEnabled).IsRequired();
        user.Property(u => u.MustSetup2FA).IsRequired();

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

    public async Task UpdateAsync(User user)
    {
        _db.Users.Update(user);
        await _db.SaveChangesAsync();
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

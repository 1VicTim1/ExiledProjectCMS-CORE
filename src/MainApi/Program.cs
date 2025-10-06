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

    // Enforce initial 2FA setup for accounts that must set it up (e.g., first admin login)
    if (user.MustSetup2FA && !user.TwoFactorEnabled)
    {
        return Results.Json(new { Message = "Аккаунт заблокирован до привязки 2FA. Перейдите к настройке двухфакторной аутентификации." }, statusCode: StatusCodes.Status403Forbidden);
    }

    // If 2FA is required, GML expects 401 with a message prompting 2FA input
    if (user.Require2FA)
    {
        return Results.Json(new { Message = "Введите проверочный код 2FA" }, statusCode: StatusCodes.Status401Unauthorized); // 401
    }

    var valid = PasswordHasher.VerifyPassword(request.Password, user.PasswordHash, user.PasswordSalt);
    if (!valid)
    {
        await AppHelpers.LogAuditAsync(null, null, null, "login_fail", $"login={request.Login}", http.Connection.RemoteIpAddress?.ToString());
        return Results.Json(new { Message = "Неверный логин или пароль" }, statusCode: StatusCodes.Status401Unauthorized); // 401
    }
    await AppHelpers.LogAuditAsync(null, null, null, "login_success", $"login={request.Login}", http.Connection.RemoteIpAddress?.ToString());

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

// --- Minimal Web login endpoints (for initial admin 2FA setup) ---
app.MapPost("/api/web/login", async (AuthRequest request, IUserRepository users, HttpContext http) =>
{
    var user = await users.FindByLoginAsync(request.Login);
    if (user is null)
    {
        await AppHelpers.LogAuditAsync(null, null, null, "web_login_fail", $"login={request.Login}", http.Connection.RemoteIpAddress?.ToString());
        return Results.NotFound(new { Message = "Пользователь не найден" });
    }
    if (!PasswordHasher.VerifyPassword(request.Password, user.PasswordHash, user.PasswordSalt))
    {
        await AppHelpers.LogAuditAsync(null, user.Id, null, "web_login_fail", $"login={request.Login}", http.Connection.RemoteIpAddress?.ToString());
        return Results.Json(new { Message = "Неверный логин или пароль" }, statusCode: StatusCodes.Status401Unauthorized);
    }
    await AppHelpers.LogAuditAsync(null, user.Id, null, "web_login_success", $"login={request.Login}", http.Connection.RemoteIpAddress?.ToString());

    if (user.IsBanned)
    {
        var msg = string.IsNullOrWhiteSpace(user.BanReason) ? "Пользователь заблокирован" : $"Пользователь заблокирован. Причина: {user.BanReason}";
        return Results.Json(new { Message = msg }, statusCode: StatusCodes.Status403Forbidden);
    }

    if (user.MustSetup2FA && !user.TwoFactorEnabled)
    {
        return Results.Json(new { Next = "setup-2fa", Message = "Требуется настроить 2FA" }, statusCode: StatusCodes.Status403Forbidden);
    }

    if (user.Require2FA)
    {
        return Results.Json(new { Next = "enter-2fa", Message = "Введите код 2FA" }, statusCode: StatusCodes.Status401Unauthorized);
    }

    return Results.Ok(new { Message = "Успешная авторизация" });
});

app.MapPost("/api/web/2fa/start", async (TwoFaStartRequest req, IUserRepository users) =>
{
    var user = await users.FindByLoginAsync(req.Login);
    if (user is null) return Results.NotFound(new { Message = "Пользователь не найден" });

    // Generate secret and QR
    var secretKey = KeyGeneration.GenerateRandomKey(20); // 160-bit
    var base32Secret = Base32Encoding.ToString(secretKey);
    user.TwoFactorSecret = base32Secret;
    user.TwoFactorEnabled = false;
    await users.UpdateAsync(user);

    var issuer = Uri.EscapeDataString(req.Issuer ?? "ExiledCMS");
    var account = Uri.EscapeDataString(user.Login);
    var otpauth = $"otpauth://totp/{issuer}:{account}?secret={base32Secret}&issuer={issuer}&digits=6&period=30&algorithm=SHA1";

    // Create QR PNG as data URL
    using var qrGen = new QRCodeGenerator();
    var qrData = qrGen.CreateQrCode(otpauth, QRCodeGenerator.ECCLevel.Q);
    using var qrCode = new PngByteQRCode(qrData);
    var png = qrCode.GetGraphic(10);
    var dataUrl = "data:image/png;base64," + Convert.ToBase64String(png);

    return Results.Ok(new { Secret = base32Secret, OtpauthUri = otpauth, QrCodeDataUrl = dataUrl });
});

app.MapPost("/api/web/2fa/verify", async (TwoFaVerifyRequest req, IUserRepository users) =>
{
    var user = await users.FindByLoginAsync(req.Login);
    if (user is null) return Results.NotFound(new { Message = "Пользователь не найден" });
    if (string.IsNullOrWhiteSpace(user.TwoFactorSecret)) return Results.BadRequest(new { Message = "2FA не инициализирована" });

    var totp = new Totp(Base32Encoding.ToBytes(user.TwoFactorSecret));
    var isValid = totp.VerifyTotp(req.Code?.Trim() ?? string.Empty, out _, VerificationWindow.RfcSpecifiedNetworkDelay);
    if (!isValid) return Results.Json(new { Message = "Неверный код 2FA" }, statusCode: StatusCodes.Status401Unauthorized);

    user.TwoFactorEnabled = true;
    user.Require2FA = true;
    user.MustSetup2FA = false;
    await users.UpdateAsync(user);

    return Results.Ok(new { Message = "2FA успешно привязана" });
});

// --- Role & Permission API ---
app.MapGet("/api/roles", async (MainDbContext db) =>
{
    var roles = await db.Roles.Include(r => r.RolePermissions).ToListAsync();
    return Results.Ok(roles);
});

app.MapGet("/api/permissions", async (MainDbContext db) =>
{
    var perms = await db.Permissions.Include(p => p.RolePermissions).ToListAsync();
    return Results.Ok(perms);
});

app.MapPost("/api/roles", async (MainDbContext db, MainApi.Models.Role role, HttpContext http) =>
{
    db.Roles.Add(role);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, null, null, "role_create", $"name={role.Name}", http.Connection.RemoteIpAddress?.ToString());
    return Results.Created($"/api/roles/{role.Id}", role);
});

app.MapPut("/api/roles/{id}", async (MainDbContext db, int id, MainApi.Models.Role updated, HttpContext http) =>
{
    var role = await db.Roles.FindAsync(id);
    if (role == null) return Results.NotFound();
    role.Name = updated.Name;
    role.Code = updated.Code;
    role.Color = updated.Color;
    role.LogoUrl = updated.LogoUrl;
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, null, null, "role_update", $"id={id},name={updated.Name}", http.Connection.RemoteIpAddress?.ToString());
    return Results.Ok(role);
});

app.MapDelete("/api/roles/{id}", async (MainDbContext db, int id, HttpContext http) =>
{
    var role = await db.Roles.FindAsync(id);
    if (role == null) return Results.NotFound();
    db.Roles.Remove(role);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, null, null, "role_delete", $"id={id},name={role.Name}", http.Connection.RemoteIpAddress?.ToString());
    return Results.NoContent();
});

app.MapPost("/api/permissions", async (MainDbContext db, MainApi.Models.Permission perm, HttpContext http) =>
{
    db.Permissions.Add(perm);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, null, null, "permission_create", $"name={perm.Name}", http.Connection.RemoteIpAddress?.ToString());
    return Results.Created($"/api/permissions/{perm.Id}", perm);
});

app.MapPut("/api/permissions/{id}", async (MainDbContext db, int id, MainApi.Models.Permission updated, HttpContext http) =>
{
    var perm = await db.Permissions.FindAsync(id);
    if (perm == null) return Results.NotFound();
    perm.Name = updated.Name;
    perm.Code = updated.Code;
    perm.Description = updated.Description;
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, null, null, "permission_update", $"id={id},name={updated.Name}", http.Connection.RemoteIpAddress?.ToString());
    return Results.Ok(perm);
});

app.MapDelete("/api/permissions/{id}", async (MainDbContext db, int id, HttpContext http) =>
{
    var perm = await db.Permissions.FindAsync(id);
    if (perm == null) return Results.NotFound();
    db.Permissions.Remove(perm);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, null, null, "permission_delete", $"id={id},name={perm.Name}", http.Connection.RemoteIpAddress?.ToString());
    return Results.NoContent();
});

// --- Ticket API ---
app.MapGet("/api/tickets", async (MainDbContext db, int userId) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (perms.Contains("view_all_tickets"))
        return Results.Ok(await db.Tickets.ToListAsync());
    var own = await db.Tickets.Where(t => t.CreatedBy == userId).ToListAsync();
    return Results.Ok(own);
});

app.MapPost("/api/tickets", async (MainDbContext db, int userId, MainApi.Models.Ticket ticket, HttpContext http) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("create_ticket")) return Results.Forbid();
    ticket.CreatedBy = userId;
    ticket.Status = "open";
    ticket.CreatedAt = DateTime.UtcNow;
    db.Tickets.Add(ticket);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, userId, null, "ticket_create", $"title={ticket.Title}", http.Connection.RemoteIpAddress?.ToString());
    return Results.Created($"/api/tickets/{ticket.Id}", ticket);
});

app.MapPut("/api/tickets/{id}/close", async (MainDbContext db, int userId, int id, HttpContext http) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("close_ticket")) return Results.Forbid();
    var ticket = await db.Tickets.FindAsync(id);
    if (ticket == null) return Results.NotFound();
    ticket.Status = "closed";
    ticket.ClosedAt = DateTime.UtcNow;
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, userId, null, "ticket_close", $"id={id}", http.Connection.RemoteIpAddress?.ToString());
    return Results.Ok(ticket);
});

app.MapDelete("/api/tickets/{id}", async (MainDbContext db, int userId, int id, HttpContext http) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("delete_ticket")) return Results.Forbid();
    var ticket = await db.Tickets.FindAsync(id);
    if (ticket == null) return Results.NotFound();
    db.Tickets.Remove(ticket);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, userId, null, "ticket_delete", $"id={id},title={ticket.Title}", http.Connection.RemoteIpAddress?.ToString());
    return Results.NoContent();
});

// --- Page Access API ---
app.MapGet("/api/pages", async (MainDbContext db) =>
{
    var pages = await db.PageAccesses.Include(p => p.Permission).ToListAsync();
    return Results.Ok(pages.Select(p => new { p.Id, p.Path, PermissionName = p.Permission.Name, PermissionCode = p.Permission.Code }));
});

app.MapPost("/api/pages", async (MainDbContext db, string path, string permissionCode) =>
{
    var perm = await db.Permissions.FirstOrDefaultAsync(p => p.Code == permissionCode);
    if (perm == null) return Results.NotFound("Permission not found");
    var page = new MainApi.Models.PageAccess { Path = path, PermissionId = perm.Id };
    db.PageAccesses.Add(page);
    await db.SaveChangesAsync();
    return Results.Created($"/api/pages/{page.Id}", page);
});

app.MapPut("/api/pages/{id}", async (MainDbContext db, int id, string permissionCode) =>
{
    var page = await db.PageAccesses.FindAsync(id);
    if (page == null) return Results.NotFound();
    var perm = await db.Permissions.FirstOrDefaultAsync(p => p.Code == permissionCode);
    if (perm == null) return Results.NotFound("Permission not found");
    page.PermissionId = perm.Id;
    await db.SaveChangesAsync();
    return Results.Ok(page);
});

app.MapDelete("/api/pages/{id}", async (MainDbContext db, int id) =>
{
    var page = await db.PageAccesses.FindAsync(id);
    if (page == null) return Results.NotFound();
    db.PageAccesses.Remove(page);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

// --- API Token Management ---
app.MapGet("/api/tokens", async (MainDbContext db, int userId, HttpContext http) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("api_token")) return Results.Forbid();
    var tokens = await db.ApiTokens.Include(t => t.Permissions).Where(t => t.UserId == userId).ToListAsync();
    await AppHelpers.LogAuditAsync(db, userId, null, "token_view", $"count={tokens.Count}", http.Connection.RemoteIpAddress?.ToString());
    return Results.Ok(tokens.Select(t => new {
        t.Id,
        t.Name,
        t.CreatedAt,
        t.ExpiresAt,
        Permissions = t.Permissions.Select(tp => tp.PermissionId).ToList()
    }));
});

app.MapPost("/api/tokens", async (MainDbContext db, int userId, string name, DateTime? expiresAt, List<int> permissionIds, HttpContext http) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("api_token")) return Results.Forbid();
    var rawToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(32));
    var hash = PasswordHasher.HashPassword(rawToken, userId.ToString());
    // Получаем разрешения пользователя по id
    var allowedPermIds = await db.Permissions.Where(p => perms.Contains(p.Code)).Select(p => p.Id).ToListAsync();
    var filteredPermIds = permissionIds.Where(id => allowedPermIds.Contains(id)).Distinct().ToList();
    var token = new MainApi.Models.ApiToken
    {
        UserId = userId,
        Token = hash,
        Name = name,
        CreatedAt = DateTime.UtcNow,
        ExpiresAt = expiresAt,
        Permissions = filteredPermIds.Select(pid => new MainApi.Models.TokenPermission { PermissionId = pid }).ToList()
    };
    db.ApiTokens.Add(token);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, userId, token.Id, "token_create", $"name={name};perms=[{string.Join(",", filteredPermIds)}]", http.Connection.RemoteIpAddress?.ToString());
    return Results.Ok(new { token.Id, token.Name, token.CreatedAt, token.ExpiresAt, Token = rawToken, Permissions = filteredPermIds });
});

app.MapDelete("/api/tokens/{id}", async (MainDbContext db, int userId, int id, HttpContext http) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("api_token")) return Results.Forbid();
    var token = await db.ApiTokens.FirstOrDefaultAsync(t => t.Id == id && t.UserId == userId);
    if (token == null) return Results.NotFound();
    db.ApiTokens.Remove(token);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, userId, id, "token_delete", $"name={token.Name}", http.Connection.RemoteIpAddress?.ToString());
    return Results.NoContent();
});

app.MapGet("/api/tokens/all", async (MainDbContext db, int userId, HttpContext http) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("api_token_view_all")) return Results.Forbid();
    var tokens = await db.ApiTokens.Include(t => t.UserId).ToListAsync();
    var users = await db.Users.ToListAsync();
    await AppHelpers.LogAuditAsync(db, userId, null, "token_view_all", $"count={tokens.Count}", http.Connection.RemoteIpAddress?.ToString());
    return Results.Ok(tokens.Select(t => new {
        t.Id,
        t.Name,
        t.CreatedAt,
        t.ExpiresAt,
        t.UserId,
        UserLogin = users.FirstOrDefault(u => u.Id == t.UserId)?.Login
    }));
});

app.MapDelete("/api/tokens/all/{id}", async (MainDbContext db, int userId, int id, HttpContext http) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("api_token_delete_all")) return Results.Forbid();
    var token = await db.ApiTokens.FirstOrDefaultAsync(t => t.Id == id);
    if (token == null) return Results.NotFound();
    db.ApiTokens.Remove(token);
    await db.SaveChangesAsync();
    await AppHelpers.LogAuditAsync(db, userId, id, "token_delete_any", $"name={token.Name}", http.Connection.RemoteIpAddress?.ToString());
    return Results.NoContent();
});

// --- Audit Log API ---
app.MapGet("/api/audit-logs", async (MainDbContext db, int userId, string? action, int? filterUserId, int? apiTokenId, string? ip, string? details, DateTime? from, DateTime? to) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("audit_log_view")) return Results.Forbid();
    var query = db.AuditLogs.AsQueryable();
    if (!string.IsNullOrWhiteSpace(action)) query = query.Where(l => l.Action == action);
    if (filterUserId.HasValue) query = query.Where(l => l.UserId == filterUserId);
    if (apiTokenId.HasValue) query = query.Where(l => l.ApiTokenId == apiTokenId);
    if (!string.IsNullOrWhiteSpace(ip)) query = query.Where(l => l.Ip == ip);
    if (!string.IsNullOrWhiteSpace(details)) query = query.Where(l => l.Details != null && l.Details.Contains(details));
    if (from.HasValue) query = query.Where(l => l.CreatedAt >= from);
    if (to.HasValue) query = query.Where(l => l.CreatedAt <= to);
    var logs = await query.OrderByDescending(l => l.CreatedAt).Take(500).ToListAsync();
    return Results.Ok(logs);
});

app.MapDelete("/api/audit-logs", async (MainDbContext db, int userId, string? action, int? filterUserId, int? apiTokenId, string? ip, string? details, DateTime? to) =>
{
    var perms = await PermissionHelper.GetUserPermissions(db, userId);
    if (!perms.Contains("audit_log_manage")) return Results.Forbid();
    var query = db.AuditLogs.AsQueryable();
    if (!string.IsNullOrWhiteSpace(action)) query = query.Where(l => l.Action == action);
    if (filterUserId.HasValue) query = query.Where(l => l.UserId == filterUserId);
    if (apiTokenId.HasValue) query = query.Where(l => l.ApiTokenId == apiTokenId);
    if (!string.IsNullOrWhiteSpace(ip)) query = query.Where(l => l.Ip == ip);
    if (!string.IsNullOrWhiteSpace(details)) query = query.Where(l => l.Details != null && l.Details.Contains(details));
    if (to.HasValue) query = query.Where(l => l.CreatedAt <= to);
    db.AuditLogs.RemoveRange(query);
    await db.SaveChangesAsync();
    return Results.NoContent();
});

app.Run();

// DTOs and domain below for single-file simplicity. In a real project, split by folders.

record AuthRequest
{
    public string Login { get; init; } = string.Empty;
    public string Password { get; init; } = string.Empty;
}

record TwoFaStartRequest
{
    public string Login { get; init; } = string.Empty;
    public string? Issuer { get; init; }
}

record TwoFaVerifyRequest
{
    public string Login { get; init; } = string.Empty;
    public string? Code { get; init; }
}

class User
{
    public int Id { get; set; }
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
    public List<string> Permissions { get; set; } = new();
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
    public DbSet<MainApi.Models.Role> Roles => Set<MainApi.Models.Role>();
    public DbSet<MainApi.Models.Permission> Permissions => Set<MainApi.Models.Permission>();
    public DbSet<MainApi.Models.RolePermission> RolePermissions => Set<MainApi.Models.RolePermission>();
    public DbSet<MainApi.Models.UserRole> UserRoles => Set<MainApi.Models.UserRole>();
    public DbSet<MainApi.Models.UserPermission> UserPermissions => Set<MainApi.Models.UserPermission>();
    public DbSet<MainApi.Models.Ticket> Tickets => Set<MainApi.Models.Ticket>();
    public DbSet<MainApi.Models.PageAccess> PageAccesses => Set<MainApi.Models.PageAccess>();
    public DbSet<MainApi.Models.ApiToken> ApiTokens => Set<MainApi.Models.ApiToken>();
    public DbSet<MainApi.Models.AuditLog> AuditLogs => Set<MainApi.Models.AuditLog>();
    public DbSet<MainApi.Models.TokenPermission> TokenPermissions => Set<MainApi.Models.TokenPermission>();

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

        // Role
        var role = modelBuilder.Entity<MainApi.Models.Role>();
        role.ToTable("roles");
        role.HasKey(r => r.Id);
        role.HasIndex(r => r.Code).IsUnique();
        role.Property(r => r.Name).HasMaxLength(64).IsRequired();
        role.Property(r => r.Code).HasMaxLength(64).IsRequired();
        role.Property(r => r.Color).HasMaxLength(16);
        role.Property(r => r.LogoUrl).HasMaxLength(256);
        role.HasOne(r => r.ParentRole).WithMany().HasForeignKey(r => r.ParentRoleId).OnDelete(DeleteBehavior.Restrict);

        // Permission
        var perm = modelBuilder.Entity<MainApi.Models.Permission>();
        perm.ToTable("permissions");
        perm.HasKey(p => p.Id);
        perm.HasIndex(p => p.Code).IsUnique();
        perm.Property(p => p.Name).HasMaxLength(128).IsRequired();
        perm.Property(p => p.Code).HasMaxLength(128).IsRequired();
        perm.Property(p => p.Description).HasMaxLength(512);

        // RolePermission
        var rp = modelBuilder.Entity<MainApi.Models.RolePermission>();
        rp.ToTable("role_permissions");
        rp.HasKey(x => new { x.RoleId, x.PermissionId });
        rp.HasOne(x => x.Role).WithMany(r => r.RolePermissions).HasForeignKey(x => x.RoleId);
        rp.HasOne(x => x.Permission).WithMany(p => p.RolePermissions).HasForeignKey(x => x.PermissionId);

        // UserRole
        var ur = modelBuilder.Entity<MainApi.Models.UserRole>();
        ur.ToTable("user_roles");
        ur.HasKey(x => new { x.UserId, x.RoleId });
        ur.HasOne(x => x.Role).WithMany(r => r.UserRoles).HasForeignKey(x => x.RoleId);

        // UserPermission
        var up = modelBuilder.Entity<MainApi.Models.UserPermission>();
        up.ToTable("user_permissions");
        up.HasKey(x => new { x.UserId, x.PermissionId });
        up.HasOne(x => x.Permission).WithMany(p => p.UserPermissions).HasForeignKey(x => x.PermissionId);

        // Ticket
        var ticket = modelBuilder.Entity<MainApi.Models.Ticket>();
        ticket.ToTable("tickets");
        ticket.HasKey(t => t.Id);
        ticket.Property(t => t.Title).HasMaxLength(200).IsRequired();
        ticket.Property(t => t.Description).HasMaxLength(4000);
        ticket.Property(t => t.Status).HasMaxLength(32).IsRequired();
        ticket.Property(t => t.CreatedAt).IsRequired();

        // PageAccess
        var page = modelBuilder.Entity<MainApi.Models.PageAccess>();
        page.ToTable("page_access");
        page.HasKey(p => p.Id);
        page.Property(p => p.Path).HasMaxLength(128).IsRequired();
        page.HasOne(p => p.Permission).WithMany().HasForeignKey(p => p.PermissionId).OnDelete(DeleteBehavior.Cascade);

        // ApiToken
        var token = modelBuilder.Entity<MainApi.Models.ApiToken>();
        token.ToTable("api_tokens");
        token.HasKey(t => t.Id);
        token.Property(t => t.Token).HasMaxLength(128).IsRequired();
        token.Property(t => t.Name).HasMaxLength(64);
        token.Property(t => t.CreatedAt).IsRequired();

        // AuditLog
        var log = modelBuilder.Entity<MainApi.Models.AuditLog>();
        log.ToTable("audit_logs");
        log.HasKey(l => l.Id);
        log.Property(l => l.Action).HasMaxLength(128).IsRequired();
        log.Property(l => l.Details).HasMaxLength(2048);
        log.Property(l => l.TokenName).HasMaxLength(64);
        log.Property(l => l.IpAddress).HasMaxLength(64);
        log.Property(l => l.Timestamp).IsRequired();

        // TokenPermission
        var tp = modelBuilder.Entity<MainApi.Models.TokenPermission>();
        tp.ToTable("token_permissions");
        tp.HasKey(x => new { x.TokenId, x.PermissionId });
        tp.HasOne(x => x.Token).WithMany(t => t.Permissions).HasForeignKey(x => x.TokenId);
        tp.HasOne(x => x.Permission).WithMany().HasForeignKey(x => x.PermissionId);
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

static class PermissionHelper
{
    public static async Task<HashSet<string>> GetUserPermissions(MainDbContext db, int userId)
    {
        var userPerms = await db.UserPermissions.Where(up => up.UserId == userId).Select(up => up.Permission.Code).ToListAsync();
        var roleIds = await db.UserRoles.Where(ur => ur.UserId == userId).Select(ur => ur.RoleId).ToListAsync();
        var allPerms = new HashSet<string>(userPerms);
        var visitedRoles = new HashSet<int>();
        foreach (var roleId in roleIds)
            AddRolePermissionsRecursive(db, roleId, allPerms, visitedRoles);
        // Если есть '*' — все разрешения
        if (allPerms.Contains("*"))
            allPerms = db.Permissions.Select(p => p.Code).ToHashSet();
        return allPerms;
    }

    public static void AddRolePermissionsRecursive(MainDbContext db, int roleId, HashSet<string> perms, HashSet<int> visited)
    {
        if (visited.Contains(roleId)) return;
        visited.Add(roleId);
        var role = db.Roles.Include(r => r.RolePermissions).FirstOrDefault(r => r.Id == roleId);
        if (role == null) return;
        var codes = role.RolePermissions.Select(rp => rp.Permission.Code);
        foreach (var c in codes) perms.Add(c);
        if (role.ParentRoleId.HasValue)
            AddRolePermissionsRecursive(db, role.ParentRoleId.Value, perms, visited);
    }
}

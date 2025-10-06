using System.Text;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;

internal static class AppHelpers
{
    // --- Helpers for .env and connection strings ---
    public static void LoadDotEnv(string contentRootPath)
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

    public static string BuildMySqlConnectionString(string? host, string? port, string? db, string? user, string? password)
    {
        host ??= "localhost";
        port = string.IsNullOrWhiteSpace(port) ? "3306" : port;
        db ??= "exiledcms";
        user ??= "root";
        password ??= string.Empty;
        return $"Server={host};Port={port};Database={db};User={user};Password={password};TreatTinyAsBoolean=true;";
    }

    public static string BuildPostgresConnectionString(string? host, string? port, string? db, string? user, string? password, string? sslMode)
    {
        host ??= "localhost";
        port = string.IsNullOrWhiteSpace(port) ? "5432" : port;
        db ??= "exiledcms";
        user ??= "postgres";
        password ??= string.Empty;
        sslMode = string.IsNullOrWhiteSpace(sslMode) ? "Disable" : sslMode;
        return $"Host={host};Port={port};Database={db};Username={user};Password={password};SslMode={sslMode};";
    }

    // --- Database seed ---
    public static void SeedDatabase(MainDbContext ctx)
    {
        string? adminLogin;
        if (!ctx.Users.Any())
        {
            adminLogin = Environment.GetEnvironmentVariable("ADMIN_LOGIN") ?? "admin";
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
                // Initial admin must set up 2FA on first login
                Require2FA = false,
                TwoFactorEnabled = false,
                MustSetup2FA = true,
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

        // --- Seed roles and permissions ---
        adminLogin = Environment.GetEnvironmentVariable("ADMIN_LOGIN") ?? "admin";
        var adminRole = ctx.Roles.FirstOrDefault(r => r.Code == "admin");
        if (adminRole == null)
        {
            adminRole = new MainApi.Models.Role { Name = "Администратор", Code = "admin", Color = "#800080", LogoUrl = "", ParentRoleId = null };
            ctx.Roles.Add(adminRole);
            ctx.SaveChanges();
        }
        var userRole = ctx.Roles.FirstOrDefault(r => r.Code == "user");
        if (userRole == null)
        {
            userRole = new MainApi.Models.Role { Name = "Пользователь", Code = "user", Color = "#6f42c1", LogoUrl = "", ParentRoleId = null };
            ctx.Roles.Add(userRole);
            ctx.SaveChanges();
        }
        // --- Permissions ---
        var permissions = new[]
        {
            new MainApi.Models.Permission { Name = "Доступ к главной странице", Code = "access_home", Description = "Доступ к главной странице" },
            new MainApi.Models.Permission { Name = "Доступ к странице входа", Code = "access_login", Description = "Доступ к странице входа" },
            new MainApi.Models.Permission { Name = "Управление ролями", Code = "manage_roles", Description = "Доступ к матрице ролей и разрешений" },
            new MainApi.Models.Permission { Name = "Управление новостями", Code = "manage_news", Description = "Добавление и изменение новостей" },
            new MainApi.Models.Permission { Name = "Доступ к конструктору страниц", Code = "page_builder", Description = "Доступ к визуальному редактору страниц" },
            // Ticket permissions
            new MainApi.Models.Permission { Name = "Создание тикетов", Code = "create_ticket", Description = "Создание тикетов" },
            new MainApi.Models.Permission { Name = "Закрытие тикетов", Code = "close_ticket", Description = "Закрытие тикетов" },
            new MainApi.Models.Permission { Name = "Удаление тикетов", Code = "delete_ticket", Description = "Удаление тикетов" },
            new MainApi.Models.Permission { Name = "Просмотр всех тикетов", Code = "view_all_tickets", Description = "Просмотр тикетов других пользователей" },
            new MainApi.Models.Permission { Name = "Управление API токенами", Code = "api_token", Description = "Получение и управление API токенами для интеграций" },
            new MainApi.Models.Permission { Name = "Просмотр логов действий", Code = "audit_log_view", Description = "Просмотр логов действий пользователей и токенов" },
            new MainApi.Models.Permission { Name = "Управление логами действий", Code = "audit_log_manage", Description = "Удаление и очистка логов действий" },
            new MainApi.Models.Permission { Name = "Просмотр всех API токенов", Code = "api_token_view_all", Description = "Просмотр всех токенов и их владельцев" },
            new MainApi.Models.Permission { Name = "Удаление любых API токенов", Code = "api_token_delete_all", Description = "Удаление любых токенов, а не только своих" },
        };
        foreach (var perm in permissions)
        {
            if (!ctx.Permissions.Any(p => p.Code == perm.Code))
                ctx.Permissions.Add(perm);
        }
        ctx.SaveChanges();
        // --- Назначение всех разрешений админу ---
        var allPerms = ctx.Permissions.ToList();
        foreach (var perm in allPerms)
        {
            if (!ctx.RolePermissions.Any(rp => rp.RoleId == adminRole.Id && rp.PermissionId == perm.Id))
                ctx.RolePermissions.Add(new MainApi.Models.RolePermission { RoleId = adminRole.Id, PermissionId = perm.Id });
        }
        ctx.SaveChanges();
        // --- Назначение базовых разрешений обычному пользователю ---
        var userPerms = ctx.Permissions.Where(p => p.Code == "access_home" || p.Code == "access_login").ToList();
        foreach (var perm in userPerms)
        {
            if (!ctx.RolePermissions.Any(rp => rp.RoleId == userRole.Id && rp.PermissionId == perm.Id))
                ctx.RolePermissions.Add(new MainApi.Models.RolePermission { RoleId = userRole.Id, PermissionId = perm.Id });
        }
        ctx.SaveChanges();
        // --- Назначение роли админу из .env ---
        var adminUser = ctx.Users.FirstOrDefault(u => u.Login == adminLogin);
        if (adminUser != null && !ctx.UserRoles.Any(ur => ur.UserId == adminUser.Id && ur.RoleId == adminRole.Id))
        {
            ctx.UserRoles.Add(new MainApi.Models.UserRole { UserId = adminUser.Id, RoleId = adminRole.Id });
            ctx.SaveChanges();
        }
    }

    // --- Универсальная функция логирования действий ---
    public static async Task LogAuditAsync(MainDbContext? db, int? userId, int? apiTokenId, string action, string? details, string? ip)
    {
        if (db == null) return;
        db.AuditLogs.Add(new MainApi.Models.AuditLog
        {
            UserId = userId,
            ApiTokenId = apiTokenId,
            Action = action,
            Details = details,
            Ip = ip,
            CreatedAt = DateTime.UtcNow
        });
        await db.SaveChangesAsync();
    }
}

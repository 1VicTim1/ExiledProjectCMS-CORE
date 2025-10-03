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
}

using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using ExiledProjectCMS.Core.Entities;
using ExiledProjectCMS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace ExiledProjectCMS.Infrastructure.Commands;

/// <summary>
///     Консольная команда для создания первого администратора системы
/// </summary>
public class CreateAdminCommand
{
    private readonly ILogger<CreateAdminCommand> _logger;
    private readonly IServiceProvider _serviceProvider;

    public CreateAdminCommand(IServiceProvider serviceProvider, ILogger<CreateAdminCommand> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    /// <summary>
    ///     Выполнить создание администратора
    /// </summary>
    /// <param name="username">Имя пользователя</param>
    /// <param name="email">Email</param>
    /// <param name="password">Пароль</param>
    /// <param name="displayName">Отображаемое имя</param>
    /// <returns>True, если админ создан</returns>
    public async Task<bool> ExecuteAsync(string username, string email, string password, string? displayName = null)
    {
        using var scope = _serviceProvider.CreateScope();
        var dbContext = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        try
        {
            // Проверяем, есть ли уже администратор
            var adminRole = await dbContext.Roles.FirstOrDefaultAsync(r => r.Name == "admin");
            if (adminRole != null)
            {
                var existingAdmin = await dbContext.UserRoles
                    .Include(ur => ur.User)
                    .AnyAsync(ur => ur.RoleId == adminRole.Id);

                if (existingAdmin)
                {
                    _logger.LogWarning("Администратор уже существует в системе");
                    Console.WriteLine("⚠️  Администратор уже существует в системе");
                    return false;
                }
            }

            // Создаем роли системы если их нет
            await CreateSystemRolesAsync(dbContext);

            // Создаем пользователя
            var user = new User
            {
                Login = username,
                Email = email,
                DisplayName = displayName ?? username,
                PasswordHash = HashPassword(password),
                UserUuid = Guid.NewGuid(),
                IsEmailConfirmed = true,
                IsBlocked = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            dbContext.Users.Add(user);
            await dbContext.SaveChangesAsync();

            // Назначаем роль администратора
            var adminRoleEntity = await dbContext.Roles.FirstAsync(r => r.Name == "admin");
            var userRole = new UserRole
            {
                UserId = user.Id,
                RoleId = adminRoleEntity.Id,
                AssignedAt = DateTime.UtcNow
            };

            dbContext.UserRoles.Add(userRole);
            await dbContext.SaveChangesAsync();

            _logger.LogInformation("Администратор успешно создан: {Username} ({Email})", username, email);
            Console.WriteLine("✅ Администратор успешно создан!");
            Console.WriteLine($"   Логин: {username}");
            Console.WriteLine($"   Email: {email}");
            Console.WriteLine($"   UUID: {user.UserUuid}");

            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при создании администратора");
            Console.WriteLine($"❌ Ошибка при создании администратора: {ex.Message}");
            return false;
        }
    }

    private async Task CreateSystemRolesAsync(ApplicationDbContext dbContext)
    {
        var systemRoles = new[]
        {
            new Role
            {
                Name = "admin",
                DisplayName = "Администратор",
                Description = "Полный доступ к системе",
                Color = "#FF0000",
                Priority = 1000,
                IsSystem = true
            },
            new Role
            {
                Name = "moderator",
                DisplayName = "Модератор",
                Description = "Управление контентом и пользователями",
                Color = "#FF8800",
                Priority = 500,
                IsSystem = true
            },
            new Role
            {
                Name = "editor",
                DisplayName = "Редактор",
                Description = "Создание и редактирование контента",
                Color = "#0088FF",
                Priority = 100,
                IsSystem = true
            },
            new Role
            {
                Name = "user",
                DisplayName = "Пользователь",
                Description = "Базовый пользователь системы",
                Color = "#888888",
                Priority = 1,
                IsSystem = true
            }
        };

        foreach (var role in systemRoles)
        {
            var existingRole = await dbContext.Roles.FirstOrDefaultAsync(r => r.Name == role.Name);
            if (existingRole == null) dbContext.Roles.Add(role);
        }

        await dbContext.SaveChangesAsync();

        // Создаем системные права доступа
        await CreateSystemPermissionsAsync(dbContext);
    }

    private async Task CreateSystemPermissionsAsync(ApplicationDbContext dbContext)
    {
        var adminRole = await dbContext.Roles.FirstAsync(r => r.Name == "admin");
        var permissions = typeof(Permission).GetFields(BindingFlags.Public | BindingFlags.Static)
            .Where(f => f.IsLiteral && f.FieldType == typeof(string))
            .Select(f => f.GetValue(null)?.ToString())
            .Where(p => !string.IsNullOrEmpty(p))
            .ToList();

        foreach (var permissionName in permissions)
        {
            if (string.IsNullOrEmpty(permissionName)) continue;

            var existingPermission = await dbContext.Permissions.FirstOrDefaultAsync(p => p.Name == permissionName);
            if (existingPermission == null)
            {
                var permission = new Permission
                {
                    Name = permissionName,
                    Description = GetPermissionDescription(permissionName)
                };
                dbContext.Permissions.Add(permission);
                await dbContext.SaveChangesAsync();

                // Назначаем все права администратору
                var rolePermission = new RolePermission
                {
                    RoleId = adminRole.Id,
                    PermissionId = permission.Id
                };
                dbContext.RolePermissions.Add(rolePermission);
            }
        }

        await dbContext.SaveChangesAsync();
    }

    private static string GetPermissionDescription(string permissionName)
    {
        return permissionName switch
        {
            "admin.panel" => "Доступ к админ панели",
            "admin.users" => "Управление пользователями",
            "admin.roles" => "Управление ролями",
            "admin.permissions" => "Управление правами доступа",
            "admin.system" => "Системные настройки",
            "admin.plugins" => "Управление плагинами",
            "admin.cache" => "Управление кешем",
            "admin.migrations" => "Управление миграциями БД",
            "news.create" => "Создание новостей",
            "news.edit" => "Редактирование новостей",
            "news.delete" => "Удаление новостей",
            "news.publish" => "Публикация новостей",
            "users.view" => "Просмотр пользователей",
            "users.edit" => "Редактирование пользователей",
            "users.ban" => "Блокировка пользователей",
            _ => $"Разрешение: {permissionName}"
        };
    }

    private static string HashPassword(string password)
    {
        using var sha256 = SHA256.Create();
        var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
        return Convert.ToBase64String(hashedBytes);
    }
}

/// <summary>
///     Расширения для регистрации консольных команд
/// </summary>
public static class ConsoleCommandExtensions
{
    /// <summary>
    ///     Добавить поддержку консольных команд
    /// </summary>
    /// <param name="services">Коллекция сервисов</param>
    public static void AddConsoleCommands(this IServiceCollection services)
    {
        services.AddScoped<CreateAdminCommand>();
    }

    /// <summary>
    ///     Обработать аргументы командной строки
    /// </summary>
    /// <param name="app">Приложение</param>
    /// <param name="args">Аргументы</param>
    public static async Task ProcessCommandLineArgsAsync(this IHost app, string[] args)
    {
        if (args.Length == 0) return;

        var command = args[0].ToLowerInvariant();

        switch (command)
        {
            case "create-admin":
                await HandleCreateAdminCommand(app, args);
                Environment.Exit(0);
                break;
        }
    }

    private static async Task HandleCreateAdminCommand(IHost app, string[] args)
    {
        if (args.Length < 4)
        {
            Console.WriteLine("Использование: create-admin <username> <email> <password> [displayName]");
            return;
        }

        var username = args[1];
        var email = args[2];
        var password = args[3];
        var displayName = args.Length > 4 ? args[4] : null;

        using var scope = app.Services.CreateScope();
        var createAdminCommand = scope.ServiceProvider.GetRequiredService<CreateAdminCommand>();

        await createAdminCommand.ExecuteAsync(username, email, password, displayName);
    }
}
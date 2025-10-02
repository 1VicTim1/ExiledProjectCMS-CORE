using System.Diagnostics;
using System.Reflection;
using ExiledProjectCMS.Core.Interfaces;
using ExiledProjectCMS.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ExiledProjectCMS.API.Controllers;

/// <summary>
///     Контроллер админ-панели для управления системой
/// </summary>
[ApiController]
[Route("api/admin")]
[Produces("application/json")]
[Tags("Admin Panel")]
public class AdminController : ControllerBase
{
    private readonly ICacheService _cacheService;
    private readonly IConfiguration _configuration;
    private readonly ApplicationDbContext _dbContext;
    private readonly ILogger<AdminController> _logger;

    public AdminController(
        ICacheService cacheService,
        ApplicationDbContext dbContext,
        ILogger<AdminController> logger,
        IConfiguration configuration)
    {
        _cacheService = cacheService;
        _dbContext = dbContext;
        _logger = logger;
        _configuration = configuration;
    }

    /// <summary>
    ///     Получить информацию о системе
    /// </summary>
    /// <returns>Информация о системе</returns>
    [HttpGet("system-info")]
    public async Task<IActionResult> GetSystemInfo()
    {
        try
        {
            var process = Process.GetCurrentProcess();
            var startTime = DateTime.Now - process.StartTime;

            var systemInfo = new
            {
                Version = Assembly.GetEntryAssembly()?.GetName().Version?.ToString(),
                Environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT"),
                Uptime = startTime.ToString(@"dd\.hh\:mm\:ss"),
                Environment.MachineName,
                Environment.ProcessorCount,
                WorkingSet = GC.GetTotalMemory(false) / 1024 / 1024 + " MB",
                DatabaseProvider = _configuration.GetValue<string>("DatabaseProvider"),
                CacheProvider = _configuration.GetValue<string>("CacheProvider"),
                PluginsEnabled = _configuration.GetValue<bool>("Plugins:EnableHotReload"),
                DatabaseConnection = await TestDatabaseConnection()
            };

            return Ok(systemInfo);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при получении информации о системе");
            return StatusCode(500, new { message = "Ошибка при получении информации о системе" });
        }
    }

    /// <summary>
    ///     Очистить весь кеш
    /// </summary>
    /// <returns>Результат операции</returns>
    [HttpPost("cache/clear")]
    public async Task<IActionResult> ClearCache()
    {
        try
        {
            await _cacheService.ClearAllAsync();
            _logger.LogInformation("Кеш очищен через админ-панель");
            return Ok(new { message = "Кеш успешно очищен", timestamp = DateTime.UtcNow });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при очистке кеша");
            return StatusCode(500, new { message = "Ошибка при очистке кеша" });
        }
    }

    /// <summary>
    ///     Очистить кеш по шаблону
    /// </summary>
    /// <param name="pattern">Шаблон для очистки</param>
    /// <returns>Результат операции</returns>
    [HttpPost("cache/clear/{pattern}")]
    public async Task<IActionResult> ClearCacheByPattern(string pattern)
    {
        try
        {
            await _cacheService.RemoveByPatternAsync(pattern);
            _logger.LogInformation("Кеш очищен по шаблону: {Pattern}", pattern);
            return Ok(new { message = $"Кеш очищен по шаблону: {pattern}", timestamp = DateTime.UtcNow });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при очистке кеша по шаблону: {Pattern}", pattern);
            return StatusCode(500, new { message = "Ошибка при очистке кеша" });
        }
    }

    /// <summary>
    ///     Проверить подключение к базе данных
    /// </summary>
    /// <returns>Статус подключения</returns>
    [HttpGet("database/test-connection")]
    public async Task<IActionResult> TestConnection()
    {
        try
        {
            var canConnect = await TestDatabaseConnection();
            return Ok(new { connected = canConnect, timestamp = DateTime.UtcNow });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при проверке подключения к базе данных");
            return Ok(new { connected = false, error = ex.Message, timestamp = DateTime.UtcNow });
        }
    }

    /// <summary>
    ///     Получить список доступных миграций
    /// </summary>
    /// <returns>Список миграций</returns>
    [HttpGet("migrations")]
    public async Task<IActionResult> GetMigrations()
    {
        try
        {
            var appliedMigrations = await _dbContext.Database.GetAppliedMigrationsAsync();
            var pendingMigrations = await _dbContext.Database.GetPendingMigrationsAsync();

            var migrationInfo = new
            {
                Applied = appliedMigrations.ToList(),
                Pending = pendingMigrations.ToList(),
                CanMigrate = pendingMigrations.Any(),
                LastMigration = appliedMigrations.LastOrDefault(),
                TotalApplied = appliedMigrations.Count(),
                TotalPending = pendingMigrations.Count()
            };

            return Ok(migrationInfo);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при получении информации о миграциях");
            return StatusCode(500, new { message = "Ошибка при получении информации о миграциях" });
        }
    }

    /// <summary>
    ///     Применить ожидающие миграции
    /// </summary>
    /// <returns>Результат операции</returns>
    [HttpPost("migrations/apply")]
    public async Task<IActionResult> ApplyMigrations()
    {
        try
        {
            var pendingMigrations = await _dbContext.Database.GetPendingMigrationsAsync();
            if (!pendingMigrations.Any()) return Ok(new { message = "Нет ожидающих миграций", applied = 0 });

            await _dbContext.Database.MigrateAsync();
            _logger.LogInformation("Применены миграции: {Migrations}", string.Join(", ", pendingMigrations));

            return Ok(new
            {
                message = "Миграции успешно применены",
                applied = pendingMigrations.Count(),
                migrations = pendingMigrations.ToList(),
                timestamp = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при применении миграций");
            return StatusCode(500, new { message = "Ошибка при применении миграций", error = ex.Message });
        }
    }

    /// <summary>
    ///     Получить статистику базы данных
    /// </summary>
    /// <returns>Статистика БД</returns>
    [HttpGet("database/statistics")]
    public async Task<IActionResult> GetDatabaseStatistics()
    {
        try
        {
            var statistics = new
            {
                Users = new
                {
                    Total = await _dbContext.Users.CountAsync(),
                    Active = await _dbContext.Users.CountAsync(u => !u.IsBlocked),
                    Blocked = await _dbContext.Users.CountAsync(u => u.IsBlocked),
                    EmailConfirmed = await _dbContext.Users.CountAsync(u => u.IsEmailConfirmed)
                },
                News = new
                {
                    Total = await _dbContext.News.CountAsync(),
                    Published = await _dbContext.News.CountAsync(n => n.IsPublished),
                    Draft = await _dbContext.News.CountAsync(n => !n.IsPublished)
                },
                Roles = new
                {
                    Total = await _dbContext.Roles.CountAsync(),
                    System = await _dbContext.Roles.CountAsync(r => r.IsSystem)
                },
                UserRoles = await _dbContext.UserRoles.CountAsync()
            };

            return Ok(statistics);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при получении статистики базы данных");
            return StatusCode(500, new { message = "Ошибка при получении статистики" });
        }
    }

    private async Task<bool> TestDatabaseConnection()
    {
        try
        {
            return await _dbContext.Database.CanConnectAsync();
        }
        catch
        {
            return false;
        }
    }
}
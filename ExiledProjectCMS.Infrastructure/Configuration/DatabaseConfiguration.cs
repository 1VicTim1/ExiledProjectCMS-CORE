using ExiledProjectCMS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace ExiledProjectCMS.Infrastructure.Configuration;

/// <summary>
///     Конфигурация подключения к различным базам данных
/// </summary>
public static class DatabaseConfiguration
{
    /// <summary>
    ///     Настройка подключения к базе данных в зависимости от провайдера
    /// </summary>
    /// <param name="services">Коллекция сервисов</param>
    /// <param name="configuration">Конфигурация приложения</param>
    public static void ConfigureDatabase(this IServiceCollection services, IConfiguration configuration)
    {
        var databaseProvider = configuration.GetValue<string>("DatabaseProvider") ?? "SqlServer";
        var connectionString = configuration.GetConnectionString("DefaultConnection");

        if (string.IsNullOrEmpty(connectionString))
            throw new InvalidOperationException("Строка подключения к базе данных не найдена");

        switch (databaseProvider.ToLowerInvariant())
        {
            case "sqlserver":
                services.AddDbContext<ApplicationDbContext>(options =>
                    options.UseSqlServer(connectionString, sqlOptions =>
                    {
                        sqlOptions.MigrationsAssembly("ExiledProjectCMS.Infrastructure");
                        sqlOptions.EnableRetryOnFailure(
                            5,
                            TimeSpan.FromSeconds(30),
                            null);
                    }));
                break;

            case "mysql":
                services.AddDbContext<ApplicationDbContext>(options =>
                    options.UseMySql(connectionString, ServerVersion.AutoDetect(connectionString), mysqlOptions =>
                    {
                        mysqlOptions.MigrationsAssembly("ExiledProjectCMS.Infrastructure");
                        mysqlOptions.EnableRetryOnFailure(
                            5,
                            TimeSpan.FromSeconds(30),
                            new List<int>());
                    }));
                break;

            case "postgresql":
            case "postgres":
                services.AddDbContext<ApplicationDbContext>(options =>
                    options.UseNpgsql(connectionString, npgsqlOptions =>
                    {
                        npgsqlOptions.MigrationsAssembly("ExiledProjectCMS.Infrastructure");
                        npgsqlOptions.EnableRetryOnFailure(
                            5,
                            TimeSpan.FromSeconds(30),
                            null);
                    }));
                break;

            case "inmemory":
                services.AddDbContext<ApplicationDbContext>(options =>
                    options.UseInMemoryDatabase("ExiledProjectCMS_InMemory"));
                break;

            default:
                throw new NotSupportedException($"Провайдер базы данных '{databaseProvider}' не поддерживается");
        }
    }

    /// <summary>
    ///     Получить строку подключения по умолчанию для провайдера
    /// </summary>
    /// <param name="provider">Провайдер базы данных</param>
    /// <param name="server">Сервер</param>
    /// <param name="database">База данных</param>
    /// <param name="username">Пользователь</param>
    /// <param name="password">Пароль</param>
    /// <returns>Строка подключения</returns>
    public static string GetDefaultConnectionString(string provider, string server = "localhost",
        string database = "ExiledProjectCMS", string username = "", string password = "")
    {
        return provider.ToLowerInvariant() switch
        {
            "sqlserver" =>
                $"Server={server};Database={database};Trusted_Connection=true;MultipleActiveResultSets=true;TrustServerCertificate=true",
            "mysql" => $"Server={server};Database={database};Uid={username};Pwd={password};CharSet=utf8mb4;",
            "postgresql" or "postgres" => $"Host={server};Database={database};Username={username};Password={password};",
            "inmemory" => database,
            _ => throw new NotSupportedException($"Провайдер '{provider}' не поддерживается")
        };
    }

    /// <summary>
    ///     Валидация строки подключения для указанного провайдера
    /// </summary>
    /// <param name="provider">Провайдер базы данных</param>
    /// <param name="connectionString">Строка подключения</param>
    /// <returns>True, если строка подключения валидна</returns>
    public static bool ValidateConnectionString(string provider, string connectionString)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
            return false;

        try
        {
            return provider.ToLowerInvariant() switch
            {
                "sqlserver" => connectionString.Contains("Server=") || connectionString.Contains("Data Source="),
                "mysql" => connectionString.Contains("Server=") || connectionString.Contains("Host="),
                "postgresql" or "postgres" => connectionString.Contains("Host=") ||
                                              connectionString.Contains("Server="),
                "inmemory" => !string.IsNullOrWhiteSpace(connectionString),
                _ => false
            };
        }
        catch
        {
            return false;
        }
    }
}
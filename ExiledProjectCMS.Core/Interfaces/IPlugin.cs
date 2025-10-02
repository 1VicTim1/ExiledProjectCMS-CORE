using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;

namespace ExiledProjectCMS.Core.Interfaces;

/// <summary>
///     Базовый интерфейс для всех плагинов
/// </summary>
public interface IPlugin
{
    /// <summary>
    ///     Уникальный идентификатор плагина
    /// </summary>
    string Id { get; }

    /// <summary>
    ///     Название плагина
    /// </summary>
    string Name { get; }

    /// <summary>
    ///     Версия плагина
    /// </summary>
    string Version { get; }

    /// <summary>
    ///     Описание плагина
    /// </summary>
    string Description { get; }

    /// <summary>
    ///     Автор плагина
    /// </summary>
    string Author { get; }

    /// <summary>
    ///     Зависимости плагина
    /// </summary>
    string[] Dependencies { get; }

    /// <summary>
    ///     Инициализация плагина
    /// </summary>
    /// <param name="serviceProvider">Провайдер сервисов</param>
    Task InitializeAsync(IServiceProvider serviceProvider);

    /// <summary>
    ///     Запуск плагина
    /// </summary>
    Task StartAsync();

    /// <summary>
    ///     Остановка плагина
    /// </summary>
    Task StopAsync();

    /// <summary>
    ///     Проверка совместимости с версией CMS
    /// </summary>
    /// <param name="cmsVersion">Версия CMS</param>
    /// <returns>True, если совместим</returns>
    bool IsCompatible(string cmsVersion);
}

/// <summary>
///     Интерфейс для C# плагинов
/// </summary>
public interface ICSharpPlugin : IPlugin
{
    /// <summary>
    ///     Конфигурация сервисов плагина
    /// </summary>
    /// <param name="services">Коллекция сервисов</param>
    void ConfigureServices(IServiceCollection services);

    /// <summary>
    ///     Конфигурация middleware плагина
    /// </summary>
    /// <param name="app">Application builder</param>
    void Configure(IApplicationBuilder app);
}

/// <summary>
///     Интерфейс для JavaScript плагинов
/// </summary>
public interface IJavaScriptPlugin : IPlugin
{
    /// <summary>
    ///     Путь к главному файлу плагина
    /// </summary>
    string MainFile { get; }

    /// <summary>
    ///     Ресурсы для загрузки на фронтенде
    /// </summary>
    string[] Assets { get; }

    /// <summary>
    ///     Конфигурация API эндпоинтов плагина
    /// </summary>
    Dictionary<string, object> ApiEndpoints { get; }
}

/// <summary>
///     Интерфейс для Go плагинов (для будущей интеграции)
/// </summary>
public interface IGoPlugin : IPlugin
{
    /// <summary>
    ///     Порт для запуска Go сервиса
    /// </summary>
    int Port { get; }

    /// <summary>
    ///     Путь к исполняемому файлу Go
    /// </summary>
    string ExecutablePath { get; }

    /// <summary>
    ///     Переменные окружения для Go процесса
    /// </summary>
    Dictionary<string, string> EnvironmentVariables { get; }

    /// <summary>
    ///     API эндпоинты, которые предоставляет Go сервис
    /// </summary>
    Dictionary<string, string> ProxyEndpoints { get; }
}
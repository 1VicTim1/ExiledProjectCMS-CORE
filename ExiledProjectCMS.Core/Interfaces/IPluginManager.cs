namespace ExiledProjectCMS.Core.Interfaces;

/// <summary>
///     Интерфейс менеджера плагинов
/// </summary>
public interface IPluginManager
{
    /// <summary>
    ///     Получить все загруженные плагины
    /// </summary>
    /// <returns>Список плагинов</returns>
    IEnumerable<IPlugin> GetLoadedPlugins();

    /// <summary>
    ///     Получить плагин по ID
    /// </summary>
    /// <param name="id">ID плагина</param>
    /// <returns>Плагин или null</returns>
    IPlugin? GetPlugin(string id);

    /// <summary>
    ///     Загрузить плагин из файла
    /// </summary>
    /// <param name="filePath">Путь к файлу плагина</param>
    /// <returns>Загруженный плагин</returns>
    Task<IPlugin> LoadPluginAsync(string filePath);

    /// <summary>
    ///     Выгрузить плагин
    /// </summary>
    /// <param name="id">ID плагина</param>
    /// <returns>True, если плагин выгружен</returns>
    Task<bool> UnloadPluginAsync(string id);

    /// <summary>
    ///     Запустить плагин
    /// </summary>
    /// <param name="id">ID плагина</param>
    /// <returns>True, если плагин запущен</returns>
    Task<bool> StartPluginAsync(string id);

    /// <summary>
    ///     Остановить плагин
    /// </summary>
    /// <param name="id">ID плагина</param>
    /// <returns>True, если плагин остановлен</returns>
    Task<bool> StopPluginAsync(string id);

    /// <summary>
    ///     Установить плагин
    /// </summary>
    /// <param name="packagePath">Путь к пакету плагина</param>
    /// <param name="overwrite">Перезаписать, если уже существует</param>
    /// <returns>True, если плагин установлен</returns>
    Task<bool> InstallPluginAsync(string packagePath, bool overwrite = false);

    /// <summary>
    ///     Удалить плагин
    /// </summary>
    /// <param name="id">ID плагина</param>
    /// <returns>True, если плагин удален</returns>
    Task<bool> RemovePluginAsync(string id);

    /// <summary>
    ///     Получить информацию о плагине
    /// </summary>
    /// <param name="id">ID плагина</param>
    /// <returns>Информация о плагине</returns>
    Task<PluginInfo?> GetPluginInfoAsync(string id);

    /// <summary>
    ///     Проверить зависимости плагина
    /// </summary>
    /// <param name="plugin">Плагин для проверки</param>
    /// <returns>True, если все зависимости выполнены</returns>
    bool CheckDependencies(IPlugin plugin);

    /// <summary>
    ///     Событие загрузки плагина
    /// </summary>
    event EventHandler<PluginEventArgs> PluginLoaded;

    /// <summary>
    ///     Событие выгрузки плагина
    /// </summary>
    event EventHandler<PluginEventArgs> PluginUnloaded;

    /// <summary>
    ///     Событие запуска плагина
    /// </summary>
    event EventHandler<PluginEventArgs> PluginStarted;

    /// <summary>
    ///     Событие остановки плагина
    /// </summary>
    event EventHandler<PluginEventArgs> PluginStopped;
}

/// <summary>
///     Информация о плагине
/// </summary>
public class PluginInfo
{
    public string Id { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string Version { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public string Author { get; set; } = string.Empty;
    public string[] Dependencies { get; set; } = Array.Empty<string>();
    public bool IsLoaded { get; set; }
    public bool IsRunning { get; set; }
    public DateTime? LoadedAt { get; set; }
    public DateTime? StartedAt { get; set; }
    public string FilePath { get; set; } = string.Empty;
    public long FileSize { get; set; }
    public string Type { get; set; } = string.Empty; // CSharp, JavaScript, Go
}

/// <summary>
///     Аргументы событий плагинов
/// </summary>
public class PluginEventArgs : EventArgs
{
    public PluginEventArgs(IPlugin plugin)
    {
        Plugin = plugin;
        Timestamp = DateTime.UtcNow;
    }

    public IPlugin Plugin { get; }
    public DateTime Timestamp { get; }
}
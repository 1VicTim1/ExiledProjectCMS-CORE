namespace ExiledProjectCMS.Core.Interfaces;

/// <summary>
///     Интерфейс сервиса кеширования
/// </summary>
public interface ICacheService
{
    /// <summary>
    ///     Получить значение из кеша
    /// </summary>
    /// <typeparam name="T">Тип возвращаемого значения</typeparam>
    /// <param name="key">Ключ кеша</param>
    /// <returns>Значение из кеша или null, если не найдено</returns>
    Task<T?> GetAsync<T>(string key) where T : class;

    /// <summary>
    ///     Установить значение в кеш
    /// </summary>
    /// <typeparam name="T">Тип значения</typeparam>
    /// <param name="key">Ключ кеша</param>
    /// <param name="value">Значение для кеширования</param>
    /// <param name="expiry">Время жизни в кеше</param>
    Task SetAsync<T>(string key, T value, TimeSpan? expiry = null) where T : class;

    /// <summary>
    ///     Удалить значение из кеша
    /// </summary>
    /// <param name="key">Ключ кеша</param>
    Task RemoveAsync(string key);

    /// <summary>
    ///     Удалить значения из кеша по шаблону
    /// </summary>
    /// <param name="pattern">Шаблон ключей для удаления</param>
    Task RemoveByPatternAsync(string pattern);

    /// <summary>
    ///     Проверить существование ключа в кеше
    /// </summary>
    /// <param name="key">Ключ кеша</param>
    /// <returns>True, если ключ существует</returns>
    Task<bool> ExistsAsync(string key);

    /// <summary>
    ///     Очистить весь кеш
    /// </summary>
    Task ClearAllAsync();

    /// <summary>
    ///     Получить или установить значение в кеш
    /// </summary>
    /// <typeparam name="T">Тип значения</typeparam>
    /// <param name="key">Ключ кеша</param>
    /// <param name="factory">Функция создания значения, если его нет в кеше</param>
    /// <param name="expiry">Время жизни в кеше</param>
    /// <returns>Значение из кеша или созданное функцией</returns>
    Task<T> GetOrSetAsync<T>(string key, Func<Task<T>> factory, TimeSpan? expiry = null) where T : class;
}
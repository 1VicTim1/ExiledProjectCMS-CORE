using System.Text.Json;
using ExiledProjectCMS.Core.Interfaces;
using Microsoft.Extensions.Logging;
using StackExchange.Redis;

namespace ExiledProjectCMS.Infrastructure.Services;

/// <summary>
///     Реализация кеширования через Redis
/// </summary>
public class RedisCacheService : ICacheService
{
    private readonly IDatabase _database;
    private readonly TimeSpan _defaultExpiry;
    private readonly ILogger<RedisCacheService> _logger;
    private readonly IServer _server;

    public RedisCacheService(IConnectionMultiplexer connectionMultiplexer, ILogger<RedisCacheService> logger)
    {
        _database = connectionMultiplexer.GetDatabase();
        _server = connectionMultiplexer.GetServer(connectionMultiplexer.GetEndPoints().First());
        _logger = logger;
        _defaultExpiry = TimeSpan.FromMinutes(30);
    }

    public async Task<T?> GetAsync<T>(string key) where T : class
    {
        try
        {
            var value = await _database.StringGetAsync(key);
            if (!value.HasValue)
            {
                _logger.LogDebug("Значение не найдено в кеше для ключа: {Key}", key);
                return null;
            }

            var result = JsonSerializer.Deserialize<T>(value!);
            _logger.LogDebug("Получено значение из кеша для ключа: {Key}", key);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при получении значения из кеша для ключа: {Key}", key);
            return null;
        }
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? expiry = null) where T : class
    {
        try
        {
            var serializedValue = JsonSerializer.Serialize(value);
            var expiryTime = expiry ?? _defaultExpiry;

            await _database.StringSetAsync(key, serializedValue, expiryTime);
            _logger.LogDebug("Значение добавлено в кеш для ключа: {Key} с временем жизни: {Expiry}", key, expiryTime);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при добавлении значения в кеш для ключа: {Key}", key);
        }
    }

    public async Task RemoveAsync(string key)
    {
        try
        {
            await _database.KeyDeleteAsync(key);
            _logger.LogDebug("Значение удалено из кеша для ключа: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при удалении значения из кеша для ключа: {Key}", key);
        }
    }

    public async Task RemoveByPatternAsync(string pattern)
    {
        try
        {
            var keys = _server.Keys(pattern: pattern).ToArray();
            if (keys.Length > 0)
            {
                await _database.KeyDeleteAsync(keys);
                _logger.LogDebug("Удалено {Count} ключей по шаблону: {Pattern}", keys.Length, pattern);
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при удалении ключей по шаблону: {Pattern}", pattern);
        }
    }

    public async Task<bool> ExistsAsync(string key)
    {
        try
        {
            return await _database.KeyExistsAsync(key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при проверке существования ключа: {Key}", key);
            return false;
        }
    }

    public async Task ClearAllAsync()
    {
        try
        {
            await _server.FlushDatabaseAsync();
            _logger.LogInformation("Кеш полностью очищен");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при очистке кеша");
        }
    }

    public async Task<T> GetOrSetAsync<T>(string key, Func<Task<T>> factory, TimeSpan? expiry = null) where T : class
    {
        var cachedValue = await GetAsync<T>(key);
        if (cachedValue != null) return cachedValue;

        var value = await factory();
        if (value != null) await SetAsync(key, value, expiry);

        return value;
    }
}
using System.Collections.Concurrent;
using System.Text.Json;
using System.Text.RegularExpressions;
using ExiledProjectCMS.Core.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace ExiledProjectCMS.Infrastructure.Services;

/// <summary>
///     Реализация кеширования через Memory Cache
/// </summary>
public class MemoryCacheService : ICacheService
{
    private readonly ConcurrentDictionary<string, byte> _cacheKeys;
    private readonly TimeSpan _defaultExpiry;
    private readonly ILogger<MemoryCacheService> _logger;
    private readonly IMemoryCache _memoryCache;

    public MemoryCacheService(IMemoryCache memoryCache, ILogger<MemoryCacheService> logger)
    {
        _memoryCache = memoryCache;
        _logger = logger;
        _cacheKeys = new ConcurrentDictionary<string, byte>();
        _defaultExpiry = TimeSpan.FromMinutes(30);
    }

    public Task<T?> GetAsync<T>(string key) where T : class
    {
        try
        {
            if (_memoryCache.TryGetValue(key, out var value))
            {
                if (value is string jsonValue)
                {
                    var result = JsonSerializer.Deserialize<T>(jsonValue);
                    _logger.LogDebug("Получено значение из кеша для ключа: {Key}", key);
                    return Task.FromResult(result);
                }

                if (value is T directValue)
                {
                    _logger.LogDebug("Получено значение из кеша для ключа: {Key}", key);
                    return Task.FromResult<T?>(directValue);
                }
            }

            _logger.LogDebug("Значение не найдено в кеше для ключа: {Key}", key);
            return Task.FromResult<T?>(null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при получении значения из кеша для ключа: {Key}", key);
            return Task.FromResult<T?>(null);
        }
    }

    public Task SetAsync<T>(string key, T value, TimeSpan? expiry = null) where T : class
    {
        try
        {
            var options = new MemoryCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = expiry ?? _defaultExpiry,
                Priority = CacheItemPriority.Normal
            };

            options.PostEvictionCallbacks.Add(new PostEvictionCallbackRegistration
            {
                EvictionCallback = (k, v, reason, state) => { _cacheKeys.TryRemove(k.ToString()!, out _); }
            });

            var serializedValue = JsonSerializer.Serialize(value);
            _memoryCache.Set(key, serializedValue, options);
            _cacheKeys.TryAdd(key, 0);

            _logger.LogDebug("Значение добавлено в кеш для ключа: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при добавлении значения в кеш для ключа: {Key}", key);
        }

        return Task.CompletedTask;
    }

    public Task RemoveAsync(string key)
    {
        try
        {
            _memoryCache.Remove(key);
            _cacheKeys.TryRemove(key, out _);
            _logger.LogDebug("Значение удалено из кеша для ключа: {Key}", key);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при удалении значения из кеша для ключа: {Key}", key);
        }

        return Task.CompletedTask;
    }

    public Task RemoveByPatternAsync(string pattern)
    {
        try
        {
            var regex = new Regex(pattern.Replace("*", ".*"), RegexOptions.Compiled);
            var keysToRemove = _cacheKeys.Keys.Where(key => regex.IsMatch(key)).ToList();

            foreach (var key in keysToRemove)
            {
                _memoryCache.Remove(key);
                _cacheKeys.TryRemove(key, out _);
            }

            _logger.LogDebug("Удалено {Count} ключей по шаблону: {Pattern}", keysToRemove.Count, pattern);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при удалении ключей по шаблону: {Pattern}", pattern);
        }

        return Task.CompletedTask;
    }

    public Task<bool> ExistsAsync(string key)
    {
        var exists = _cacheKeys.ContainsKey(key);
        return Task.FromResult(exists);
    }

    public Task ClearAllAsync()
    {
        try
        {
            var keysToRemove = _cacheKeys.Keys.ToList();
            foreach (var key in keysToRemove) _memoryCache.Remove(key);

            _cacheKeys.Clear();
            _logger.LogInformation("Кеш полностью очищен");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при очистке кеша");
        }

        return Task.CompletedTask;
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
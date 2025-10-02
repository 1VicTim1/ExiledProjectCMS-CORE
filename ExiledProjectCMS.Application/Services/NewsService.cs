using ExiledProjectCMS.Application.DTOs.News;
using ExiledProjectCMS.Core.Repositories;
using Microsoft.Extensions.Logging;

namespace ExiledProjectCMS.Application.Services;

/// <summary>
///     Сервис новостей для системы CMS
/// </summary>
public class NewsService : INewsService
{
    private readonly ILogger<NewsService> _logger;
    private readonly INewsRepository _newsRepository;

    public NewsService(INewsRepository newsRepository, ILogger<NewsService> logger)
    {
        _newsRepository = newsRepository;
        _logger = logger;
    }

    /// <summary>
    ///     Получение списка новостей с пагинацией для интеграции с GMLLauncher
    /// </summary>
    /// <param name="limit">Ограничение количества новостей</param>
    /// <param name="offset">Смещение для пагинации</param>
    /// <returns>Список новостей в формате, совместимом с GMLLauncher</returns>
    public async Task<IEnumerable<NewsResponse>> GetNewsAsync(int? limit = null, int? offset = null)
    {
        try
        {
            _logger.LogInformation("Запрос новостей с параметрами: limit={Limit}, offset={Offset}", limit, offset);

            // Получение новостей из репозитория
            var news = await _newsRepository.GetAsync(limit, offset);

            // Преобразование доменных моделей в DTO для API
            var result = news.Select(n => new NewsResponse
            {
                Id = n.Id,
                Title = n.Title,
                Description = n.Description,
                CreatedAt = n.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            }).ToList();

            _logger.LogInformation("Возвращено {Count} новостей", result.Count);
            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при получении новостей");
            return Enumerable.Empty<NewsResponse>();
        }
    }
}
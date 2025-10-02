using ExiledProjectCMS.Application.DTOs.News;

namespace ExiledProjectCMS.Application.Services;

/// <summary>
///     Интерфейс сервиса новостей для системы CMS
/// </summary>
public interface INewsService
{
    /// <summary>
    ///     Получение списка новостей с пагинацией
    /// </summary>
    /// <param name="limit">Ограничение количества новостей</param>
    /// <param name="offset">Смещение для пагинации</param>
    /// <returns>Список новостей</returns>
    Task<IEnumerable<NewsResponse>> GetNewsAsync(int? limit = null, int? offset = null);
}
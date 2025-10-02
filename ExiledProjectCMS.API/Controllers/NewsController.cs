using System.ComponentModel.DataAnnotations;
using ExiledProjectCMS.Application.DTOs.News;
using ExiledProjectCMS.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace ExiledProjectCMS.API.Controllers;

/// <summary>
///     Контроллер новостей для интеграции с GMLLauncher
/// </summary>
[ApiController]
[Route("api")]
[Produces("application/json")]
[Tags("GMLLauncher News")]
public class NewsController : ControllerBase
{
    private readonly ILogger<NewsController> _logger;
    private readonly INewsService _newsService;

    public NewsController(INewsService newsService, ILogger<NewsController> logger)
    {
        _newsService = newsService;
        _logger = logger;
    }

    /// <summary>
    ///     Получение списка новостей с поддержкой пагинации для GMLLauncher
    /// </summary>
    /// <remarks>
    ///     Возвращает список опубликованных новостей в формате, совместимом с GMLLauncher API.
    ///     Поддерживает пагинацию через параметры:
    ///     - **limit**: максимальное количество новостей (по умолчанию без ограничений)
    ///     - **offset**: количество пропускаемых новостей (по умолчанию 0)
    ///     Новости возвращаются в порядке убывания даты публикации (новые сначала).
    ///     Примеры запросов:
    ///     - `GET /api/news` - все новости
    ///     - `GET /api/news?limit=5` - первые 5 новостей
    ///     - `GET /api/news?limit=5&amp;offset=10` - 5 новостей, пропустив первые 10
    ///     Пример ответа:
    ///     ```json
    ///     [
    ///     {
    ///     "id": 1,
    ///     "title": "Обновление сервера v1.0",
    ///     "description": "Сервер обновлен до последней версии...",
    ///     "createdAt": "2024-01-01T12:00:00.000Z"
    ///     }
    ///     ]
    ///     ```
    /// </remarks>
    /// <param name="limit">Ограничение количества новостей (необязательный параметр, >= 0)</param>
    /// <param name="offset">Смещение для пагинации (необязательный параметр, >= 0)</param>
    /// <returns>Массив новостей в формате JSON, совместимом с GMLLauncher API</returns>
    /// <response code="200">Успешно получены новости</response>
    /// <response code="400">Некорректные параметры запроса (отрицательные значения limit или offset)</response>
    /// <response code="500">Внутренняя ошибка сервера</response>
    [HttpGet("news")]
    [ProducesResponseType(typeof(NewsResponseSwagger[]), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(object), StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetNews(
        [FromQuery] [Range(0, int.MaxValue, ErrorMessage = "Параметр limit должен быть больше или равен 0")]
        int? limit = null,
        [FromQuery] [Range(0, int.MaxValue, ErrorMessage = "Параметр offset должен быть больше или равен 0")]
        int? offset = null)
    {
        try
        {
            _logger.LogInformation("Получен запрос новостей с параметрами: limit={Limit}, offset={Offset}", limit,
                offset);

            // Валидация параметров пагинации
            if (limit.HasValue && limit.Value < 0)
            {
                _logger.LogWarning("Получен некорректный параметр limit: {Limit}", limit);
                return BadRequest(new { Message = "Параметр limit должен быть больше или равен 0" });
            }

            if (offset.HasValue && offset.Value < 0)
            {
                _logger.LogWarning("Получен некорректный параметр offset: {Offset}", offset);
                return BadRequest(new { Message = "Параметр offset должен быть больше или равен 0" });
            }

            // Получение новостей через сервис
            var news = await _newsService.GetNewsAsync(limit, offset);

            _logger.LogInformation("Успешно получено {Count} новостей", news.Count());

            // Возврат данных в формате, совместимом с GMLLauncher API
            return Ok(news.Select(n => new
            {
                id = n.Id,
                title = n.Title,
                description = n.Description,
                createdAt = n.CreatedAt
            }).ToArray());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при получении новостей с параметрами: limit={Limit}, offset={Offset}", limit,
                offset);
            return StatusCode(StatusCodes.Status500InternalServerError, new { Message = "Внутренняя ошибка сервера" });
        }
    }
}
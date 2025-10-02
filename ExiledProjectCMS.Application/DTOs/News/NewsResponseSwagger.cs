using System.ComponentModel.DataAnnotations;

namespace ExiledProjectCMS.Application.DTOs.News;

/// <summary>
///     Ответ с данными новости для GMLLauncher API
/// </summary>
/// <example>
///     {
///     "id": 1,
///     "title": "Обновление сервера v1.0",
///     "description": "Сервер обновлен до последней версии Minecraft. Добавлены новые функции и исправлены ошибки.",
///     "createdAt": "2024-01-01T12:00:00.000Z"
///     }
/// </example>
public class NewsResponseSwagger
{
    /// <summary>
    ///     Уникальный идентификатор новости
    /// </summary>
    /// <example>1</example>
    [Required]
    public int Id { get; set; }

    /// <summary>
    ///     Заголовок новости
    /// </summary>
    /// <example>Обновление сервера v1.0</example>
    [Required]
    public string Title { get; set; } = string.Empty;

    /// <summary>
    ///     Полное содержание новости
    /// </summary>
    /// <example>Сервер обновлен до последней версии Minecraft. Добавлены новые функции и исправлены ошибки.</example>
    [Required]
    public string Description { get; set; } = string.Empty;

    /// <summary>
    ///     Дата публикации новости в формате ISO 8601
    /// </summary>
    /// <example>2024-01-01T12:00:00.000Z</example>
    [Required]
    public string CreatedAt { get; set; } = string.Empty;
}
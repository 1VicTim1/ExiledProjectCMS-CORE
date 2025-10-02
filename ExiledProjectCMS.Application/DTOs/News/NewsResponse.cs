namespace ExiledProjectCMS.Application.DTOs.News;

/// <summary>
///     Ответ с данными новости для интеграции с GMLLauncher
/// </summary>
public class NewsResponse
{
    /// <summary>
    ///     Уникальный идентификатор новости
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    ///     Заголовок новости
    /// </summary>
    public string Title { get; set; } = string.Empty;

    /// <summary>
    ///     Содержание новости
    /// </summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>
    ///     Дата публикации новости в формате ISO 8601
    /// </summary>
    public string CreatedAt { get; set; } = string.Empty;
}
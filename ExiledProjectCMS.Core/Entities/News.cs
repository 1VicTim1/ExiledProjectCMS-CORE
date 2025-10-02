namespace ExiledProjectCMS.Core.Entities;

/// <summary>
///     Доменная модель новости для системы CMS
/// </summary>
public class News
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
    ///     Дата и время публикации новости
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    ///     Дата последнего изменения новости
    /// </summary>
    public DateTime UpdatedAt { get; set; }

    /// <summary>
    ///     Флаг публикации новости
    /// </summary>
    public bool IsPublished { get; set; }
}
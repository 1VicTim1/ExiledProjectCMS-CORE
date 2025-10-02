namespace ExiledProjectCMS.Core.Entities;

/// <summary>
///     Доменная модель роли пользователя
/// </summary>
public class Role
{
    /// <summary>
    ///     Уникальный идентификатор роли
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    ///     Название роли (уникальное)
    /// </summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    ///     Отображаемое название роли
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    ///     Описание роли
    /// </summary>
    public string? Description { get; set; }

    /// <summary>
    ///     Цвет роли в HEX формате для отображения
    /// </summary>
    public string? Color { get; set; }

    /// <summary>
    ///     Приоритет роли (чем выше число, тем выше приоритет)
    /// </summary>
    public int Priority { get; set; }

    /// <summary>
    ///     Флаг системной роли (нельзя удалить)
    /// </summary>
    public bool IsSystem { get; set; }

    /// <summary>
    ///     Дата создания роли
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    ///     Дата последнего обновления роли
    /// </summary>
    public DateTime UpdatedAt { get; set; }

    /// <summary>
    ///     Связи роли с пользователями
    /// </summary>
    public virtual ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();

    /// <summary>
    ///     Связи роли с разрешениями
    /// </summary>
    public virtual ICollection<RolePermission> RolePermissions { get; set; } = new List<RolePermission>();
}
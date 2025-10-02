namespace ExiledProjectCMS.Core.Entities;

/// <summary>
///     Доменная модель разрешения (права доступа)
/// </summary>
public class Permission
{
    /// <summary>
    ///     Уникальный идентификатор разрешения
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    ///     Системное имя разрешения (уникальное)
    /// </summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    ///     Отображаемое название разрешения
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    ///     Описание разрешения
    /// </summary>
    public string? Description { get; set; }

    /// <summary>
    ///     Категория разрешения (например: "News", "Users", "Admin")
    /// </summary>
    public string Category { get; set; } = string.Empty;

    /// <summary>
    ///     Флаг системного разрешения (нельзя удалить)
    /// </summary>
    public bool IsSystem { get; set; }

    /// <summary>
    ///     Дата создания разрешения
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    ///     Связи разрешения с ролями
    /// </summary>
    public virtual ICollection<RolePermission> RolePermissions { get; set; } = new List<RolePermission>();
}

/// <summary>
///     Константы системных разрешений
/// </summary>
public static class Permissions
{
    // Управление новостями
    public const string NewsCreate = "news.create";
    public const string NewsRead = "news.read";
    public const string NewsUpdate = "news.update";
    public const string NewsDelete = "news.delete";
    public const string NewsPublish = "news.publish";

    // Управление пользователями
    public const string UsersRead = "users.read";
    public const string UsersUpdate = "users.update";
    public const string UsersDelete = "users.delete";
    public const string UsersBlock = "users.block";

    // Административные функции
    public const string AdminPanel = "admin.panel";
    public const string AdminRoles = "admin.roles";
    public const string AdminPermissions = "admin.permissions";
    public const string AdminSettings = "admin.settings";

    // Система
    public const string SystemLogs = "system.logs";
    public const string SystemBackup = "system.backup";
}
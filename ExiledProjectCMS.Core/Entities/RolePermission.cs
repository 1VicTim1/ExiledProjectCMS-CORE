namespace ExiledProjectCMS.Core.Entities;

/// <summary>
///     Связующая таблица роли и разрешения (многие ко многим)
/// </summary>
public class RolePermission
{
    /// <summary>
    ///     ID роли
    /// </summary>
    public int RoleId { get; set; }

    /// <summary>
    ///     Роль
    /// </summary>
    public virtual Role Role { get; set; } = null!;

    /// <summary>
    ///     ID разрешения
    /// </summary>
    public int PermissionId { get; set; }

    /// <summary>
    ///     Разрешение
    /// </summary>
    public virtual Permission Permission { get; set; } = null!;

    /// <summary>
    ///     Дата назначения разрешения роли
    /// </summary>
    public DateTime AssignedAt { get; set; }
}
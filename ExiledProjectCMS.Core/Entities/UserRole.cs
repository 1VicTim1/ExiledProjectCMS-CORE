namespace ExiledProjectCMS.Core.Entities;

/// <summary>
///     Связующая таблица пользователя и роли (многие ко многим)
/// </summary>
public class UserRole
{
    /// <summary>
    ///     ID пользователя
    /// </summary>
    public int UserId { get; set; }

    /// <summary>
    ///     Пользователь
    /// </summary>
    public virtual User User { get; set; } = null!;

    /// <summary>
    ///     ID роли
    /// </summary>
    public int RoleId { get; set; }

    /// <summary>
    ///     Роль
    /// </summary>
    public virtual Role Role { get; set; } = null!;

    /// <summary>
    ///     Дата назначения роли пользователю
    /// </summary>
    public DateTime AssignedAt { get; set; }

    /// <summary>
    ///     ID пользователя, который назначил роль (может быть null для системных назначений)
    /// </summary>
    public int? AssignedByUserId { get; set; }

    /// <summary>
    ///     Пользователь, который назначил роль
    /// </summary>
    public virtual User? AssignedByUser { get; set; }
}
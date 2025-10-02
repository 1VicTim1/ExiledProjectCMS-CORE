namespace ExiledProjectCMS.Core.Entities;

/// <summary>
///     Доменная модель пользователя для интеграции с GMLLauncher
/// </summary>
public class User
{
    /// <summary>
    ///     Уникальный идентификатор пользователя
    /// </summary>
    public int Id { get; set; }

    /// <summary>
    ///     Логин пользователя для авторизации (уникальный)
    /// </summary>
    public string Login { get; set; } = string.Empty;

    /// <summary>
    ///     Email пользователя (уникальный)
    /// </summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    ///     Хэшированный пароль пользователя (может быть null для OAuth2 пользователей)
    /// </summary>
    public string? PasswordHash { get; set; }

    /// <summary>
    ///     Отображаемое имя пользователя
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    ///     UUID пользователя в формате GUID для интеграции с Minecraft
    /// </summary>
    public Guid UserUuid { get; set; }

    /// <summary>
    ///     Флаг подтверждения email адреса
    /// </summary>
    public bool IsEmailConfirmed { get; set; }

    /// <summary>
    ///     Флаг блокировки пользователя
    /// </summary>
    public bool IsBlocked { get; set; }

    /// <summary>
    ///     Причина блокировки пользователя (если заблокирован)
    /// </summary>
    public string? BlockReason { get; set; }

    /// <summary>
    ///     Discord ID пользователя для OAuth2 авторизации
    /// </summary>
    public string? DiscordId { get; set; }

    /// <summary>
    ///     URL аватара пользователя
    /// </summary>
    public string? AvatarUrl { get; set; }

    /// <summary>
    ///     Дата последней активности пользователя
    /// </summary>
    public DateTime? LastLoginAt { get; set; }

    /// <summary>
    ///     IP адрес последнего входа
    /// </summary>
    public string? LastLoginIp { get; set; }

    /// <summary>
    ///     Дата создания аккаунта
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    ///     Дата последнего обновления данных пользователя
    /// </summary>
    public DateTime UpdatedAt { get; set; }

    /// <summary>
    ///     Роли пользователя
    /// </summary>
    public virtual ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();

    /// <summary>
    ///     Проверка наличия конкретной роли у пользователя
    /// </summary>
    /// <param name="roleName">Название роли</param>
    /// <returns>True если роль есть у пользователя</returns>
    public bool HasRole(string roleName)
    {
        return UserRoles.Any(ur => ur.Role?.Name?.Equals(roleName, StringComparison.OrdinalIgnoreCase) == true);
    }

    /// <summary>
    ///     Проверка наличия разрешения у пользователя
    /// </summary>
    /// <param name="permission">Название разрешения</param>
    /// <returns>True если разрешение есть у пользователя</returns>
    public bool HasPermission(string permission)
    {
        return UserRoles.Any(ur =>
            ur.Role?.RolePermissions?.Any(rp =>
                rp.Permission?.Name?.Equals(permission, StringComparison.OrdinalIgnoreCase) == true) == true);
    }
}
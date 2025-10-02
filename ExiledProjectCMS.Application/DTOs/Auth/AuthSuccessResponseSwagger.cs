using System.ComponentModel.DataAnnotations;

namespace ExiledProjectCMS.Application.DTOs.Auth;

/// <summary>
///     Успешный ответ на запрос авторизации для GMLLauncher API
/// </summary>
/// <example>
///     {
///     "Login": "GamerVII",
///     "UserUuid": "c07a9841-2275-4ba0-8f1c-2e1599a1f22f",
///     "Message": "Успешная авторизация"
///     }
/// </example>
public class AuthSuccessResponseSwagger
{
    /// <summary>
    ///     Логин пользователя
    /// </summary>
    /// <example>GamerVII</example>
    [Required]
    public string Login { get; set; } = string.Empty;

    /// <summary>
    ///     UUID пользователя в формате строки для интеграции с Minecraft
    /// </summary>
    /// <example>c07a9841-2275-4ba0-8f1c-2e1599a1f22f</example>
    [Required]
    public string UserUuid { get; set; } = string.Empty;

    /// <summary>
    ///     Сообщение о результате авторизации
    /// </summary>
    /// <example>Успешная авторизация</example>
    [Required]
    public string Message { get; set; } = string.Empty;
}
using System.ComponentModel.DataAnnotations;

namespace ExiledProjectCMS.Application.DTOs.Auth;

/// <summary>
///     Ответ об ошибке авторизации для GMLLauncher API
/// </summary>
/// <example>
///     {
///     "Message": "Неверный логин или пароль"
///     }
/// </example>
public class AuthErrorResponseSwagger
{
    /// <summary>
    ///     Сообщение об ошибке авторизации
    /// </summary>
    /// <example>Неверный логин или пароль</example>
    [Required]
    public string Message { get; set; } = string.Empty;
}
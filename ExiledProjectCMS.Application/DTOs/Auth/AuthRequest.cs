using System.ComponentModel.DataAnnotations;

namespace ExiledProjectCMS.Application.DTOs.Auth;

/// <summary>
///     Запрос на авторизацию пользователя для GMLLauncher
/// </summary>
public class AuthRequest
{
    /// <summary>
    ///     Логин пользователя
    /// </summary>
    [Required(ErrorMessage = "Логин обязателен для заполнения")]
    [StringLength(50, ErrorMessage = "Логин не может быть длиннее 50 символов")]
    public string Login { get; set; } = string.Empty;

    /// <summary>
    ///     Пароль пользователя
    /// </summary>
    [Required(ErrorMessage = "Пароль обязателен для заполнения")]
    public string Password { get; set; } = string.Empty;
}
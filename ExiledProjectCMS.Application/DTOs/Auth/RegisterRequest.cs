using System.ComponentModel.DataAnnotations;

namespace ExiledProjectCMS.Application.DTOs.Auth;

/// <summary>
///     Запрос на регистрацию нового пользователя
/// </summary>
public class RegisterRequest
{
    /// <summary>
    ///     Логин пользователя (уникальный)
    /// </summary>
    [Required(ErrorMessage = "Логин обязателен для заполнения")]
    [StringLength(50, MinimumLength = 3, ErrorMessage = "Логин должен содержать от 3 до 50 символов")]
    [RegularExpression(@"^[a-zA-Z0-9_]+$",
        ErrorMessage = "Логин может содержать только латинские буквы, цифры и знак подчеркивания")]
    public string Login { get; set; } = string.Empty;

    /// <summary>
    ///     Email пользователя (уникальный)
    /// </summary>
    [Required(ErrorMessage = "Email обязателен для заполнения")]
    [EmailAddress(ErrorMessage = "Некорректный формат email адреса")]
    [StringLength(255, ErrorMessage = "Email не может быть длиннее 255 символов")]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    ///     Пароль пользователя
    /// </summary>
    [Required(ErrorMessage = "Пароль обязателен для заполнения")]
    [StringLength(100, MinimumLength = 6, ErrorMessage = "Пароль должен содержать от 6 до 100 символов")]
    [RegularExpression(@"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{6,}$",
        ErrorMessage = "Пароль должен содержать минимум одну заглавную букву, одну строчную букву и одну цифру")]
    public string Password { get; set; } = string.Empty;

    /// <summary>
    ///     Подтверждение пароля
    /// </summary>
    [Required(ErrorMessage = "Подтверждение пароля обязательно")]
    [Compare("Password", ErrorMessage = "Пароли не совпадают")]
    public string ConfirmPassword { get; set; } = string.Empty;

    /// <summary>
    ///     Отображаемое имя пользователя (опционально)
    /// </summary>
    [StringLength(100, ErrorMessage = "Отображаемое имя не может быть длиннее 100 символов")]
    public string? DisplayName { get; set; }
}
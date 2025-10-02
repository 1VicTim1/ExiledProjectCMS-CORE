using ExiledProjectCMS.Application.DTOs.Auth;

namespace ExiledProjectCMS.Application.Services;

/// <summary>
///     Интерфейс сервиса аутентификации для интеграции с GMLLauncher и управления пользователями
/// </summary>
public interface IAuthService
{
    /// <summary>
    ///     Авторизация пользователя по логину и паролю
    /// </summary>
    /// <param name="request">Данные для авторизации</param>
    /// <returns>Результат авторизации</returns>
    Task<AuthResponse> SignInAsync(AuthRequest request);

    /// <summary>
    ///     Регистрация нового пользователя
    /// </summary>
    /// <param name="request">Данные для регистрации</param>
    /// <returns>Результат регистрации</returns>
    Task<RegisterResponse> RegisterAsync(RegisterRequest request);

    /// <summary>
    ///     Проверка доступности логина
    /// </summary>
    /// <param name="login">Логин для проверки</param>
    /// <returns>True если логин доступен</returns>
    Task<bool> IsLoginAvailableAsync(string login);

    /// <summary>
    ///     Проверка доступности email
    /// </summary>
    /// <param name="email">Email для проверки</param>
    /// <returns>True если email доступен</returns>
    Task<bool> IsEmailAvailableAsync(string email);

    /// <summary>
    ///     Подтверждение email адреса пользователя
    /// </summary>
    /// <param name="userId">ID пользователя</param>
    /// <param name="confirmationToken">Токен подтверждения</param>
    /// <returns>True если подтверждение прошло успешно</returns>
    Task<bool> ConfirmEmailAsync(int userId, string confirmationToken);
}
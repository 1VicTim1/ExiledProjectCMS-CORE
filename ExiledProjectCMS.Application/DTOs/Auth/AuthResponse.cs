namespace ExiledProjectCMS.Application.DTOs.Auth;

/// <summary>
///     Ответ на запрос авторизации для интеграции с GMLLauncher
/// </summary>
public class AuthResponse
{
    /// <summary>
    ///     Логин пользователя (возвращается при успешной авторизации)
    /// </summary>
    public string? Login { get; set; }

    /// <summary>
    ///     UUID пользователя в формате строки (возвращается при успешной авторизации)
    /// </summary>
    public string? UserUuid { get; set; }

    /// <summary>
    ///     Сообщение о результате авторизации
    /// </summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>
    ///     HTTP статус код ответа
    /// </summary>
    public int StatusCode { get; set; }

    /// <summary>
    ///     Создание успешного ответа авторизации
    /// </summary>
    /// <param name="login">Логин пользователя</param>
    /// <param name="userUuid">UUID пользователя</param>
    /// <returns>Успешный ответ</returns>
    public static AuthResponse Success(string login, Guid userUuid)
    {
        return new AuthResponse
        {
            Login = login,
            UserUuid = userUuid.ToString(),
            Message = "Успешная авторизация",
            StatusCode = 200
        };
    }

    /// <summary>
    ///     Создание ответа об ошибке авторизации
    /// </summary>
    /// <param name="message">Сообщение об ошибке</param>
    /// <param name="statusCode">HTTP статус код</param>
    /// <returns>Ответ об ошибке</returns>
    public static AuthResponse Error(string message, int statusCode)
    {
        return new AuthResponse
        {
            Message = message,
            StatusCode = statusCode
        };
    }
}
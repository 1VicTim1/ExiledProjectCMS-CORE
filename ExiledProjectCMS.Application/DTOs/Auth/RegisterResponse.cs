namespace ExiledProjectCMS.Application.DTOs.Auth;

/// <summary>
///     Ответ на запрос регистрации пользователя
/// </summary>
public class RegisterResponse
{
    /// <summary>
    ///     Логин зарегистрированного пользователя
    /// </summary>
    public string Login { get; set; } = string.Empty;

    /// <summary>
    ///     Email зарегистрированного пользователя
    /// </summary>
    public string Email { get; set; } = string.Empty;

    /// <summary>
    ///     UUID пользователя в формате строки
    /// </summary>
    public string UserUuid { get; set; } = string.Empty;

    /// <summary>
    ///     Отображаемое имя пользователя
    /// </summary>
    public string DisplayName { get; set; } = string.Empty;

    /// <summary>
    ///     Сообщение о результате регистрации
    /// </summary>
    public string Message { get; set; } = string.Empty;

    /// <summary>
    ///     Флаг необходимости подтверждения email
    /// </summary>
    public bool RequireEmailConfirmation { get; set; }

    /// <summary>
    ///     Дата создания аккаунта
    /// </summary>
    public DateTime CreatedAt { get; set; }

    /// <summary>
    ///     Флаг успешности регистрации
    /// </summary>
    public bool IsSuccess { get; set; }

    /// <summary>
    ///     Сообщение об ошибке (если есть)
    /// </summary>
    public string? ErrorMessage { get; set; }

    /// <summary>
    ///     Создание успешного ответа регистрации
    /// </summary>
    /// <param name="login">Логин пользователя</param>
    /// <param name="email">Email пользователя</param>
    /// <param name="userUuid">UUID пользователя</param>
    /// <param name="displayName">Отображаемое имя</param>
    /// <param name="requireEmailConfirmation">Требуется ли подтверждение email</param>
    /// <returns>Успешный ответ регистрации</returns>
    public static RegisterResponse Success(string login, string email, Guid userUuid, string displayName,
        bool requireEmailConfirmation = true)
    {
        return new RegisterResponse
        {
            IsSuccess = true,
            Login = login,
            Email = email,
            UserUuid = userUuid.ToString(),
            DisplayName = displayName,
            Message = requireEmailConfirmation
                ? "Регистрация прошла успешно. Пожалуйста, подтвердите ваш email адрес."
                : "Регистрация прошла успешно.",
            RequireEmailConfirmation = requireEmailConfirmation,
            CreatedAt = DateTime.UtcNow
        };
    }

    /// <summary>
    ///     Создание ответа об ошибке регистрации
    /// </summary>
    /// <param name="message">Сообщение об ошибке</param>
    /// <returns>Ответ об ошибке</returns>
    public static RegisterResponse Error(string message)
    {
        return new RegisterResponse
        {
            IsSuccess = false,
            ErrorMessage = message,
            Message = message
        };
    }
}
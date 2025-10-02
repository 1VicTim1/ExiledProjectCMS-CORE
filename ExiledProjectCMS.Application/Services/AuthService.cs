using System.Security.Cryptography;
using System.Text;
using ExiledProjectCMS.Application.DTOs.Auth;
using ExiledProjectCMS.Core.Entities;
using ExiledProjectCMS.Core.Repositories;
using Microsoft.Extensions.Logging;

namespace ExiledProjectCMS.Application.Services;

/// <summary>
///     Сервис аутентификации для интеграции с GMLLauncher и управления пользователями
/// </summary>
public class AuthService : IAuthService
{
    private readonly ILogger<AuthService> _logger;
    private readonly IUserRepository _userRepository;

    public AuthService(IUserRepository userRepository, ILogger<AuthService> logger)
    {
        _userRepository = userRepository;
        _logger = logger;
    }

    /// <summary>
    ///     Авторизация пользователя по логину и паролю
    /// </summary>
    /// <param name="request">Данные для авторизации</param>
    /// <returns>Результат авторизации в формате, совместимом с GMLLauncher</returns>
    public async Task<AuthResponse> SignInAsync(AuthRequest request)
    {
        try
        {
            // Поиск пользователя по логину
            var user = await _userRepository.GetByLoginAsync(request.Login);

            if (user == null)
            {
                _logger.LogWarning("Попытка авторизации с несуществующим логином: {Login}", request.Login);
                return AuthResponse.Error("Пользователь не найден", 404);
            }

            // Проверка блокировки пользователя
            if (user.IsBlocked)
            {
                var reason = string.IsNullOrEmpty(user.BlockReason) ? "Не указана" : user.BlockReason;
                _logger.LogWarning("Попытка авторизации заблокированного пользователя: {Login}, причина: {Reason}",
                    request.Login, reason);
                return AuthResponse.Error($"Пользователь заблокирован. Причина: {reason}", 403);
            }

            // Проверка пароля
            var passwordHash = HashPassword(request.Password);
            if (user.PasswordHash != passwordHash)
            {
                _logger.LogWarning("Неверный пароль для пользователя: {Login}", request.Login);
                return AuthResponse.Error("Неверный логин или пароль", 401);
            }

            _logger.LogInformation("Успешная авторизация пользователя: {Login}", request.Login);
            return AuthResponse.Success(user.Login, user.UserUuid);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при авторизации пользователя: {Login}", request.Login);
            return AuthResponse.Error("Внутренняя ошибка сервера", 500);
        }
    }

    /// <summary>
    ///     Регистрация нового пользователя
    /// </summary>
    /// <param name="request">Данные для регистрации</param>
    /// <returns>Результат регистрации</returns>
    public async Task<RegisterResponse> RegisterAsync(RegisterRequest request)
    {
        try
        {
            _logger.LogInformation("Получен запрос на регистрацию пользователя: {Login}, {Email}", request.Login,
                request.Email);

            // Проверка доступности логина
            if (!await IsLoginAvailableAsync(request.Login))
            {
                _logger.LogWarning("Попытка регистрации с уже занятым логином: {Login}", request.Login);
                return RegisterResponse.Error("Логин уже занят");
            }

            // Проверка доступности email
            if (!await IsEmailAvailableAsync(request.Email))
            {
                _logger.LogWarning("Попытка регистрации с уже занятым email: {Email}", request.Email);
                return RegisterResponse.Error("Email уже занят");
            }

            // Создание нового пользователя
            var user = new User
            {
                Login = request.Login,
                Email = request.Email,
                DisplayName = request.DisplayName ?? request.Login,
                PasswordHash = HashPassword(request.Password),
                UserUuid = Guid.NewGuid(),
                IsEmailConfirmed = false, // По умолчанию требуется подтверждение email
                IsBlocked = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            // Сохранение пользователя в базе данных
            var createdUser = await _userRepository.CreateAsync(user);

            _logger.LogInformation("Пользователь успешно зарегистрирован: {Login} ({Email})", createdUser.Login,
                createdUser.Email);

            return RegisterResponse.Success(
                createdUser.Login,
                createdUser.Email,
                createdUser.UserUuid,
                createdUser.DisplayName
            );
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при регистрации пользователя: {Login}, {Email}", request.Login, request.Email);
            return RegisterResponse.Error("Внутренняя ошибка сервера");
        }
    }

    /// <summary>
    ///     Проверка доступности логина
    /// </summary>
    /// <param name="login">Логин для проверки</param>
    /// <returns>True если логин доступен</returns>
    public async Task<bool> IsLoginAvailableAsync(string login)
    {
        try
        {
            var existingUser = await _userRepository.GetByLoginAsync(login);
            return existingUser == null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при проверке доступности логина: {Login}", login);
            return false; // В случае ошибки считаем логин недоступным
        }
    }

    /// <summary>
    ///     Проверка доступности email
    /// </summary>
    /// <param name="email">Email для проверки</param>
    /// <returns>True если email доступен</returns>
    public async Task<bool> IsEmailAvailableAsync(string email)
    {
        try
        {
            var existingUser = await _userRepository.GetByEmailAsync(email);
            return existingUser == null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при проверке доступности email: {Email}", email);
            return false; // В случае ошибки считаем email недоступным
        }
    }

    /// <summary>
    ///     Подтверждение email адреса пользователя
    /// </summary>
    /// <param name="userId">ID пользователя</param>
    /// <param name="confirmationToken">Токен подтверждения</param>
    /// <returns>True если подтверждение прошло успешно</returns>
    public async Task<bool> ConfirmEmailAsync(int userId, string confirmationToken)
    {
        try
        {
            // TODO: Реализовать логику подтверждения email с токенами
            // Пока что простая заглушка
            var user = await _userRepository.GetByIdAsync(userId);
            if (user == null) return false;

            user.IsEmailConfirmed = true;
            user.UpdatedAt = DateTime.UtcNow;

            await _userRepository.UpdateAsync(user);

            _logger.LogInformation("Email подтвержден для пользователя: {UserId} ({Email})", userId, user.Email);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Ошибка при подтверждении email для пользователя: {UserId}", userId);
            return false;
        }
    }

    /// <summary>
    ///     Хеширование пароля с использованием SHA256
    /// </summary>
    /// <param name="password">Пароль для хеширования</param>
    /// <returns>Хешированный пароль</returns>
    private static string HashPassword(string password)
    {
        using var sha256 = SHA256.Create();
        var hashedBytes = sha256.ComputeHash(Encoding.UTF8.GetBytes(password));
        return Convert.ToBase64String(hashedBytes);
    }
}
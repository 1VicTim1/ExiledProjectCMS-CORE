using ExiledProjectCMS.Application.DTOs.Auth;
using ExiledProjectCMS.Application.Services;
using Microsoft.AspNetCore.Mvc;

namespace ExiledProjectCMS.API.Controllers;

/// <summary>
///     Контроллер аутентификации для интеграции с GMLLauncher
/// </summary>
[ApiController]
[Route("api/v1/integrations/auth")]
[Produces("application/json")]
[Tags("GMLLauncher Authentication")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _authService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(IAuthService authService, ILogger<AuthController> logger)
    {
        _authService = authService;
        _logger = logger;
    }

    /// <summary>
    ///     Авторизация пользователя для GMLLauncher
    /// </summary>
    /// <remarks>
    ///     Эндпоинт для авторизации пользователей через GMLLauncher.
    ///     Поддерживает следующие сценарии:
    ///     - **200 OK**: Успешная авторизация
    ///     - **401 Unauthorized**: Неверный логин или пароль
    ///     - **403 Forbidden**: Пользователь заблокирован
    ///     - **404 Not Found**: Пользователь не найден
    ///     Пример запроса:
    ///     ```json
    ///     {
    ///     "Login": "GamerVII",
    ///     "Password": "your_password"
    ///     }
    ///     ```
    /// </remarks>
    /// <param name="request">Данные для авторизации (логин и пароль)</param>
    /// <returns>Результат авторизации в формате, совместимом с GMLLauncher API</returns>
    /// <response code="200">Успешная авторизация пользователя</response>
    /// <response code="401">Неверный логин или пароль</response>
    /// <response code="403">Пользователь заблокирован</response>
    /// <response code="404">Пользователь не найден</response>
    /// <response code="400">Некорректные данные запроса</response>
    /// <response code="500">Внутренняя ошибка сервера</response>
    [HttpPost("signin")]
    [ProducesResponseType(typeof(AuthSuccessResponseSwagger), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(AuthErrorResponseSwagger), StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(AuthErrorResponseSwagger), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(AuthErrorResponseSwagger), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(AuthErrorResponseSwagger), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(AuthErrorResponseSwagger), StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> SignIn([FromBody] AuthRequest request)
    {
        try
        {
            _logger.LogInformation("Получен запрос на авторизацию для пользователя: {Login}", request.Login);

            // Валидация входных данных
            if (!ModelState.IsValid)
            {
                _logger.LogWarning("Получены некорректные данные для авторизации: {Login}", request.Login);
                return BadRequest(new { Message = "Некорректные данные запроса" });
            }

            // Выполнение авторизации через сервис
            var result = await _authService.SignInAsync(request);

            // Возврат ответа с соответствующим HTTP статусом
            return result.StatusCode switch
            {
                200 => Ok(new
                {
                    result.Login,
                    result.UserUuid,
                    result.Message
                }),
                401 => Unauthorized(new { result.Message }),
                403 => StatusCode(StatusCodes.Status403Forbidden, new { result.Message }),
                404 => NotFound(new { result.Message }),
                _ => StatusCode(StatusCodes.Status500InternalServerError, new { Message = "Внутренняя ошибка сервера" })
            };
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Неожиданная ошибка при обработке запроса авторизации для пользователя: {Login}",
                request.Login);
            return StatusCode(StatusCodes.Status500InternalServerError, new { Message = "Внутренняя ошибка сервера" });
        }
    }

    /// <summary>
    ///     Регистрация нового пользователя
    /// </summary>
    /// <remarks>
    ///     Эндпоинт для регистрации новых пользователей в системе.
    ///     Поддерживает следующие сценарии:
    ///     - **200 OK**: Успешная регистрация
    ///     - **400 Bad Request**: Некорректные данные или пользователь уже существует
    ///     - **500 Internal Server Error**: Внутренняя ошибка сервера
    ///     Пример запроса:
    ///     ```json
    ///     {
    ///     "Login": "NewUser",
    ///     "Email": "newuser@example.com",
    ///     "Password": "StrongPassword123!",
    ///     "ConfirmPassword": "StrongPassword123!",
    ///     "DisplayName": "New User"
    ///     }
    ///     ```
    /// </remarks>
    /// <param name="request">Данные для регистрации пользователя</param>
    /// <returns>Результат регистрации</returns>
    /// <response code="200">Успешная регистрация пользователя</response>
    /// <response code="400">Некорректные данные или пользователь уже существует</response>
    /// <response code="500">Внутренняя ошибка сервера</response>
    [HttpPost("register")]
    [ProducesResponseType(typeof(RegisterResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(AuthErrorResponseSwagger), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(AuthErrorResponseSwagger), StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            _logger.LogInformation("Получен запрос на регистрацию пользователя: {Login}", request.Login);

            if (!ModelState.IsValid)
            {
                _logger.LogWarning("Получены некорректные данные для регистрации: {Login}", request.Login);
                return BadRequest(new { Message = "Некорректные данные запроса" });
            }

            var result = await _authService.RegisterAsync(request);

            if (result.IsSuccess)
            {
                _logger.LogInformation("Пользователь успешно зарегистрирован: {Login}", request.Login);
                return Ok(result);
            }

            _logger.LogWarning("Ошибка при регистрации пользователя: {Login}, {Error}", request.Login,
                result.ErrorMessage);
            return BadRequest(new { Message = result.ErrorMessage });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Неожиданная ошибка при регистрации пользователя: {Login}", request.Login);
            return StatusCode(StatusCodes.Status500InternalServerError, new { Message = "Внутренняя ошибка сервера" });
        }
    }
}
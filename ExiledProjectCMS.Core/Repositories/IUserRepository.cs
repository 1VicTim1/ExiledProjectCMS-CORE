using ExiledProjectCMS.Core.Entities;

namespace ExiledProjectCMS.Core.Repositories;

/// <summary>
///     Интерфейс репозитория для работы с пользователями
/// </summary>
public interface IUserRepository
{
    /// <summary>
    ///     Получение пользователя по логину для авторизации
    /// </summary>
    /// <param name="login">Логин пользователя</param>
    /// <returns>Пользователь или null если не найден</returns>
    Task<User?> GetByLoginAsync(string login);

    /// <summary>
    ///     Получение пользователя по email
    /// </summary>
    /// <param name="email">Email пользователя</param>
    /// <returns>Пользователь или null если не найден</returns>
    Task<User?> GetByEmailAsync(string email);

    /// <summary>
    ///     Получение пользователя по ID
    /// </summary>
    /// <param name="id">Идентификатор пользователя</param>
    /// <returns>Пользователь или null если не найден</returns>
    Task<User?> GetByIdAsync(int id);

    /// <summary>
    ///     Создание нового пользователя
    /// </summary>
    /// <param name="user">Данные пользователя</param>
    /// <returns>Созданный пользователь</returns>
    Task<User> CreateAsync(User user);

    /// <summary>
    ///     Обновление данных пользователя
    /// </summary>
    /// <param name="user">Обновленные данные пользователя</param>
    /// <returns>Обновленный пользователь</returns>
    Task<User> UpdateAsync(User user);
}
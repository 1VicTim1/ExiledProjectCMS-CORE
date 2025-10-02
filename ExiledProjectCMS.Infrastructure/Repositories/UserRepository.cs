using ExiledProjectCMS.Core.Entities;
using ExiledProjectCMS.Core.Repositories;
using ExiledProjectCMS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ExiledProjectCMS.Infrastructure.Repositories;

/// <summary>
///     Реализация репозитория для работы с пользователями
/// </summary>
public class UserRepository : IUserRepository
{
    private readonly ApplicationDbContext _context;

    public UserRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    /// <summary>
    ///     Получение пользователя по логину для авторизации
    /// </summary>
    /// <param name="login">Логин пользователя</param>
    /// <returns>Пользователь или null если не найден</returns>
    public async Task<User?> GetByLoginAsync(string login)
    {
        return await _context.Users
            .Where(u => u.Login == login)
            .FirstOrDefaultAsync();
    }

    /// <summary>
    ///     Получение пользователя по email
    /// </summary>
    /// <param name="email">Email пользователя</param>
    /// <returns>Пользователь или null если не найден</returns>
    public async Task<User?> GetByEmailAsync(string email)
    {
        return await _context.Users
            .Where(u => u.Email == email)
            .FirstOrDefaultAsync();
    }

    /// <summary>
    ///     Получение пользователя по ID
    /// </summary>
    /// <param name="id">Идентификатор пользователя</param>
    /// <returns>Пользователь или null если не найден</returns>
    public async Task<User?> GetByIdAsync(int id)
    {
        return await _context.Users
            .Where(u => u.Id == id)
            .FirstOrDefaultAsync();
    }

    /// <summary>
    ///     Создание нового пользователя
    /// </summary>
    /// <param name="user">Данные пользователя</param>
    /// <returns>Созданный пользователь</returns>
    public async Task<User> CreateAsync(User user)
    {
        user.CreatedAt = DateTime.UtcNow;
        user.UpdatedAt = DateTime.UtcNow;

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return user;
    }

    /// <summary>
    ///     Обновление данных пользователя
    /// </summary>
    /// <param name="user">Обновленные данные пользователя</param>
    /// <returns>Обновленный пользователь</returns>
    public async Task<User> UpdateAsync(User user)
    {
        user.UpdatedAt = DateTime.UtcNow;

        _context.Users.Update(user);
        await _context.SaveChangesAsync();

        return user;
    }
}
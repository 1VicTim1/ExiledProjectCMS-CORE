using ExiledProjectCMS.Core.Entities;
using ExiledProjectCMS.Core.Repositories;
using ExiledProjectCMS.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace ExiledProjectCMS.Infrastructure.Repositories;

/// <summary>
///     Реализация репозитория для работы с новостями
/// </summary>
public class NewsRepository : INewsRepository
{
    private readonly ApplicationDbContext _context;

    public NewsRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    /// <summary>
    ///     Получение списка новостей с пагинацией
    /// </summary>
    /// <param name="limit">Ограничение количества новостей</param>
    /// <param name="offset">Смещение для пагинации</param>
    /// <returns>Список новостей</returns>
    public async Task<IEnumerable<News>> GetAsync(int? limit = null, int? offset = null)
    {
        IQueryable<News> query = _context.News
            .Where(n => n.IsPublished)
            .OrderByDescending(n => n.CreatedAt);

        // Применяем смещение если указано
        if (offset.HasValue && offset.Value > 0) query = query.Skip(offset.Value);

        // Применяем ограничение если указано
        if (limit.HasValue && limit.Value > 0) query = query.Take(limit.Value);

        return await query.ToListAsync();
    }

    /// <summary>
    ///     Получение новости по ID
    /// </summary>
    /// <param name="id">Идентификатор новости</param>
    /// <returns>Новость или null если не найдена</returns>
    public async Task<News?> GetByIdAsync(int id)
    {
        return await _context.News
            .Where(n => n.Id == id)
            .FirstOrDefaultAsync();
    }

    /// <summary>
    ///     Создание новой новости
    /// </summary>
    /// <param name="news">Данные новости</param>
    /// <returns>Созданная новость</returns>
    public async Task<News> CreateAsync(News news)
    {
        news.CreatedAt = DateTime.UtcNow;
        news.UpdatedAt = DateTime.UtcNow;

        _context.News.Add(news);
        await _context.SaveChangesAsync();

        return news;
    }

    /// <summary>
    ///     Обновление новости
    /// </summary>
    /// <param name="news">Обновленные данные новости</param>
    /// <returns>Обновленная новость</returns>
    public async Task<News> UpdateAsync(News news)
    {
        news.UpdatedAt = DateTime.UtcNow;

        _context.News.Update(news);
        await _context.SaveChangesAsync();

        return news;
    }

    /// <summary>
    ///     Удаление новости
    /// </summary>
    /// <param name="id">Идентификатор новости</param>
    /// <returns>True если удалена успешно</returns>
    public async Task<bool> DeleteAsync(int id)
    {
        var news = await GetByIdAsync(id);
        if (news == null) return false;

        _context.News.Remove(news);
        await _context.SaveChangesAsync();

        return true;
    }
}
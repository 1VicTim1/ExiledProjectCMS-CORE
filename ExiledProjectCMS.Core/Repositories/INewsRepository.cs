using ExiledProjectCMS.Core.Entities;

namespace ExiledProjectCMS.Core.Repositories;

/// <summary>
///     Интерфейс репозитория для работы с новостями
/// </summary>
public interface INewsRepository
{
    /// <summary>
    ///     Получение списка новостей с пагинацией
    /// </summary>
    /// <param name="limit">Ограничение количества новостей</param>
    /// <param name="offset">Смещение для пагинации</param>
    /// <returns>Список новостей</returns>
    Task<IEnumerable<News>> GetAsync(int? limit = null, int? offset = null);

    /// <summary>
    ///     Получение новости по ID
    /// </summary>
    /// <param name="id">Идентификатор новости</param>
    /// <returns>Новость или null если не найдена</returns>
    Task<News?> GetByIdAsync(int id);

    /// <summary>
    ///     Создание новой новости
    /// </summary>
    /// <param name="news">Данные новости</param>
    /// <returns>Созданная новость</returns>
    Task<News> CreateAsync(News news);

    /// <summary>
    ///     Обновление новости
    /// </summary>
    /// <param name="news">Обновленные данные новости</param>
    /// <returns>Обновленная новость</returns>
    Task<News> UpdateAsync(News news);

    /// <summary>
    ///     Удаление новости
    /// </summary>
    /// <param name="id">Идентификатор новости</param>
    /// <returns>True если удалена успешно</returns>
    Task<bool> DeleteAsync(int id);
}
using ExiledProjectCMS.Core.Entities;
using Microsoft.EntityFrameworkCore;

namespace ExiledProjectCMS.Infrastructure.Data;

/// <summary>
///     Контекст базы данных для системы ExiledProjectCMS
/// </summary>
public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
    {
    }

    /// <summary>
    ///     Таблица пользователей
    /// </summary>
    public DbSet<User> Users { get; set; }

    /// <summary>
    ///     Таблица новостей
    /// </summary>
    public DbSet<News> News { get; set; }

    /// <summary>
    ///     Таблица ролей
    /// </summary>
    public DbSet<Role> Roles { get; set; }

    /// <summary>
    ///     Таблица разрешений
    /// </summary>
    public DbSet<Permission> Permissions { get; set; }

    /// <summary>
    ///     Таблица связей пользователь-роль
    /// </summary>
    public DbSet<UserRole> UserRoles { get; set; }

    /// <summary>
    ///     Таблица связей роль-разрешение
    /// </summary>
    public DbSet<RolePermission> RolePermissions { get; set; }

    /// <summary>
    ///     Конфигурация моделей данных
    /// </summary>
    /// <param name="modelBuilder">Построитель модели</param>
    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Конфигурация таблицы пользователей
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Login)
                .IsRequired()
                .HasMaxLength(50)
                .HasColumnName("Login");

            entity.Property(e => e.PasswordHash)
                .IsRequired()
                .HasMaxLength(255)
                .HasColumnName("PasswordHash");

            entity.Property(e => e.UserUuid)
                .IsRequired()
                .HasColumnName("UserUuid");

            entity.Property(e => e.IsBlocked)
                .HasDefaultValue(false)
                .HasColumnName("IsBlocked");

            entity.Property(e => e.BlockReason)
                .HasMaxLength(500)
                .HasColumnName("BlockReason");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("CreatedAt");

            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("UpdatedAt");

            // Создание уникального индекса для логина
            entity.HasIndex(e => e.Login)
                .IsUnique()
                .HasDatabaseName("IX_Users_Login");

            // Создание индекса для UUID
            entity.HasIndex(e => e.UserUuid)
                .IsUnique()
                .HasDatabaseName("IX_Users_UserUuid");
        });

        // Конфигурация таблицы новостей
        modelBuilder.Entity<News>(entity =>
        {
            entity.HasKey(e => e.Id);

            entity.Property(e => e.Title)
                .IsRequired()
                .HasMaxLength(255)
                .HasColumnName("Title");

            entity.Property(e => e.Description)
                .IsRequired()
                .HasColumnType("nvarchar(max)")
                .HasColumnName("Description");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("CreatedAt");

            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("UpdatedAt");

            entity.Property(e => e.IsPublished)
                .HasDefaultValue(true)
                .HasColumnName("IsPublished");

            // Создание индекса для сортировки по дате создания
            entity.HasIndex(e => e.CreatedAt)
                .HasDatabaseName("IX_News_CreatedAt");

            // Создание индекса для фильтрации по статусу публикации
            entity.HasIndex(e => e.IsPublished)
                .HasDatabaseName("IX_News_IsPublished");
        });

        // Обновление конфигурации таблицы пользователей для новых полей
        modelBuilder.Entity<User>(entity =>
        {
            // Добавляем конфигурацию для новых полей
            entity.Property(e => e.Email)
                .IsRequired()
                .HasMaxLength(255)
                .HasColumnName("Email");

            entity.Property(e => e.DisplayName)
                .HasMaxLength(100)
                .HasColumnName("DisplayName");

            entity.Property(e => e.IsEmailConfirmed)
                .HasDefaultValue(false)
                .HasColumnName("IsEmailConfirmed");

            entity.Property(e => e.DiscordId)
                .HasMaxLength(50)
                .HasColumnName("DiscordId");

            entity.Property(e => e.AvatarUrl)
                .HasMaxLength(500)
                .HasColumnName("AvatarUrl");

            entity.Property(e => e.LastLoginAt)
                .HasColumnName("LastLoginAt");

            entity.Property(e => e.LastLoginIp)
                .HasMaxLength(45)
                .HasColumnName("LastLoginIp");

            // Создание индекса для email
            entity.HasIndex(e => e.Email)
                .IsUnique()
                .HasDatabaseName("IX_Users_Email");

            // Создание индекса для Discord ID
            entity.HasIndex(e => e.DiscordId)
                .IsUnique()
                .HasDatabaseName("IX_Users_DiscordId");
        });

        // Конфигурация таблицы ролей
        modelBuilder.Entity<Role>(entity =>
        {
            entity.HasKey(e => e.Id);

            entity.Property(e => e.Name)
                .IsRequired()
                .HasMaxLength(50)
                .HasColumnName("Name");

            entity.Property(e => e.DisplayName)
                .IsRequired()
                .HasMaxLength(100)
                .HasColumnName("DisplayName");

            entity.Property(e => e.Description)
                .HasMaxLength(500)
                .HasColumnName("Description");

            entity.Property(e => e.Color)
                .HasMaxLength(7)
                .HasColumnName("Color");

            entity.Property(e => e.Priority)
                .HasDefaultValue(0)
                .HasColumnName("Priority");

            entity.Property(e => e.IsSystem)
                .HasDefaultValue(false)
                .HasColumnName("IsSystem");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("CreatedAt");

            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("UpdatedAt");

            // Уникальный индекс для имени роли
            entity.HasIndex(e => e.Name)
                .IsUnique()
                .HasDatabaseName("IX_Roles_Name");
        });

        // Конфигурация таблицы разрешений
        modelBuilder.Entity<Permission>(entity =>
        {
            entity.HasKey(e => e.Id);

            entity.Property(e => e.Name)
                .IsRequired()
                .HasMaxLength(100)
                .HasColumnName("Name");

            entity.Property(e => e.DisplayName)
                .IsRequired()
                .HasMaxLength(100)
                .HasColumnName("DisplayName");

            entity.Property(e => e.Description)
                .HasMaxLength(500)
                .HasColumnName("Description");

            entity.Property(e => e.Category)
                .IsRequired()
                .HasMaxLength(50)
                .HasColumnName("Category");

            entity.Property(e => e.IsSystem)
                .HasDefaultValue(false)
                .HasColumnName("IsSystem");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("CreatedAt");

            // Уникальный индекс для имени разрешения
            entity.HasIndex(e => e.Name)
                .IsUnique()
                .HasDatabaseName("IX_Permissions_Name");

            // Индекс для категории
            entity.HasIndex(e => e.Category)
                .HasDatabaseName("IX_Permissions_Category");
        });

        // Конфигурация таблицы связей пользователь-роль
        modelBuilder.Entity<UserRole>(entity =>
        {
            // Составной первичный ключ
            entity.HasKey(ur => new { ur.UserId, ur.RoleId });

            entity.Property(ur => ur.AssignedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("AssignedAt");

            entity.Property(ur => ur.AssignedByUserId)
                .HasColumnName("AssignedByUserId");

            // Внешние ключи
            entity.HasOne(ur => ur.User)
                .WithMany(u => u.UserRoles)
                .HasForeignKey(ur => ur.UserId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(ur => ur.Role)
                .WithMany(r => r.UserRoles)
                .HasForeignKey(ur => ur.RoleId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(ur => ur.AssignedByUser)
                .WithMany()
                .HasForeignKey(ur => ur.AssignedByUserId)
                .OnDelete(DeleteBehavior.NoAction);
        });

        // Конфигурация таблицы связей роль-разрешение
        modelBuilder.Entity<RolePermission>(entity =>
        {
            // Составной первичный ключ
            entity.HasKey(rp => new { rp.RoleId, rp.PermissionId });

            entity.Property(rp => rp.AssignedAt)
                .HasDefaultValueSql("GETUTCDATE()")
                .HasColumnName("AssignedAt");

            // Внешние ключи
            entity.HasOne(rp => rp.Role)
                .WithMany(r => r.RolePermissions)
                .HasForeignKey(rp => rp.RoleId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(rp => rp.Permission)
                .WithMany(p => p.RolePermissions)
                .HasForeignKey(rp => rp.PermissionId)
                .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
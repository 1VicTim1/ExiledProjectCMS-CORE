using System.Collections.Generic;

namespace MainApi.Models
{
    public class Role
    {
        public int Id { get; set; }
        public string Name { get; set; } // Отображаемое имя
        public string Code { get; set; } // Кодовое имя (только латиница, без спецсимволов)
        public string Color { get; set; } // HEX-цвет
        public string LogoUrl { get; set; } // URL лого
        public int? ParentRoleId { get; set; } // Родительская роль
        public Role ParentRole { get; set; }
        public ICollection<RolePermission> RolePermissions { get; set; }
        public ICollection<UserRole> UserRoles { get; set; }
    }

    public class Permission
    {
        public int Id { get; set; }
        public string Name { get; set; } // Название разрешения
        public string Code { get; set; } // Кодовое имя разрешения
        public string Description { get; set; }
        public ICollection<RolePermission> RolePermissions { get; set; }
        public ICollection<UserPermission> UserPermissions { get; set; }
    }

    public class RolePermission
    {
        public int RoleId { get; set; }
        public Role Role { get; set; }
        public int PermissionId { get; set; }
        public Permission Permission { get; set; }
    }

    public class UserRole
    {
        public int UserId { get; set; }
        public int RoleId { get; set; }
        public Role Role { get; set; }
    }

    public class UserPermission
    {
        public int UserId { get; set; }
        public int PermissionId { get; set; }
        public Permission Permission { get; set; }
    }

    public class Ticket
    {
        public int Id { get; set; }
        public string Title { get; set; }
        public string Description { get; set; }
        public string Status { get; set; } // open, closed, etc.
        public int CreatedBy { get; set; }
        public int? AssignedTo { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? ClosedAt { get; set; }
    }

    public class PageAccess
    {
        public int Id { get; set; }
        public string Path { get; set; } // /admin, /tickets, /roles и т.д.
        public int PermissionId { get; set; }
        public Permission Permission { get; set; }
    }

    public class ApiToken
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string Token { get; set; } // Хэш токена
        public string Name { get; set; } // Название токена (для удобства)
        public DateTime CreatedAt { get; set; }
        public DateTime? ExpiresAt { get; set; }
        public List<TokenPermission> Permissions { get; set; } = new();
    }

    public class AuditLog
    {
        public int Id { get; set; }
        public int? UserId { get; set; }
        public int? ApiTokenId { get; set; }
        public string TokenName { get; set; } // Копия имени токена на момент действия
        public string Action { get; set; } // Описание действия (например, "create_ticket", "delete_role", "api_call:/api/news")
        public string Details { get; set; } // Доп. информация (например, параметры запроса)
        public DateTime Timestamp { get; set; }
        public string IpAddress { get; set; }
    }
}

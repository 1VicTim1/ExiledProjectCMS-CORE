using System;

namespace MainApi.Models
{
    public class AuditLog
    {
        public int Id { get; set; }
        public int? UserId { get; set; }
        public int? ApiTokenId { get; set; }
        public string Action { get; set; } = null!;
        public string? Details { get; set; }
        public string? Ip { get; set; }
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}


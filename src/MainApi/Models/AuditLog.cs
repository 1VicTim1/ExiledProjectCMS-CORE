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
        public string? TokenName { get; set; }
        public string? IpAddress { get; set; }
        public DateTime Timestamp { get; set; } = DateTime.UtcNow;

        // Backwards-compat aliases for existing code
        public string? Ip { get => IpAddress; set => IpAddress = value; }
        public DateTime CreatedAt { get => Timestamp; set => Timestamp = value; }
    }
}


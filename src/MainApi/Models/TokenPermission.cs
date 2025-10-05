using System.ComponentModel.DataAnnotations.Schema;

namespace MainApi.Models
{
    public class TokenPermission
    {
        public int TokenId { get; set; }
        public ApiToken Token { get; set; } = null!;
        public int PermissionId { get; set; }
        public Permission Permission { get; set; } = null!;
    }
}


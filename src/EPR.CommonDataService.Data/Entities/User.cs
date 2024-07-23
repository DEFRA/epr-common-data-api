using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Diagnostics.CodeAnalysis;
using Microsoft.EntityFrameworkCore;

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
[Table("users", Schema = "rpd")]
public class User
{
    public int Id { get; set; }

    [Required]
    public string UserId { get; set; }

    [MaxLength(200)]
    [Comment("External Provider Identity ID")]
    public string? ExternalIdpId { get; set; }

    [MaxLength(200)]
    [Comment("External Provider Identity User ID")]
    public string? ExternalIdpUserId { get; set; }

    [MaxLength(254)]
    public string? Email { get; set; }

    public Person Person { get; set; } = null!;

    public bool IsDeleted { get; set; }

    [MaxLength(100)]
    public string? InviteToken { get; set; }

    [MaxLength(254)]
    public string? InvitedBy { get; set; }
}

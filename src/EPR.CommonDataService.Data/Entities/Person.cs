using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Diagnostics.CodeAnalysis;
// ReSharper disable UnusedAutoPropertyAccessor.Local

namespace EPR.CommonDataService.Data.Entities;

[ExcludeFromCodeCoverage]
[Table("persons", Schema = "rpd")]
public class Person
{
    public int Id { get; set; }

    [MaxLength(50)]
    public string FirstName { get; set; }

    [MaxLength(50)]
    public string LastName { get; set; }

    [MaxLength(100)]
    public string Email { get; set; }

    [MaxLength(50)]
    public string Telephone { get; set; }

    public int? UserId { get; set; }

    public bool IsDeleted { get; set; }

    public string ExternalId { get; set; }

#pragma warning disable S1144
    public string CreatedOn { get; private set; }

    public string LastUpdatedOn { get; private set; }
#pragma warning restore S1144
}

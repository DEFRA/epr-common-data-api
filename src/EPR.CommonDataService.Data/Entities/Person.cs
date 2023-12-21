using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace EPR.CommonDataService.Data.Entities;

[Table("persons",Schema = "rpd")]
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

    public string CreatedOn { get; private set; }

    public string LastUpdatedOn { get; private set; }
}

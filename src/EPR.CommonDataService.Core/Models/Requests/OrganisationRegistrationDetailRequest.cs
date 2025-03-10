﻿using System.ComponentModel.DataAnnotations;
using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Requests
{
    [ExcludeFromCodeCoverage]
    public class OrganisationRegistrationDetailRequest
    {
        [Required]
        public Guid SubmissionId { get; set; }
    }
}

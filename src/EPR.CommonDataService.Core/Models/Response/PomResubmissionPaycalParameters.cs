using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EPR.CommonDataService.Core.Models.Response
{
    public class PomResubmissionPaycalParametersDto
    {
        public bool? IsResubmission { get; set; }
        public DateTime? ResubmissionDate { get; set; }
        public int? MemberCount { get; set; }
        public string? Reference { get; set; }
        public bool ReferenceFieldAvailable { get; set; }
    }
}

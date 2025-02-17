using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EPR.CommonDataService.Core.Models.Response
{
    public class PomResubmissionPaycalParametersDto
    {
        public int? MemberCount { get; set; }
        public string? Reference { get; set; }
    }

    public class PomResubmissionPaycalParameters : PomResubmissionPaycalParametersDto
    {
        public bool ReferenceAvailable { get; set; }
    }
}

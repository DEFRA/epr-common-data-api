using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EPR.CommonDataService.Data.Entities
{
    public class PomSubmissionSummaryRowWithFileFields : PomSubmissionSummaryWithFileFields
    {
        public int TotalItems { get; set; }
    }
}

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EPR.CommonDataService.Data.Entities
{
    public class PomSubmissionSummaryWithFileFields : SubmissionSummaryModel
    {
        public Guid? FileId { get; set; }
        public bool IsResubmissionRequired { get; set; }
        public string SubmittedDate { get; set; }
        public int SubmissionYear { get; set; }
        public string SubmissionCode { get; set; }
        public string ActualSubmissionPeriod { get; set; }
    }
}

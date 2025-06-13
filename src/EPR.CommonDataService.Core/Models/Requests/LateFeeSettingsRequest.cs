using System.Diagnostics.CodeAnalysis;

namespace EPR.CommonDataService.Core.Models.Requests;

[ExcludeFromCodeCoverage]
public class LateFeeSettingsRequest
{
    public int LateFeeCutOffMonth_2025 { get; set; }

    public int LateFeeCutOffDay_2025 { get; set; }

    public int LateFeeCutOffMonth_CS { get; set; }

    public int LateFeeCutOffDay_CS { get; set; }

    public int LateFeeCutOffMonth_SP { get; set; }

    public int LateFeeCutOffDay_SP { get; set; }

    public int LateFeeCutOffMonth_LP { get; set; }

    public int LateFeeCutOffDay_LP { get; set; }
}
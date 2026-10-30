using System.Globalization;
using EPR.CommonDataService.Data.Entities;

namespace EPR.CommonDataService.Api.Features.PayCal.Fss.v1.BillingOrganisations.Get;

public static class BillingOrganisationsBuilder
{
    /// <summary>
    ///     Groups the flat rows from <c>GetLatestAcceptedGrantedOrgData</c> into one entry per organisation,
    ///     ordered by organisation id, with its subsidiaries nested beneath it.
    /// </summary>
    /// <remarks>
    ///     <list type="bullet">
    ///         <item>Rows are grouped by organisation id only, not by relative year.</item>
    ///         <item>
    ///             The parent is the non-subsidiary row with the latest decision date, so an organisation approved
    ///             in more than one year is only returned for its most recent one unless the request filters by year.
    ///         </item>
    ///         <item>Subsidiaries are the subsidiary rows with the same relative year as the chosen parent.</item>
    ///         <item>Organisations with no parent row are skipped and logged.</item>
    ///     </list>
    ///     Grouping by organisation and relative year would return every year, but changes the contract with FSS
    ///     so needs agreeing with them first.
    /// </remarks>
    public static IReadOnlyCollection<BillingOrganisationResponse> Build(
        IEnumerable<PayCalLatestAcceptedGrantedOrg> rows,
        ILogger logger)
    {
        var organisationGroups = rows
            .Where(row => row.OrganisationId is not null)
            .GroupBy(row => row.OrganisationId!.Value)
            .OrderBy(group => group.Key);

        var organisations = new List<BillingOrganisationResponse>();

        foreach (var organisationRows in organisationGroups)
        {
            var parent = organisationRows
                .Where(row => !IsSubsidiary(row))
                .MaxBy(ParseDecisionDate);

            if (parent is null)
            {
                logger.LogWarning("Parent organisation not found for OrganisationId={OrganisationId}. Skipping.", organisationRows.Key);
                continue;
            }

            var subsidiaries = organisationRows
                .Where(row => IsSubsidiary(row) && row.RelativeYear == parent.RelativeYear)
                .Select(row => new BillingSubsidiaryResponse
                {
                    SubsidiaryId = row.SubsidiaryId!,
                    SubsidiaryName = row.OrganisationName,
                    SubsidiaryTradingName = row.TradingName,
                    FinancialYear = FinancialYear.FromRelativeYear(row.RelativeYear),
                    ApprovedDate = ParseDecisionDate(row)
                })
                .ToList();

            organisations.Add(new BillingOrganisationResponse
            {
                OrganisationId = organisationRows.Key.ToString(CultureInfo.InvariantCulture),
                FinancialYear = FinancialYear.FromRelativeYear(parent.RelativeYear),
                ApprovedDate = ParseDecisionDate(parent),
                OrganisationName = parent.OrganisationName,
                OrganisationTradingName = parent.TradingName,
                CompaniesHouseNumber = parent.CompaniesHouseNumber,
                HomeNationCode = parent.HomeNationCode,
                ServiceOfNoticeAddrLine1 = parent.ServiceOfNoticeAddrLine1,
                ServiceOfNoticeAddrLine2 = parent.ServiceOfNoticeAddrLine2,
                ServiceOfNoticeAddrCity = parent.ServiceOfNoticeAddrCity,
                ServiceOfNoticeAddrCounty = parent.ServiceOfNoticeAddrCounty,
                ServiceOfNoticeAddrCountry = parent.ServiceOfNoticeAddrCountry,
                ServiceOfNoticeAddrPostcode = parent.ServiceOfNoticeAddrPostcode,
                ServiceOfNoticeAddrPhoneNumber = parent.ServiceOfNoticeAddrPhoneNumber,
                SoleTraderFirstName = parent.SoleTraderFirstName,
                SoleTraderLastName = parent.SoleTraderLastName,
                SoleTraderPhoneNumber = parent.SoleTraderPhoneNumber,
                SoleTraderEmail = parent.SoleTraderEmail,
                PrimaryContactPersonFirstName = parent.PrimaryContactPersonFirstName,
                PrimaryContactPersonLastName = parent.PrimaryContactPersonLastName,
                PrimaryContactPersonPhoneNumber = parent.PrimaryContactPersonPhoneNumber,
                PrimaryContactPersonEmail = parent.PrimaryContactPersonEmail,
                SubsidiaryDetails = subsidiaries
            });
        }

        return organisations.AsReadOnly();
    }

    private static bool IsSubsidiary(PayCalLatestAcceptedGrantedOrg row) =>
        !string.IsNullOrWhiteSpace(row.SubsidiaryId);

    private static DateTime ParseDecisionDate(PayCalLatestAcceptedGrantedOrg row) =>
        DateTime.Parse(row.DecisionDate, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
}

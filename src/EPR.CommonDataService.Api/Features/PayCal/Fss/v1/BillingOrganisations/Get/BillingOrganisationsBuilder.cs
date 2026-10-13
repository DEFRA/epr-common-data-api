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
        var organisationsLookup = rows
            .Where(row => row.OrganisationId is not null)
            .Select(row => new
            {
                Data = row,
                SubsidiaryId = string.IsNullOrWhiteSpace(row.SubsidiaryId) ? null : row.SubsidiaryId
            })
            .ToLookup(x => x.Data.OrganisationId!.Value);

        var organisations = new List<BillingOrganisationResponse>();

        foreach (var organisationRecords in organisationsLookup.OrderBy(g => g.Key))
        {
            var parent = organisationRecords
                .Where(x => x.SubsidiaryId is null)
                .MaxBy(x => ParseDecisionDate(x.Data));

            if (parent is null)
            {
                logger.LogWarning("Parent organisation not found for OrganisationId={OrganisationId}. Skipping.", organisationRecords.Key);
                continue;
            }

            var subsidiaries = organisationRecords
                .Where(x => x.SubsidiaryId is not null && x.Data.RelativeYear == parent.Data.RelativeYear)
                .Select(x => new BillingSubsidiaryResponse
                {
                    SubsidiaryId = x.SubsidiaryId!,
                    SubsidiaryName = x.Data.OrganisationName,
                    SubsidiaryTradingName = x.Data.TradingName,
                    FinancialYear = FinancialYear.FromRelativeYear(x.Data.RelativeYear),
                    ApprovedDate = ParseDecisionDate(x.Data)
                })
                .ToList();

            organisations.Add(new BillingOrganisationResponse
            {
                OrganisationId = organisationRecords.Key.ToString(CultureInfo.InvariantCulture),
                FinancialYear = FinancialYear.FromRelativeYear(parent.Data.RelativeYear),
                ApprovedDate = ParseDecisionDate(parent.Data),
                OrganisationName = parent.Data.OrganisationName,
                OrganisationTradingName = parent.Data.TradingName,
                CompaniesHouseNumber = parent.Data.CompaniesHouseNumber,
                HomeNationCode = parent.Data.HomeNationCode,
                ServiceOfNoticeAddrLine1 = parent.Data.ServiceOfNoticeAddrLine1,
                ServiceOfNoticeAddrLine2 = parent.Data.ServiceOfNoticeAddrLine2,
                ServiceOfNoticeAddrCity = parent.Data.ServiceOfNoticeAddrCity,
                ServiceOfNoticeAddrCounty = parent.Data.ServiceOfNoticeAddrCounty,
                ServiceOfNoticeAddrCountry = parent.Data.ServiceOfNoticeAddrCountry,
                ServiceOfNoticeAddrPostcode = parent.Data.ServiceOfNoticeAddrPostcode,
                ServiceOfNoticeAddrPhoneNumber = parent.Data.ServiceOfNoticeAddrPhoneNumber,
                SoleTraderFirstName = parent.Data.SoleTraderFirstName,
                SoleTraderLastName = parent.Data.SoleTraderLastName,
                SoleTraderPhoneNumber = parent.Data.SoleTraderPhoneNumber,
                SoleTraderEmail = parent.Data.SoleTraderEmail,
                PrimaryContactPersonFirstName = parent.Data.PrimaryContactPersonFirstName,
                PrimaryContactPersonLastName = parent.Data.PrimaryContactPersonLastName,
                PrimaryContactPersonPhoneNumber = parent.Data.PrimaryContactPersonPhoneNumber,
                PrimaryContactPersonEmail = parent.Data.PrimaryContactPersonEmail,
                SubsidiaryDetails = subsidiaries
            });
        }

        return organisations.AsReadOnly();
    }

    private static DateTime ParseDecisionDate(PayCalLatestAcceptedGrantedOrg row) =>
        DateTime.Parse(row.DecisionDate, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind);
}

-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_FilterAndPaginateRegistrationsSummaries]'))
DROP PROCEDURE [apps].[sp_FilterAndPaginateRegistrationsSummaries];
GO

CREATE PROCEDURE apps.sp_FilterAndPaginateRegistrationsSummaries
    @OrganisationName NVARCHAR(255),
    @OrganisationReference NVARCHAR(255),
    @RegulatorUserId NVARCHAR(50),
    @StatusesCommaSeperated NVARCHAR(50),
	@OrganisationType NVARCHAR(50),
    @PageSize INT,
    @PageNumber INT,
    @DecisionsDelta NVARCHAR(MAX)
AS
BEGIN
	
-- get regulator user nation id
DECLARE @NationId INT;

SELECT @NationId = o.NationId
FROM rpd.Users u
         INNER JOIN rpd.Persons p ON p.UserId = u.Id
         INNER JOIN rpd.PersonOrganisationConnections poc ON poc.PersonId = p.Id
         INNER JOIN rpd.Organisations o ON o.Id = poc.OrganisationId
         INNER JOIN rpd.Enrolments e ON e.ConnectionId = poc.Id
         INNER JOIN rpd.ServiceRoles sr ON sr.Id = e.ServiceRoleId
WHERE
        sr.ServiceId=2 AND -- only regulator service users
        u.UserId=@RegulatorUserId  -- with provided ID

-- Initial Filter CTE
;WITH InitialFilter AS (
    SELECT *
    FROM apps.RegistrationsSummaries
    WHERE
        (
                (NULLIF(@OrganisationName, '') IS NOT NULL AND OrganisationName LIKE '%' + @OrganisationName + '%')
                OR
                (NULLIF(@OrganisationReference, '') IS NOT NULL AND OrganisationReference LIKE '%' + @OrganisationReference + '%')
                OR
                (NULLIF(@OrganisationName, '') IS NULL AND NULLIF(@OrganisationReference, '') IS NULL)
            )
      AND (NationId = @NationId)
      AND
        (
                (@OrganisationType = 'All' OR @OrganisationType = '')
                OR
                (@OrganisationType = 'ComplianceScheme' AND ComplianceSchemeId IS NOT NULL)
                OR
                (@OrganisationType = 'DirectProducer' AND ComplianceSchemeId IS NULL)
            )
)

    ,RankedJsonParsedUpdates AS (
        SELECT
            JSON_VALUE([value], '$.FileId,') AS CompanyDetailsFileId,
            JSON_VALUE([value], '$.Decision') AS Decision,
            JSON_VALUE([value], '$.Comments') AS Comments,
            ROW_NUMBER() OVER (PARTITION BY JSON_VALUE([value], '$.FileId') ORDER BY (SELECT NULL)) AS rn
        FROM OPENJSON(@DecisionsDelta)
    )

    ,JsonParsedUpdates AS (
        SELECT
            CompanyDetailsFileId,
            Decision,
            Comments
        FROM RankedJsonParsedUpdates
        WHERE rn = 1
    )

    ,OverriddenStatuses AS (
        SELECT
            f.*,
            COALESCE(j.Decision, f.Decision) AS UpdatedDecision,
            COALESCE(j.Comments, f.Comments) AS UpdatedComments
        FROM InitialFilter f
                 LEFT JOIN JsonParsedUpdates j ON j.CompanyDetailsFileId = f.CompanyDetailsFileId
    )

    ,StatusFilteredResults AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                ORDER BY
                    CASE
                        WHEN UpdatedDecision = 'Pending' THEN 1
                        WHEN UpdatedDecision = 'Rejected' THEN 2
                        WHEN UpdatedDecision = 'Accepted' THEN 3
                        ELSE 4
                    END,
                    RegistrationDate
            ) AS RowNum
        FROM OverriddenStatuses
        WHERE
            (ISNULL(@StatusesCommaSeperated, '') = '' OR UpdatedDecision IN (SELECT value FROM STRING_SPLIT(@StatusesCommaSeperated, ',')))
    )

 -- Fetch the paginated results
 SELECT
     [SubmissionId],
     [OrganisationId],
     [ComplianceSchemeId],
     [OrganisationName],
     [OrganisationReference],
     [CompaniesHouseNumber],
     [SubBuildingName],
     [BuildingName],
     [BuildingNumber],
     [Street],
     [Locality],
     [DependentLocality],
     [Town],
     [County],
     [Country],
     [Postcode],
     [OrganisationType],
     [ProducerType],
     [UserId],
     [FirstName],
     [LastName],
     [Email],
     [Telephone],
     [ServiceRole],
     [CompanyDetailsFileId],
     [CompanyDetailsFileName],
     [PartnershipFileId],
     [PartnershipFileName],
     [BrandsFileId],
     [BrandsFileName],
     [SubmissionPeriod],
     [RegistrationDate],
     [UpdatedDecision] AS Decision,
     [UpdatedComments] AS Comments,
     [IsResubmission],
     [PreviousRejectionComments],
     [NationId],
     (SELECT COUNT(*) FROM StatusFilteredResults) AS TotalItems
 FROM StatusFilteredResults
 WHERE RowNum > (@PageSize * (@PageNumber - 1))
   AND RowNum <= @PageSize * @PageNumber
 ORDER BY RowNum;

END;
IF EXISTS (
    SELECT 1
    FROM sys.procedures
    WHERE object_id = OBJECT_ID(
            N'[dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries]'
        )
) DROP PROCEDURE [dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries];

GO

CREATE PROC [dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries] @OrganisationNameCommaSeparated [nvarchar](255),
    @OrganisationReferenceCommaSeparated [nvarchar](255),
    @SubmissionYearsCommaSeparated [nvarchar](255),
    @StatusesCommaSeparated [nvarchar](100),
    @OrganisationTypeCommaSeparated [nvarchar](255),
    @NationId int,
    @AppRefNumbersCommaSeparated [nvarchar](2000),
    @PageSize [INT],
    @PageNumber [INT] AS BEGIN
SET NOCOUNT ON;
WITH NormalFilterCTE AS (
    SELECT *
    FROM dbo.[v_OrganisationRegistrationSummaries_New] i
    WHERE (
            NationId = @NationId
            OR @NationId = 0
        )
        AND (
            EXISTS (
                SELECT 1
                FROM STRING_SPLIT(@AppRefNumbersCommaSeparated, ',') AS AppReference
                WHERE ApplicationReferenceNumber = LTRIM(RTRIM(AppReference.value))
            )
            OR (
                (
                    (
                        (
                            LEN(ISNULL(@OrganisationNameCommaSeparated, '')) > 0
                            AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) > 0
                            AND EXISTS (
                                SELECT 1
                                FROM STRING_SPLIT(@OrganisationNameCommaSeparated, ',') AS Names
                                WHERE OrganisationName LIKE '%' + LTRIM(RTRIM(Names.value)) + '%'
                            )
                            AND EXISTS (
                                SELECT 1
                                FROM STRING_SPLIT(@OrganisationReferenceCommaSeparated, ',') AS Reference
                                WHERE OrganisationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                                    OR ApplicationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                                    OR RegistrationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                            )
                        ) -- Only OrganisationName specified
                        OR (
                            LEN(ISNULL(@OrganisationNameCommaSeparated, '')) > 0
                            AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) = 0
                            AND EXISTS (
                                SELECT 1
                                FROM STRING_SPLIT(@OrganisationNameCommaSeparated, ',') AS Names
                                WHERE OrganisationName LIKE '%' + LTRIM(RTRIM(Names.value)) + '%'
                            )
                        ) -- Only OrganisationReference specified
                        OR (
                            LEN(ISNULL(@OrganisationNameCommaSeparated, '')) = 0
                            AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) > 0
                            AND EXISTS (
                                SELECT 1
                                FROM STRING_SPLIT(@OrganisationReferenceCommaSeparated, ',') AS Reference
                                WHERE OrganisationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                                    OR ApplicationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                                    OR RegistrationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                            )
                        )
                        OR (
                            LEN(ISNULL(@OrganisationNameCommaSeparated, '')) = 0
                            AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) = 0
                        )
                    )
                )
                AND (
                    ISNULL(@OrganisationTypeCommaSeparated, '') = ''
                    OR OrganisationType IN (
                        SELECT TRIM(value)
                        FROM STRING_SPLIT(@OrganisationTypeCommaSeparated, ',')
                    )
                )
                AND (
                    ISNULL(@SubmissionYearsCommaSeparated, '') = ''
                    OR RelevantYear IN (
                        SELECT TRIM(value)
                        FROM STRING_SPLIT(
                                CONCAT('2024,2025,', @SubmissionYearsCommaSeparated),
                                ','
                            )
                    )
                )
                AND (
                    ISNULL(@StatusesCommaSeparated, '') = ''
                    OR SubmissionStatus IN (
                        SELECT TRIM(value)
                        FROM STRING_SPLIT(@StatusesCommaSeparated, ',')
                    )
                )
            )
        )
),
SortedCTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            ORDER BY CASE
                    WHEN SubmissionStatus = 'Cancelled' THEN 6
                    WHEN SubmissionStatus = 'Refused' THEN 5
                    WHEN SubmissionStatus = 'Granted' THEN 4
                    WHEN SubmissionStatus = 'Queried' THEN 3
                    WHEN SubmissionStatus = 'Pending' THEN 2
                    WHEN SubmissionStatus = 'Updated' THEN 1
                END,
                SubmittedDateTime
        ) AS RowNum
    FROM NormalFilterCTE
),
TotalRowsCTE AS (
    SELECT COUNT(*) AS TotalRows
    FROM SortedCTE
),
PagedResultsCTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            ORDER BY RowNum
        ) AS PagedRowNum
    FROM SortedCTE
)
SELECT SubmissionId,
    OrganisationId,
    OrganisationInternalId,
    OrganisationType,
    OrganisationName,
    OrganisationReferenceNumber AS OrganisationReference,
    SubmissionStatus,
    StatusPendingDate,
    ApplicationReferenceNumber,
    RegistrationReferenceNumber,
    RelevantYear,
    SubmittedDateTime,
    RegulatorDecisionDate AS RegulatorCommentDate,
    ProducerCommentDate,
    RegulatorUserId,
    NationId,
    NationCode,
(
        SELECT COUNT(*)
        FROM SortedCTE
    ) AS TotalItems
FROM PagedResultsCTE
WHERE PagedRowNum > (
        @PageSize * (
            LEAST(
                @PageNumber,
                CEILING(
                    (
                        SELECT TotalRows
                        FROM TotalRowsCTE
                    ) / (1.0 * @PageSize)
                )
            ) - 1
        )
    )
    AND PagedRowNum <= @PageSize * LEAST(
        @PageNumber,
        CEILING(
            (
                SELECT TotalRows
                FROM TotalRowsCTE
            ) / (1.0 * @PageSize)
        )
    )
ORDER BY RowNum;
END;

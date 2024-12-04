-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[rpd].[sp_FilterAndPaginateOrganisationRegistrationSummaries]'))
DROP PROCEDURE [rpd].[sp_FilterAndPaginateOrganisationRegistrationSummaries];
GO
create proc [rpd].[sp_FilterAndPaginateOrganisationRegistrationSummaries] 
    @OrganisationNameCommaSeparated[nvarchar](255),
    @OrganisationReferenceCommaSeparated [nvarchar](255),
    @SubmissionYearsCommaSeparated [nvarchar](255),
    @StatusesCommaSeparated [nvarchar](100),
    @OrganisationTypeCommaSeparated [nvarchar](255),
    @NationId int,
	@AppRefNumbersCommaSeparated [nvarchar](2000),
    @PageSize [INT],
    @PageNumber [INT]
AS
begin
	SET NOCOUNT ON;

    with 
	RequiredApplicationsByStatusCTE as  (
    	SELECT * 
        FROM dbo.[v_OrganisationRegistrationSummaries]
		WHERE 
        ( 
			1 = 1
			AND NationId = @NationId 
		)
		AND EXISTS (
			SELECT 1
			FROM STRING_SPLIT(@AppRefNumbersCommaSeparated, ',') AS AppReference
			WHERE ApplicationReferenceNumber = LTRIM(RTRIM(AppReference.value))
		)
	)
	,InitialFilterCTE as (
    	SELECT * 
        FROM dbo.[v_OrganisationRegistrationSummaries]
		WHERE 
        ( 
			1 = 1
			AND NationId = @NationId 
		)
	)
	,NormalFilterCTE as (
		SELECT * from InitialFilterCTE i
		WHERE NationId = @NationId
		AND
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
				)
				-- Only OrganisationName specified
				OR (
					LEN(ISNULL(@OrganisationNameCommaSeparated, '')) > 0
					AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) = 0
					AND EXISTS (
						SELECT 1
						FROM STRING_SPLIT(@OrganisationNameCommaSeparated, ',') AS Names
						WHERE OrganisationName LIKE '%' + LTRIM(RTRIM(Names.value)) + '%'
					)
				)
				-- Only OrganisationReference specified
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
        AND (ISNULL(@OrganisationTypeCommaSeparated, '') = '' OR OrganisationType IN
            (SELECT TRIM(value) FROM STRING_SPLIT(@OrganisationTypeCommaSeparated, ','))
        )
        AND (ISNULL(@SubmissionYearsCommaSeparated, '') = '' OR RelevantYear IN 
            (SELECT TRIM(value) FROM STRING_SPLIT(CONCAT('2025,', @SubmissionYearsCommaSeparated), ','))
        )
        AND (ISNULL(@StatusesCommaSeparated, '') = '' OR SubmissionStatus IN 
			(SELECT TRIM(value) FROM STRING_SPLIT(@StatusesCommaSeparated, ','))
        )
    )
	,CombinedCTE as (
		select * from NormalFilterCTE
		UNION
		select * from RequiredApplicationsByStatusCTE
	)
    ,SortedCTE as (
        select *,
        ROW_NUMBER() OVER (
            ORDER BY
                CASE 
                    when SubmissionStatus = 'Cancelled' THEN 6
                    when SubmissionStatus = 'Refused' THEN 5
                    when SubmissionStatus = 'Granted' THEN 4
                    when SubmissionStatus = 'Queried' THEN 3
                    when SubmissionStatus = 'Pending' THEN 2
                    when SubmissionStatus = 'Updated' THEN 1
                END,
                SubmittedDateTime
        ) as RowNum
        from CombinedCTE
    )
SELECT
    SubmissionId,
    OrganisationId,
	OrganisationInternalId,
    OrganisationType,
    OrganisationName,
    OrganisationReferenceNumber as OrganisationReference,
    SubmissionStatus,
    StatusPendingDate,
    ApplicationReferenceNumber,
    RegistrationReferenceNumber,
    RelevantYear,
    SubmittedDateTime,
	RegulatorDecisionDate as RegulatorCommentDate,
	ProducerCommentDate,
	RegulatorUserId,
    NationId,
	NationCode,
    (SELECT COUNT(*) FROM SortedCTE) AS TotalItems
FROM SortedCTE
WHERE RowNum > (@PageSize * (@PageNumber - 1))
   AND RowNum <= @PageSize * @PageNumber
ORDER BY RowNum;

END;

GO

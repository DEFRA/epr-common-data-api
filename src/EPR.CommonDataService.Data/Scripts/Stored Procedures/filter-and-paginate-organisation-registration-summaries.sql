IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries]'))
DROP PROCEDURE [dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries];
GO
CREATE PROC [dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries] @OrganisationNameCommaSeparated [nvarchar](255),@OrganisationReferenceCommaSeparated [nvarchar](255),@SubmissionYearsCommaSeparated [nvarchar](255),@StatusesCommaSeparated [nvarchar](100),@OrganisationTypeCommaSeparated [nvarchar](255),@NationId [int],@AppRefNumbersCommaSeparated [nvarchar](2000),@PageSize [INT],@PageNumber [INT] AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
		SELECT 1
		FROM sys.columns
		WHERE [name] = 'AppReferenceNumber' AND [object_id] = OBJECT_ID('rpd.Submissions')
	)
	BEGIN
		IF OBJECT_ID('tempdb..#TempTable') IS NOT NULL
			DROP TABLE #TempTable;

		CREATE TABLE #TempTable (
			SubmissionId NVARCHAR(150) NULL,
			OrganisationId NVARCHAR(150) NULL,
			OrganisationInternalId INT NULL,
			OrganisationName NVARCHAR(500) NULL,
			UploadedOrganisationName NVARCHAR(500) NULL,
			OrganisationReferenceNumber NVARCHAR(25) NULL,
			SubmittedUserId NVARCHAR(150) NULL,
			IsComplianceScheme BIT,
			OrganisationType NVARCHAR(50) NULL,
			ProducerSize NVARCHAR(50) NULL,
			ApplicationReferenceNumber NVARCHAR(50) NULL,
			RegistrationReferenceNumber NVARCHAR(50) NULL,
			SubmittedDateTime NVARCHAR(50) NULL,
			RelevantYear INT NULL,
			SubmissionPeriod NVARCHAR(500) NULL,
			IsLateSubmission BIT,
			SubmissionStatus NVARCHAR(20) NULL,
			StatusPendingDate NVARCHAR(50) NULL,
			RegulatorDecisionDate NVARCHAR(50) NULL,
			RegulatorUserId NVARCHAR(150) NULL,
			ProducerCommentDate NVARCHAR(50) NULL,
			ProducerSubmissionEventId NVARCHAR(150) NULL,
			RegulatorSubmissionEventId NVARCHAR(150) NULL,
			NationId INT NULL,
			NationCode NVARCHAR(10) NULL,
			IsResubmission BIT NOT NULL
		);
		
		exec dbo.sp_OrganisationRegistrationSummaries ;

		WITH
            NormalFilterCTE
            AS
            (
                SELECT
					SubmissionId,
					OrganisationId,
					OrganisationInternalId,
					OrganisationName,
					OrganisationReferenceNumber,
					OrganisationType,
					SubmissionStatus,
					StatusPendingDate,
					ApplicationReferenceNumber,
					RegistrationReferenceNumber,
					RelevantYear,
					SubmittedDateTime,
					RegulatorDecisionDate,
					ProducerCommentDate,
					RegulatorUserId,
					NationId,
					NationCode,
                    IsResubmission
			FROM #TempTable i
            WHERE (
				    NationId = @NationId
                    OR @NationId = 0
			)
			AND (
            EXISTS (
                SELECT
                        1
                    FROM
                        STRING_SPLIT(@AppRefNumbersCommaSeparated, ',') AS AppReference
                    WHERE ApplicationReferenceNumber = LTRIM(RTRIM(AppReference.value))
            )
                    OR
                    (
                (
                    (
                        (
                            LEN(ISNULL(@OrganisationNameCommaSeparated, '')) > 0
                    AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) > 0
                    AND EXISTS (
                                SELECT
                        1
                    FROM
                        STRING_SPLIT(@OrganisationNameCommaSeparated, ',') AS Names
                    WHERE OrganisationName LIKE '%' + LTRIM(RTRIM(Names.value)) + '%'
                            )
                    AND EXISTS (
                                SELECT
                        1
                    FROM
                        STRING_SPLIT(@OrganisationReferenceCommaSeparated, ',') AS Reference
                    WHERE OrganisationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                        OR ApplicationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                        OR RegistrationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                            )
                        ) -- Only OrganisationName specified
                    OR (
                            LEN(ISNULL(@OrganisationNameCommaSeparated, '')) > 0
                    AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) = 0
                    AND EXISTS (
                                SELECT
                        1
                    FROM
                        STRING_SPLIT(@OrganisationNameCommaSeparated, ',') AS Names
                    WHERE OrganisationName LIKE '%' + LTRIM(RTRIM(Names.value)) + '%'
                            )
                        ) -- Only OrganisationReference specified
                    OR (
                            LEN(ISNULL(@OrganisationNameCommaSeparated, '')) = 0
                    AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) > 0
                    AND EXISTS (
                                SELECT
                        1
                    FROM
                        STRING_SPLIT(@OrganisationReferenceCommaSeparated, ',') AS Reference
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
                        SELECT
                        TRIM(value)
                    FROM
                        STRING_SPLIT(@OrganisationTypeCommaSeparated, ',')
                    )
                )
                    AND (
                    ISNULL(@SubmissionYearsCommaSeparated, '') = ''
                    OR RelevantYear IN (
                        SELECT
                        TRIM(value)
                    FROM
                        STRING_SPLIT(
                                CONCAT('2024,2025,', @SubmissionYearsCommaSeparated),
                                ','
                            )
                    )
                )
                    AND (
                    ISNULL(@StatusesCommaSeparated, '') = ''
                    OR SubmissionStatus IN (
                        SELECT
                        TRIM(value)
                    FROM
                        STRING_SPLIT(@StatusesCommaSeparated, ',')
                    )
                )
            )
			) )
			,SortedCTE
				AS
				(
					SELECT
						*
					,ROW_NUMBER() OVER (
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
					FROM
						NormalFilterCTE
				)
			,TotalRowsCTE
				AS
				(
					SELECT
						COUNT(*) AS TotalRows
					FROM
						SortedCTE
				)
			,PagedResultsCTE
				AS
				(
					SELECT
						*
					,ROW_NUMBER() OVER (
				ORDER BY RowNum
			) AS PagedRowNum
					FROM
						SortedCTE
				)
			SELECT
				SubmissionId
				,OrganisationId
				,OrganisationInternalId
				,OrganisationType
				,OrganisationName
				,OrganisationReferenceNumber as OrganisationReference
				,SubmissionStatus
				,StatusPendingDate
				,ApplicationReferenceNumber
				,RegistrationReferenceNumber
				,RelevantYear
				,SubmittedDateTime
				,RegulatorDecisionDate AS RegulatorCommentDate
				,ProducerCommentDate
				,RegulatorUserId
				,NationId
				,NationCode
                ,IsResubmission
				,( SELECT COUNT(*) FROM SortedCTE ) AS TotalItems
			FROM
				PagedResultsCTE
			WHERE PagedRowNum > (
			@PageSize * (
				LEAST(
					@PageNumber,
					CEILING(
						(
							SELECT
					TotalRows
				FROM
					TotalRowsCTE
						) / (1.0 * @PageSize)
					)
				) - 1
			)
		)
		AND PagedRowNum <= @PageSize * LEAST(
			@PageNumber,
			CEILING(
				(
					SELECT
					TotalRows
				FROM
					TotalRowsCTE
				) / (1.0 * @PageSize)
			)
		)
		ORDER BY RowNum;
	END
	ELSE
	BEGIN
        SELECT
            CAST(NULL AS UNIQUEIDENTIFIER) AS SubmissionId
            ,CAST(NULL AS UNIQUEIDENTIFIER) AS OrganisationId
            ,CAST(NULL AS Int) AS OrganisationInternalId
            ,CAST(NULL AS NVARCHAR(50)) AS OrganisationType
            ,CAST(NULL AS NVARCHAR(500)) AS OrganisationName
            ,CAST(NULL AS NVARCHAR(25)) AS OrganisationReference
            ,CAST(NULL AS NVARCHAR(20)) AS SubmissionStatus
            ,CAST(NULL AS nvarchar(50)) AS StatusPendingDate
            ,CAST(NULL AS NVARCHAR(50)) AS ApplicationReferenceNumber
            ,CAST(NULL AS NVARCHAR(50)) AS RegistrationReferenceNumber
            ,CAST(NULL AS INT) AS RelevantYear
            ,CAST(NULL AS nvarchar(50)) AS SubmittedDateTime
            ,CAST(NULL AS nvarchar(50)) AS RegulatorCommentDate
            ,CAST(NULL AS nvarchar(50)) AS ProducerCommentDate
            ,CAST(NULL AS UNIQUEIDENTIFIER) AS RegulatorUserId
            ,CAST(NULL AS INT) AS NationId
            ,CAST(NULL AS NVARCHAR(10)) AS NationCode
            ,CAST(0 AS BIT) AS IsResubmission
            ,0 AS TotalItems
        WHERE 1=0
    END;
END;

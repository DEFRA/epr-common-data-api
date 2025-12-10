IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries_resub]'))
DROP PROCEDURE [dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries_resub];
GO

CREATE PROC [dbo].[sp_FilterAndPaginateOrganisationRegistrationSummaries_resub] 
@OrganisationNameCommaSeparated [nvarchar](255),
@OrganisationReferenceCommaSeparated [nvarchar](255),
@SubmissionYearsCommaSeparated [nvarchar](255),
@StatusesCommaSeparated [nvarchar](100),
@ResubmissionStatusesCommaSeparated [nvarchar](100),
@OrganisationTypeCommaSeparated [nvarchar](255),
@NationId [int],@AppRefNumbersCommaSeparated [nvarchar](2000),
@PageSize [INT],
@PageNumber [INT] AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('apps.OrgRegistrationsSummaries') IS NOT NULL
	BEGIN
        DECLARE @CleanedOrgName NVARCHAR(4000) = REPLACE(LTRIM(RTRIM(@OrganisationNameCommaSeparated)), ',', ' ');

		WITH
            NormalFilterCTE
            AS
            (
                SELECT
					ors.SubmissionId,
					ors.OrganisationId,
					ors.OrganisationInternalId,
					ors.OrganisationName,
					ors.OrganisationReference,
					ors.OrganisationType,
					ors.ProducerSize,
					ors.SubmissionStatus,
                    CONVERT(bit, ors.IsResubmission) AS IsResubmission,
					ors.ResubmissionStatus,
					ors.ResubmissionDate,
					ors.StatusPendingDate,
					ors.RegistrationDate,
					ors.ApplicationReferenceNumber,
					ors.RegistrationReferenceNumber,
					ors.RelevantYear,
					ors.SubmittedDateTime,
					ors.RegulatorDecisionDate,
					ors.NationId,
					ors.NationCode,
					s.[RegistrationJourney]
				FROM [apps].[OrgRegistrationsSummaries] as ors
				INNER JOIN [apps].[Submissions] as s 
					ON ors.[SubmissionId] = s.[SubmissionId]
				WHERE ( ( ors.NationId = @NationId OR @NationId = 0 )
					OR ( 
						EXISTS (
								SELECT
									1
								FROM
									STRING_SPLIT(@AppRefNumbersCommaSeparated, ',') AS AppReference
								WHERE ors.ApplicationReferenceNumber = LTRIM(RTRIM(AppReference.value))
						)
					))
			)
            ,ExactNameMatchCTE as (
                select * from NormalFilterCTE
                where OrganisationName = @CleanedOrgName
            )
			,OrganisationTypeValuesCTE as (
				SELECT
					MAX(CASE WHEN LOWER(TRIM(value)) = 'direct' THEN 1 ELSE 0 END) AS HasDirect,
					MAX(CASE WHEN LOWER(TRIM(value)) = 'compliance' THEN 1 ELSE 0 END) AS HasCompliance,
					MAX(CASE WHEN LOWER(TRIM(value)) = 'small' THEN 1 ELSE 0 END) AS HasSmall,
					MAX(CASE WHEN LOWER(TRIM(value)) = 'large' THEN 1 ELSE 0 END) AS HasLarge
				FROM STRING_SPLIT(@OrganisationTypeCommaSeparated, ',')
			)
			,OptionalFiltersCTE as (
				SELECT 
					nf.*
				FROM NormalFilterCTE nf
				CROSS JOIN OrganisationTypeValuesCTE otv
				WHERE
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
                    						WHERE nf.OrganisationName LIKE '%' + LTRIM(RTRIM(Names.value)) + '%'
        						)
        						AND EXISTS (
        									SELECT
                    							1
                    						FROM
                    							STRING_SPLIT(@OrganisationReferenceCommaSeparated, ',') AS Reference
                    						WHERE nf.OrganisationReference LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                    							OR nf.ApplicationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
                    							OR nf.RegistrationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
        						)
    						) 
    						-- Only OrganisationName specified
    						OR (
        						LEN(ISNULL(@OrganisationNameCommaSeparated, '')) > 0
        						AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) = 0
								AND (
										SELECT COUNT(*)
										FROM STRING_SPLIT(@OrganisationNameCommaSeparated, ',') AS Words
										WHERE nf.OrganisationName LIKE '%' + LTRIM(RTRIM(Words.value)) + '%'
									) = (
										SELECT COUNT(*)
										FROM STRING_SPLIT(@OrganisationNameCommaSeparated, ',')
								)
    					    ) 
    						-- Only OrganisationReference specified
    						OR (
    							LEN(ISNULL(@OrganisationNameCommaSeparated, '')) = 0
        						AND LEN(ISNULL(@OrganisationReferenceCommaSeparated, '')) > 0
        						AND EXISTS (
        									SELECT
        							1
        						FROM
        							STRING_SPLIT(@OrganisationReferenceCommaSeparated, ',') AS Reference
        						WHERE nf.OrganisationReference LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
        							OR nf.ApplicationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
        							OR nf.RegistrationReferenceNumber LIKE '%' + LTRIM(RTRIM(Reference.value)) + '%'
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
						OR (
							nf.OrganisationType IN (
								SELECT
								TRIM(value)
							FROM
								STRING_SPLIT(@OrganisationTypeCommaSeparated, ',')
							)
							OR (
								-- DirectSmallProducer = direct & small
								(otv.HasDirect = 1
								 AND otv.HasSmall = 1
								 AND nf.RegistrationJourney = 'DirectSmallProducer')
								-- DirectLargeProducer = direct & large
								OR (otv.HasDirect = 1
								 AND otv.HasLarge = 1
								 AND nf.RegistrationJourney = 'DirectLargeProducer')
								-- CsoSmallProducer = compliance & small
								OR (otv.HasCompliance = 1
								 AND otv.HasSmall = 1
								 AND nf.RegistrationJourney = 'CsoSmallProducer')
								-- CsoLargeProducer = compliance & large
								OR (otv.HasCompliance = 1
								 AND otv.HasLarge = 1
								 AND nf.RegistrationJourney = 'CsoLargeProducer')
								-- null = none of the above (when OrganisationTypeCommaSeparated doesn't match any of the four combinations)
								OR (
									NOT (
										(otv.HasDirect = 1 AND otv.HasSmall = 1)
										OR (otv.HasDirect = 1 AND otv.HasLarge = 1)
										OR (otv.HasCompliance = 1 AND otv.HasSmall = 1)
										OR (otv.HasCompliance = 1 AND otv.HasLarge = 1)
									)
									AND nf.RegistrationJourney IS NULL
								)
							)
						)
					)
					AND (
						ISNULL(@SubmissionYearsCommaSeparated, '') = ''
						OR nf.RelevantYear IN (
							SELECT
							TRIM(value)
						FROM
							STRING_SPLIT(@SubmissionYearsCommaSeparated, ',')
						)
					)
					AND (
						ISNULL(@StatusesCommaSeparated, '') = ''
						OR nf.SubmissionStatus IN (
							SELECT
							TRIM(value)
						FROM
							STRING_SPLIT(@StatusesCommaSeparated, ',')
						)
					)
					AND (
						ISNULL(@ResubmissionStatusesCommaSeparated, '') = ''
						OR nf.ResubmissionStatus IN (
							SELECT TRIM(value)
							FROM STRING_SPLIT(@ResubmissionStatusesCommaSeparated, ',')
						)
					)
			    ) 
            )
            ,FinalFilterCTE as (
                SELECT * FROM ExactNameMatchCTE
                UNION ALL
                SELECT * FROM OptionalFiltersCTE
                WHERE NOT EXISTS (SELECT 1 FROM ExactNameMatchCTE)                
            )
			,SortedCTE AS (
					SELECT
						*
					    ,ROW_NUMBER() OVER (
					        ORDER BY CASE
                						WHEN SubmissionStatus = 'Cancelled' THEN 9
                						WHEN SubmissionStatus = 'Refused' THEN 8
                						WHEN SubmissionStatus = 'Granted' AND ResubmissionStatus IS NULL THEN 7
                						WHEN SubmissionStatus = 'Queried' THEN 6
                						WHEN SubmissionStatus = 'Granted' AND ResubmissionStatus = 'Rejected' THEN 5
                						WHEN SubmissionStatus = 'Granted' AND ResubmissionStatus = 'Accepted' THEN 4
                						WHEN SubmissionStatus = 'Granted' AND ResubmissionStatus = 'Pending' THEN 3
                						WHEN SubmissionStatus = 'Pending' THEN 2
                						WHEN SubmissionStatus = 'Updated' THEN 1
                			END,
					        SubmittedDateTime DESC
			            ) AS RowNum
					FROM FinalFilterCTE
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
			SELECT *, ( SELECT COUNT(*) FROM SortedCTE ) AS TotalItems
			FROM
				PagedResultsCTE
			WHERE 
            PagedRowNum > (
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
            AND 
            PagedRowNum <= @PageSize * LEAST(
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
			,CAST(NULL as NVARCHAR(50)) AS RegistrationDate --NEW
			,CAST(NULL as BIT) as IsResubmission --NEW
			,CAST(NULL as NVARCHAR(50)) as ResubmissionDate --NEW
			,CAST(NULL as NVARCHAR(50)) as ResubmissionStatus --NEW
			,CAST(NULL as NVARCHAR(50)) as RegulatorDecisionDate --NEW
            ,CAST(NULL AS nvarchar(50)) AS RegulatorCommentDate
            ,CAST(NULL AS nvarchar(50)) AS ProducerCommentDate
            ,CAST(NULL AS INT) AS NationId
            ,CAST(NULL AS NVARCHAR(10)) AS NationCode
            ,0 AS TotalItems
        WHERE 1=0
    END;
END;
GO
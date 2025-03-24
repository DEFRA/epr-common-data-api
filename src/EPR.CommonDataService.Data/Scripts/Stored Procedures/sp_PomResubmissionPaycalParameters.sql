IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_PomResubmissionPaycalParameters]'))
DROP PROCEDURE [dbo].[sp_PomResubmissionPaycalParameters];
GO

CREATE PROC [dbo].[sp_PomResubmissionPaycalParameters] @SubmissionId [nvarchar](40),@ComplianceSchemeId [nvarchar](40) 
AS
begin
	declare @IsResubmission BIT = NULL,
		    @ResubmissionDate nvarchar(50),
			@Membercount INT = NULL,
			@Reference nvarchar(50) = NULL,
			@ReferenceAvailable BIT = 0,
			@NationCode nvarchar(10);

	IF EXISTS (
		SELECT 1 
		FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_SCHEMA = 'apps' AND TABLE_NAME = 'SubmissionEvents' 
		AND COLUMN_NAME = 'PackagingResubmissionReferenceNumber'
	)
	BEGIN
		SET @ReferenceAvailable = 1;

		select @IsResubmission = IsResubmission, 
			   @ResubmissionDate = SubmittedDate,
			   @NationCode = NationCode
		FROM (
			SELECT ROW_NUMBER() OVER (ORDER BY SubmittedDate DESC) as RowNum
					, CASE WHEN cs.NationId IS NOT NULL THEN
						CASE cs.NationId
							WHEN 1 THEN 'GB-ENG'
							WHEN 2 THEN 'GB-NIR'
							WHEN 3 THEN 'GB-SCT'
							WHEN 4 THEN 'GB-WLS'
						END
					  ELSE CASE UPPER(org.NationId)
								WHEN '1' THEN 'GB-ENG'
								WHEN '2' THEN 'GB-NIR'
								WHEN '3' THEN 'GB-SCT'
								WHEN '4' THEN 'GB-WLS'
							END
					  END as NationCode
					, s.*
			FROM apps.SubmissionsSummaries s 
			left join rpd.ComplianceSchemes cs on cs.ExternalId = s.ComplianceSchemeId
			inner join rpd.Organisations org on org.ExternalId = s.OrganisationId
			WHERE s.SubmissionId = @SubmissionId
		) innsers
		WHERE RowNum = 1;

		if ( @IsResubmission = 1 )
		BEGIN
			DECLARE @sql NVARCHAR(MAX);

			SET @sql = N'
			select @Reference = innerse.PackagingResubmissionReferenceNumber
			from (
				select TOP 1 PackagingResubmissionReferenceNumber
				FROM apps.SubmissionEvents se
				where se.[Type] = ''PackagingResubmissionReferenceNumberCreated'' and se.SubmissionId = @SubmissionId
				ORDER BY Created desc
			) innerse;
			';

			exec sp_executesql @sql,
							   N'@SubmissionId nvarchar(50), @Reference NVARCHAR(255) OUTPUT', 
							   @SubmissionId = @SubmissionId, 
							   @Reference = @Reference OUTPUT

			if ( @ComplianceSchemeId IS NOT NULL)
			BEGIN
				declare @SubmissionPeriod nvarchar(50),
						@OrganisationRefNum nvarchar(20);

				select @SubmissionPeriod = inners.SubmissionPeriod,
						@OrganisationRefNum = inners.OrganisationReference
				from (
					select TOP 1 SubmissionPeriod, OrganisationReference
					from apps.SubmissionsSummaries s
					where s.SubmissionId = @SubmissionId
					order by s.SubmittedDate desc
				) as inners ;

				exec [dbo].[sp_CSO_Pom_Resubmitted_ByCSID] @OrganisationRefNum, 
															@ComplianceSchemeId, 
															@SubmissionPeriod, 
															@MemberCount OUTPUT;
			END

			SELECT 
			CASE 
				WHEN @ComplianceSchemeId IS NOT NULL THEN @MemberCount
				ELSE CAST(NULL as INT)
			END AS MemberCount,
			CASE 
				WHEN @ReferenceAvailable = 0 THEN CAST(NULL AS NVARCHAR(50))
				ELSE @Reference
			END AS Reference,
			@ResubmissionDate as ResubmissionDate,
			@IsResubmission as IsResubmission,
			@ReferenceAvailable AS ReferenceFieldAvailable,
			@NationCode as NationCode
		END
		ELSE
		BEGIN
			if (@IsResubmission = 0)
			BEGIN
				SELECT 
					CAST(NULL as INT) AS MemberCount,
					CAST(NULL AS NVARCHAR(50)) as Reference,
					CAST(NULL AS NVARCHAR(50)) as ResubmissionDate,
					CAST(0 AS BIT) as IsResubmission,
					@ReferenceAvailable as ReferenceFieldAvailable,
					@NationCode as NationCode
			END

			if (@IsResubmission IS NULL)
			BEGIN
				SELECT 
					CAST(NULL as INT) AS MemberCount,
					CAST(NULL AS NVARCHAR(50)) as Reference,
					CAST(NULL AS NVARCHAR(50)) as ResubmissionDate,
					CAST(NULL AS BIT) as IsResubmission,
					CAST(NULL AS BIT) as ReferenceFieldAvailable,
					CAST(NULL AS NVARCHAR(20)) As NationCode
				WHERE 1=0;
			END
		END
	END
	ELSE
	BEGIN
		SELECT 
			CAST(NULL as INT) AS MemberCount,
			CAST(NULL AS NVARCHAR(50)) as Reference,
			CAST(NULL AS NVARCHAR(50)) as ResubmissionDate,
			CAST(NULL AS BIT) as IsResubmission,
			CAST(0 AS BIT) as ReferenceFieldAvailable,
			CAST(NULL AS NVARCHAR(20)) As NationCode
	END
end;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_PomResubmissionPaycalParameters]'))
DROP PROCEDURE [dbo].[sp_PomResubmissionPaycalParameters];
GO

CREATE proc [dbo].[sp_PomResubmissionPaycalParameters] @SubmissionId nvarchar(40), @ComplianceSchemeId nvarchar(40)
as
begin
	declare @IsResubmission BIT = NULL,
		    @ResubmissionDate nvarchar(50),
			@Membercount INT = NULL,
			@Reference nvarchar(50) = NULL,
			@ReferenceAvailable BIT = 0;

	IF EXISTS (
		SELECT 1 
		FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_SCHEMA = 'rpd' AND TABLE_NAME = 'SubmissionEvents' 
		AND COLUMN_NAME = 'PackagingResubmissionReferenceNumber'
	)
	BEGIN
		SET @ReferenceAvailable = 1;

		select @IsResubmission = IsResubmission, @ResubmissionDate = SubmittedDate FROM (
			SELECT ROW_NUMBER() 
					OVER (ORDER BY SubmittedDate DESC) as RowNum, *
			FROM apps.SubmissionsSummaries where SubmissionId = @SubmissionId
		) innsers
		WHERE RowNum = 1;
		-- To Deal with Sync issues:
		set @IsResubmission = 1;

		if ( @IsResubmission = 1 )
		BEGIN
			DECLARE @sql NVARCHAR(MAX);

			SET @sql = N'
			select @Reference = innerse.PackagingResubmissionReferenceNumber
			from (
				select TOP 1 PackagingResubmissionReferenceNumber
				FROM rpd.SubmissionEvents se
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
				WHEN @ComplianceSchemeId IS NULL AND @ReferenceAvailable = 0 THEN CAST(NULL AS NVARCHAR(50))
				ELSE @Reference
			END AS Reference,
			@ResubmissionDate as ResubmissionDate,
			@IsResubmission as IsResubmission,
			@ReferenceAvailable AS ReferenceFieldAvailable
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
					@ReferenceAvailable as ReferenceFieldAvailable
			END

			if (@IsResubmission IS NULL)
			BEGIN
				SELECT 
					CAST(NULL as INT) AS MemberCount,
					CAST(NULL AS NVARCHAR(50)) as Reference,
					CAST(NULL AS NVARCHAR(50)) as ResubmissionDate,
					CAST(NULL AS BIT) as IsResubmission,
					CAST(NULL AS BIT) as ReferenceFieldAvailable
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
			CAST(0 AS BIT) as ReferenceFieldAvailable
	END
end;
GO

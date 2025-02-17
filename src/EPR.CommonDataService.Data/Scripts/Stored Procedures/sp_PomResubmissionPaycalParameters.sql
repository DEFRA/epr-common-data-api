﻿IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_PomResubmissionPaycalParameters]'))
DROP PROCEDURE [dbo].[sp_PomResubmissionPaycalParameters];
GO

CREATE PROC [dbo].[sp_PomResubmissionPaycalParameters] @SubmissionId nvarchar(40), @ComplianceSchemeId nvarchar(40)
as
begin
	declare @IsResubmission BIT = 0,
		    @ResubmissionDate nvarchar(50),
			@Membercount INT = NULL,
			@Reference nvarchar(50) = NULL,
			@ReferenceAvailable BIT = 0;

	IF EXISTS (
		SELECT 1 
		FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_SCHEMA = 'apps' AND TABLE_NAME = 'SubmissionEvents' 
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

		if ( @IsResubmission = 1 )
		BEGIN
			DECLARE @sql NVARCHAR(MAX);

			SET @sql = N'
			select @Reference = innerse.PackagingResubmissionReferenceNumber
			from (
				select TOP 1 PackagingResubmissionReferenceNumber
				FROM apps.SubmissionEvents se
				where se.[Type] = ''POMResubmission'' and se.SubmissionId = @SubmissionId
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
		END
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
    @ReferenceAvailable AS ReferenceAvailable
end;
GO

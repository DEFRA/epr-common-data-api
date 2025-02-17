IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_PomResubmissionPaycalParameters]'))
DROP PROCEDURE [dbo].[sp_PomResubmissionPaycalParameters];
GO

CREATE PROC [dbo].[sp_PomResubmissionPaycalParameters] @SubmissionId nvarchar(40), @ComplianceSchemeId nvarchar(40)
as
begin
	declare @Membercount INT = NULL,
			@Reference nvarchar(50) = NULL,
			@ReferenceAvailable BIT = 0;

	IF EXISTS (
		SELECT 1 
		FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_NAME = 'rpd.SubmissionEvents' 
		AND COLUMN_NAME = 'PackagingResubmissionReferenceNumber'
	)
	BEGIN
		SET @ReferenceAvailable = 1;
		select @Reference = innerse.PackagingResubmissionReferenceNumber
		from (
			select TOP 1 PackagingResubmissionReferenceNumber
			FROM rpd.SubmissionEvents se
			where se.[Type] = 'POMResubmission' and se.SubmissionId = @SubmissionId
			ORDER BY Created desc
		) innerse;
	END

	if ( @ComplianceSchemeId IS NOT NULL)
	BEGIN
		declare @SubmissionPeriod nvarchar(50),
				@OrganisationExternalId nvarchar(50);

		select @SubmissionPeriod = inners.SubmissionPeriod,
				@OrganisationExternalId = inners.Organisationid
		from (
			select TOP 1 SubmissionPeriod, OrganisationId
			from rpd.Submissions s
			where s.SubmissionId = @SubmissionId
			order by s.Created desc
		) as inners ;

		exec [dbo].[sp_CSO_Pom_Resubmitted_ByCSID] @OrganisationExternalId, 
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
    @ReferenceAvailable AS ReferenceAvailable
end;
GO

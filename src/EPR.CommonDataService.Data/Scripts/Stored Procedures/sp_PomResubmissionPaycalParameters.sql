IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_PomResubmissionPaycalParameters]'))
DROP PROCEDURE [dbo].[sp_PomResubmissionPaycalParameters];
GO

CREATE PROC [dbo].[sp_PomResubmissionPaycalParameters] @SubmissionId [nvarchar](40),@ComplianceSchemeId [nvarchar](40) AS
begin
	--DECLARE @start_dt datetime;
	--DECLARE @batch_id INT;
	--DECLARE @cnt int;

	declare @IsResubmission BIT = NULL,
		    @ResubmissionDate nvarchar(50),
			@Membercount INT = NULL,
			@DPMemberCount INT = NULL,
			@Reference nvarchar(50) = NULL,
			@ReferenceAvailable BIT = 0,
			@NationCode nvarchar(10),
			@SubmissionYear  INT = NULL;

	--select @batch_id  = ISNULL(max(batch_id),0)+1 from [dbo].[batch_log]
	--set @start_dt = getdate()
--Checks that the apps.SubmissionEvents table exists with column PackagingResubmissionReferenceNumber
	IF EXISTS (
		SELECT 1 
		FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_SCHEMA = 'apps' AND TABLE_NAME = 'SubmissionEvents' 
		AND COLUMN_NAME = 'PackagingResubmissionReferenceNumber'
	)
	BEGIN
		SET @ReferenceAvailable = 1;
--Grabbing the various require parameters for the given ComplianceScheme from the latest submission
		select @IsResubmission = IsResubmission, 
			   @ResubmissionDate = SubmittedDate,
			   @NationCode = NationCode,
			   @SubmissionYear = SubmissionYear
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
--Following Code only applies if IsResbumission flag = 1
		if ( @IsResubmission = 1 ) 
		BEGIN
			
		Select  @Reference =  PackagingResubmissionReferenceNumber from dbo.t_PomResubmissionPaycalEvents where SubmissionId = @SubmissionId
---APPEARS TO BE CODE specifically for Compliance Schemes
--Note - the ComplianceSchemeId parameter is not set in the SP but passed in by the looks of things
--This section seems to be gathering the required parameters to then send to the underlying sp when it runs it on line 95
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
--OTHER SP gets triggered here and passes back the MemberCount paramter back from it
				
		Select @MemberCount= IsNull(MemberCount,0) from t_CSO_Pom_resubmitted_ByCSID where CS_reference_number=@OrganisationRefNum and CSid=@ComplianceSchemeId and submissionperiod=@SubmissionPeriod
			END
--Note that the above member count is the count of members of a compliance scheme that are not new members between submissions - that has Pom data changes made to it

---------NEW---------
--For DP submissions
			IF ( @ComplianceSchemeId IS NULL)
			BEGIN
				declare @DPSubmissionPeriod nvarchar(50),
						@DPOrganisationRefNum nvarchar(20);

				select @DPSubmissionPeriod = inners2.SubmissionPeriod,
						@DPOrganisationRefNum = inners2.OrganisationReference
				from (
					select TOP 1 SubmissionPeriod, OrganisationReference
					from apps.SubmissionsSummaries s
					where s.SubmissionId = @SubmissionId
					order by s.SubmittedDate desc
				) as inners2 ;
--OTHER SP gets triggered here and passes back the MemberCount paramter back from it
				exec [dbo].[sp_DP_Pom_Resubmitted_ByDPID] @DPOrganisationRefNum,
															@DPSubmissionPeriod, 
															@DPMemberCount OUTPUT;
			END
			
			
-----/NEW-----------
			SELECT 
			CASE 
				WHEN @SubmissionYear < 2024 THEN 0
				WHEN @ComplianceSchemeId IS NOT NULL THEN @MemberCount
				WHEN @ComplianceSchemeId IS NULL THEN @DPMemberCount
				ELSE CAST(NULL as INT)
			END AS MemberCount,
			--Above seems to just set the field MemberCount as the count returned from the SP if a CS or NULL if a DP.
			CASE 
				WHEN @ReferenceAvailable = 0 THEN CAST(NULL AS NVARCHAR(50))
				ELSE @Reference
			END AS Reference,
			@ResubmissionDate as ResubmissionDate,
			@IsResubmission as IsResubmission,
			@ReferenceAvailable AS ReferenceFieldAvailable,
			@NationCode as NationCode
		END
--End of code for IsResubmission flag = 1
		ELSE

--This section is for when the IsResubmission flag = 0 i.e. not a resubmission
-- seems to set columns to null
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
--Above appears to set the member count and other columns to NULL if resub = 0
--Below is the same thing except for when the IsResubmission field is NULL rather than 1 or 0
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
	--Catch all ELSE statement 
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
--COMMENTING THIS OUT FOR NOW AS DO NOT WANT TO FILL UP THE BATCH LOG WHILST DEVELOPING--
	--INSERT INTO [dbo].[batch_log] ([ID],[ProcessName],[SubProcessName],[Count],[start_time_stamp],[end_time_stamp],[Comments],batch_id)
	--select (select ISNULL(max(id),1)+1 from [dbo].[batch_log]),'dbo.sp_PomResubmissionPaycalParameters',@SubmissionId, NULL, @start_dt, getdate(), '@SubmissionId@ComplianceSchemeId',@batch_id
end;
GO

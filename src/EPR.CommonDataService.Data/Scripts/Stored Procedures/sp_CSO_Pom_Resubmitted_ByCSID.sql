IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_CSO_Pom_Resubmitted_ByCSID]'))
DROP PROCEDURE [dbo].[sp_CSO_Pom_Resubmitted_ByCSID];
GO

CREATE PROC [dbo].[sp_CSO_Pom_Resubmitted_ByCSID]
	@CSOrganisation_ID [INT]
	,@ComplianceSchemeId [nvarchar](40)
	,@SubmissionPeriod [Varchar](100)
	,@MemberCount [INT] OUT
AS
BEGIN
	DECLARE @latest_accepted_file NVARCHAR(4000);
	DECLARE @latest_resubmitted_file NVARCHAR(4000);
	DECLARE @original_file_accepted NVARCHAR(4000);
	DECLARE @original_file_resubmitted NVARCHAR(4000);

	--IDENTIFY FILES TO COMPARE--
	WITH
		latestSubmittedFiles
		AS
		(
			-- Identify the latest submitted file for each organization and submission period
			SELECT
				DISTINCT
				lsf.*
			FROM
				(
            SELECT
					DISTINCT
					a.filename
					,a.fileid
					,a.created
					,a.submissionperiod
					,a.complianceSchemeId
					,a.OrganisationId
					,b.ReferenceNumber
					,a.OriginalFileName
					,ROW_NUMBER() OVER (PARTITION BY a.OrganisationId, a.submissionperiod, a.complianceschemeid ORDER BY CONVERT(DATETIME, Substring(a.[created], 1, 23)) DESC) AS RowNumber
				FROM
					rpd.cosmos_file_metadata a
					INNER JOIN rpd.Organisations b ON b.externalid = a.OrganisationId
					INNER JOIN [rpd].[SubmissionEvents] se ON TRIM(se.fileid) = TRIM(a.fileid)
						AND se.[type] = 'Submitted'
						AND a.FileType = 'Pom'
				WHERE b.ReferenceNumber = @CSOrganisation_ID
					AND a.complianceschemeid = @ComplianceSchemeId
					AND a.submissionperiod=@SubmissionPeriod 
        ) lsf
			WHERE
        lsf.RowNumber = 1
		)
--select * from latestSubmittedFiles
,PreviousAcceptedFiles
		AS
		(
			-- Identify the latest accepted file for each organization and submission period
			SELECT
				rap.*
			FROM
				(
            SELECT
					DISTINCT
					a.filename
					,a.fileid
					,a.created
					,a.submissionperiod
					,a.complianceSchemeId
					,a.OrganisationId
					,b.ReferenceNumber
					,a.OriginalFileName
					,ROW_NUMBER() OVER (PARTITION BY a.OrganisationId, a.submissionperiod, a.complianceschemeid ORDER BY CONVERT(DATETIME, Substring(a.[created], 1, 23)) DESC) AS RowNumber
				FROM
					rpd.cosmos_file_metadata a
					INNER JOIN rpd.Organisations b ON b.externalid = a.OrganisationId
					INNER JOIN [rpd].[SubmissionEvents] se ON TRIM(se.fileid) = TRIM(a.fileid)
						AND se.[type] = 'RegulatorPoMDecision'
						AND se.Decision = 'Accepted'
						AND a.FileType = 'Pom'
				WHERE b.ReferenceNumber = @CSOrganisation_ID
					AND a.complianceschemeid = @ComplianceSchemeId
					AND a.submissionperiod=@SubmissionPeriod
					AND a.FileId NOT IN ( SELECT
						fileid
					FROM
						latestSubmittedFiles)
        ) rap
			WHERE rap.RowNumber = 1
		)
--select * from PreviousAcceptedFiles;
,LatestAcceptedFiles
		AS
		(
			-- Identify the latest accepted file for each organization and submission period
			SELECT
				rap.*
			FROM
				(
            					SELECT
						DISTINCT
						a.filename
						,a.fileid
						,a.created
						,a.submissionperiod
						,a.complianceSchemeId
						,a.OrganisationId
						,b.ReferenceNumber
						,a.OriginalFileName
						,ROW_NUMBER() OVER (PARTITION BY a.OrganisationId, a.submissionperiod, a.complianceschemeid ORDER BY CONVERT(DATETIME, Substring(a.[created], 1, 23)) DESC) AS RowNumber
					FROM
						rpd.cosmos_file_metadata a
						INNER JOIN rpd.Organisations b ON b.externalid = a.OrganisationId
						INNER JOIN [rpd].[SubmissionEvents] se ON TRIM(se.fileid) = TRIM(a.fileid)
							AND se.[type] = 'RegulatorPoMDecision'
							AND se.Decision = 'Accepted'
							AND a.FileType = 'Pom'
					WHERE b.ReferenceNumber = @CSOrganisation_ID
						AND a.complianceschemeid = @ComplianceSchemeId
						AND a.submissionperiod=@SubmissionPeriod
				EXCEPT
					SELECT
						*
					FROM
						latestSubmittedFiles
        ) rap
			WHERE 1=1
				AND rap.RowNumber = 1
		)

	SELECT
		DISTINCT
		@latest_accepted_file= paf.filename 
		,@latest_resubmitted_file= lsf.filename
		,@original_file_accepted=paf.OriginalFileName
		,@original_file_resubmitted=lsf.OriginalFileName
	FROM
		latestSubmittedFiles lsf
		INNER JOIN PreviousAcceptedFiles paf ON ISNULL(paf.OrganisationID, '') = ISNULL(lsf.OrganisationID, '')
			AND lsf.filename <> paf.filename
			AND paf.created < lsf.created;


	--COMPARISON OF THE FILES--
	--Resubmitted File Minus Latest Accepted File
	--All NEW Orgs to be paid for
	WITH
		changed_and_new_data
		AS
		(
							SELECT
					[organisation_id] 
					,[subsidiary_id]
					,[organisation_size] 
					,[submission_period] 
					,[packaging_activity]
					,[packaging_type] 
					,[packaging_class] 
					,[packaging_material] 
					,[packaging_material_subtype] 
					,[from_country]
					,[to_country] 
					,[packaging_material_weight]
					,[packaging_material_units]
					,[transitional_packaging_units]
				FROM
					rpd.pom
				WHERE filename = @latest_resubmitted_file
			EXCEPT
				SELECT
					[organisation_id]
					,[subsidiary_id]
					,[organisation_size] 
					,[submission_period] 
					,[packaging_activity]
					,[packaging_type] 
					,[packaging_class] 
					,[packaging_material] 
					,[packaging_material_subtype] 
					,[from_country]
					,[to_country] 
					,[packaging_material_weight]
					,[packaging_material_units] 
					,[transitional_packaging_units]
				FROM
					rpd.pom
				WHERE filename = @latest_accepted_file
		)
							
--select * from changed_and_new_data
--Latest Accepted File Minus Resubmitted File
-- 
,Removed_Data
		AS
		(
							SELECT
					[organisation_id] 
					,[subsidiary_id]
					,[organisation_size] 
					,[submission_period] 
					,[packaging_activity]
					,[packaging_type] 
					,[packaging_class] 
					,[packaging_material] 
					,[packaging_material_subtype] 
					,[from_country]
					,[to_country] 
					,[packaging_material_weight]
					,[packaging_material_units] 
					,[transitional_packaging_units]
				FROM
					rpd.pom
				WHERE filename =@latest_accepted_file

			EXCEPT

				SELECT
					[organisation_id]
					,[subsidiary_id]
					,[organisation_size] 
					,[submission_period] 
					,[packaging_activity]
					,[packaging_type] 
					,[packaging_class] 
					,[packaging_material] 
					,[packaging_material_subtype] 
					,[from_country]
					,[to_country] 
					,[packaging_material_weight]
					,[packaging_material_units] 
					,[transitional_packaging_units]
				FROM
					rpd.pom
				WHERE filename = @latest_resubmitted_file
		)
--select * from Removed_Data
--Find NEW members so we can exclude them from the count--
,find_new_members
		AS
		(
							SELECT
					[organisation_id]
				FROM
					rpd.pom
				WHERE filename =@latest_resubmitted_file

			EXCEPT

				SELECT
					[organisation_id]
				FROM
					rpd.pom
				WHERE filename = @latest_accepted_file
		)
--select * from find_new_members

--Find REMOVED members so we can exclude them from the count--
,find_removed_members
		AS
		(
			--OLD FILE--
							SELECT
					[organisation_id]
				FROM
					rpd.pom
				WHERE filename =@latest_accepted_file

			EXCEPT

				--NEW FILE--
				SELECT
					[organisation_id]
				FROM
					rpd.pom
				WHERE filename = @latest_resubmitted_file
		)
	--select * from find_removed_members


	SELECT
		@MemberCount = COUNT(DISTINCT organisation_id)
	FROM(	
	--Changed_and_new_data CTE contains the new members, taking these new members out
				SELECT
				DISTINCT
				find_new_members.organisation_id
			FROM
				find_new_members
				INNER JOIN
				(SELECT
					DISTINCT
					Organisation_ID
				FROM
					changed_and_new_data) sub ON sub.Organisation_ID = find_new_members.Organisation_ID
		UNION
			SELECT
				DISTINCT
				find_removed_members.organisation_id
			FROM
				find_removed_members
				INNER JOIN
				(SELECT
					DISTINCT
					Organisation_ID
				FROM
					Removed_Data ) rub ON rub.Organisation_ID = find_removed_members.Organisation_ID

) sub;

END;

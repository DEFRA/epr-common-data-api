/****** Object:  StoredProcedure [dbo].[sp_DP_Pom_Resubmitted_ByDPID ]    Script Date: 05/11/2025 13:54:28 ******/
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[dbo].[sp_DP_Pom_Resubmitted_ByDPID]'))
DROP PROCEDURE [dbo].[sp_DP_Pom_Resubmitted_ByDPID];
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[sp_DP_Pom_Resubmitted_ByDPID ] @DPOrganisation_ID [INT],@SubmissionPeriod [Varchar](100),@MemberCount [INT] OUT AS
BEGIN
	DECLARE @latest_accepted_file NVARCHAR(4000);
	DECLARE @latest_resubmitted_file NVARCHAR(4000);


--IDENTIFY FILES TO COMPARE--
WITH latestSubmittedFiles AS (
/*****************************************************************************************************************
	History:
	Created 2025-10-04:	ST001: 618686: Created the SP sp_DP_Pom_Resubmitted_ByDPID
	Amended 2025-10-09: ST002: 624926: Removed specific CTE to cater for Zero Returns as new understanding means covered in find_new_members CTE logic
 *****************************************************************************************************************/	

-- Identify the latest submitted file for each organization and submission period
    SELECT
        DISTINCT lsf.*
    FROM
        (
            SELECT
                DISTINCT a.filename,
                a.fileid,
                a.created,
                a.submissionperiod,
                a.OrganisationId,
                b.ReferenceNumber,
				a.OriginalFileName,
                ROW_NUMBER() OVER (PARTITION BY a.OrganisationId, a.submissionperiod ORDER BY CONVERT(DATETIME, Substring(a.[created], 1, 23)) DESC) AS RowNumber
            FROM
                rpd.cosmos_file_metadata a
            INNER JOIN rpd.Organisations b ON b.externalid = a.OrganisationId
            INNER JOIN [rpd].[SubmissionEvents] se ON TRIM(se.fileid) = TRIM(a.fileid)
            AND se.[type] = 'Submitted'
			AND a.FileType = 'Pom'
            WHERE b.ReferenceNumber = @DPOrganisation_ID
			and a.submissionperiod=@SubmissionPeriod 
        ) lsf
    WHERE
        lsf.RowNumber = 1
)
,PreviousAcceptedFiles AS (
    -- Identify the latest accepted file for each organization and submission period
    SELECT
        rap.*
    FROM
        (
            SELECT
                DISTINCT a.filename,
                a.fileid,
                a.created,
                a.submissionperiod,
                a.OrganisationId,
                b.ReferenceNumber,
				a.OriginalFileName,
				ROW_NUMBER() OVER (PARTITION BY a.OrganisationId, a.submissionperiod ORDER BY CONVERT(DATETIME, Substring(a.[created], 1, 23)) DESC) AS RowNumber
            FROM
                rpd.cosmos_file_metadata a
            INNER JOIN rpd.Organisations b ON b.externalid = a.OrganisationId
            INNER JOIN [rpd].[SubmissionEvents] se ON TRIM(se.fileid) = TRIM(a.fileid)
            AND se.[type] = 'RegulatorPoMDecision'
            AND se.Decision = 'Accepted'
			AND a.FileType = 'Pom'
			WHERE b.ReferenceNumber = @DPOrganisation_ID
			and a.submissionperiod=@SubmissionPeriod 
			AND a.FileId not in ( select fileid from latestSubmittedFiles)
        ) rap
    WHERE rap.RowNumber = 1
)

SELECT
    DISTINCT @latest_accepted_file= paf.filename ,
    @latest_resubmitted_file= lsf.filename
	FROM
    latestSubmittedFiles lsf
INNER JOIN PreviousAcceptedFiles paf ON ISNULL(paf.OrganisationID, '') = ISNULL(lsf.OrganisationID, '')
AND lsf.filename <> paf.filename
AND paf.created < lsf.created;

--COMPARISON OF THE FILES--
--Resubmitted File Minus Latest Accepted File leaves us with the data which is either changed for existing members or new member entries
WITH changed_and_new_data AS 
						(SELECT
							[organisation_id] ,
							[subsidiary_id],
							[organisation_size] ,
							[submission_period] ,
							[packaging_activity],
							[packaging_type] ,
							[packaging_class] ,
							[packaging_material] ,
							[packaging_material_subtype] ,
							[from_country],
							[to_country] ,
							[packaging_material_weight],
							[packaging_material_units],
							[transitional_packaging_units]
							FROM rpd.pom where filename = @latest_resubmitted_file
						EXCEPT
						SELECT
							[organisation_id], 
							[subsidiary_id],
							[organisation_size] ,
							[submission_period] ,
							[packaging_activity],
							[packaging_type] ,
							[packaging_class] ,
							[packaging_material] ,
							[packaging_material_subtype] ,
							[from_country],
							[to_country] ,
							[packaging_material_weight],
							[packaging_material_units] ,
							[transitional_packaging_units]
							FROM rpd.pom where filename = @latest_accepted_file)
	
--Find NEW members so we can exclude them from the count--
--Note This will include Zero Returns scenario as the expectation to not charge is only when they previously didnt submit any data for a member
--This CTE will flag these as new members and the script excludes later on
,find_new_members AS
(
SELECT
organisation_id, subsidiary_id 
FROM
rpd.pom where filename =@latest_resubmitted_file
EXCEPT
SELECT
organisation_id, subsidiary_id
FROM
rpd.pom where filename = @latest_accepted_file
)


SELECT @MemberCount = COUNT (*)
	FROM(
		SELECT DISTINCT organisation_id, subsidiary_id 
			FROM(	
			--Taking all Changed and New data 
					(SELECT DISTINCT Organisation_ID, subsidiary_id 
					FROM changed_and_new_data
					EXCEPT
					-- MINUS from this data set the new members (includes new members that are Zero Returns)
					SELECT DISTINCT organisation_id, subsidiary_id
					FROM find_new_members
					)
				) AS diff
	)AS Distinct_Combinations

END;
GO

IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[v_CSO_Pom_Resubmitted_ByCSID]')
) DROP VIEW [dbo].[v_CSO_Pom_Resubmitted_ByCSID];

GO

CREATE VIEW [dbo].[v_CSO_Pom_Resubmitted_ByCSID] AS WITH latestSubmittedFiles AS (
/*****************************************************************************************************************
	History:
	Amended 2025-10-07: JP001: 617502: Added subsidiary id to select statements in find_new_members CTE and final output.
	Amended 2025-10-10: JP002: 625935: Removed specific CTE for Zero Returns as covered by find_new_members CTE logic
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
                a.complianceSchemeId,
                a.OrganisationId,
                b.ReferenceNumber,
				a.OriginalFileName,
                ROW_NUMBER() OVER (PARTITION BY a.OrganisationId, a.submissionperiod, a.complianceschemeid ORDER BY CONVERT(DATETIME, Substring(a.[created], 1, 23)) DESC) AS RowNumber
            FROM
                rpd.cosmos_file_metadata a
            INNER JOIN rpd.Organisations b ON b.externalid = a.OrganisationId
            INNER JOIN [rpd].[SubmissionEvents] se ON TRIM(se.fileid) = TRIM(a.fileid)
            AND se.[type] = 'Submitted'
			AND a.FileType = 'Pom'
            WHERE --b.ReferenceNumber = @CSOrganisation_ID
			 a.complianceschemeid is not null
			--and a.submissionperiod=@SubmissionPeriod 
        ) lsf
    WHERE
        lsf.RowNumber = 1
)

--select * from latestSubmittedFiles 
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
                a.complianceSchemeId,
                a.OrganisationId,
                b.ReferenceNumber,
				a.OriginalFileName,
				ROW_NUMBER() OVER (PARTITION BY a.OrganisationId, a.submissionperiod, a.complianceschemeid ORDER BY CONVERT(DATETIME, Substring(a.[created], 1, 23)) DESC) AS RowNumber
            FROM
                rpd.cosmos_file_metadata a
            INNER JOIN rpd.Organisations b ON b.externalid = a.OrganisationId
            INNER JOIN [rpd].[SubmissionEvents] se ON TRIM(se.fileid) = TRIM(a.fileid)
            AND se.[type] = 'RegulatorPoMDecision'
            AND se.Decision = 'Accepted'
			AND a.FileType = 'Pom'
			WHERE --b.ReferenceNumber = @CSOrganisation_ID
			a.complianceschemeid is not null
			--and a.submissionperiod=@SubmissionPeriod 
			AND a.FileId not in ( select fileid from latestSubmittedFiles)
        ) rap
    WHERE rap.RowNumber = 1
)
--select * from PreviousAcceptedFiles 


,variables as (SELECT
    DISTINCT latest_accepted_file= paf.filename , --removed variable
    latest_resubmitted_file= lsf.filename --removed variable
	,CS_Reference_number = lsf.referencenumber
	,CSid = lsf.complianceSchemeId
	,submissionperiod = lsf.submissionperiod
	FROM
    latestSubmittedFiles lsf
INNER JOIN PreviousAcceptedFiles paf ON ISNULL(paf.OrganisationID, '') = ISNULL(lsf.OrganisationID, '') 
and ISNULL(paf.complianceSchemeId, '') = ISNULL(lsf.complianceSchemeId, '')
and ISNULL(paf.submissionperiod, '') = ISNULL(lsf.submissionperiod, '')
AND lsf.filename <> paf.filename
AND paf.created < lsf.created
)

--SELECT * FROM variables

--COMPARISON OF THE FILES--
--Resubmitted File Minus Latest Accepted File
--All NEW Orgs to be paid for
,changed_and_new_data AS 
						(SELECT
							p.[organisation_id] ,
							p.[subsidiary_id],
							p.[organisation_size] ,
							p.[submission_period] ,
							p.[packaging_activity],
							p.[packaging_type] ,
							p.[packaging_class] ,
							p.[packaging_material] ,
							p.[packaging_material_subtype] ,
							p.[from_country],
							p.[to_country] ,
							p.[packaging_material_weight],
							p.[packaging_material_units],
							p.[transitional_packaging_units],
							vars.CS_Reference_number,
							vars.CSid,
							vars.submissionperiod
							FROM rpd.pom p
							left join variables vars on p.filename = vars.latest_resubmitted_file
							where p.filename = vars.latest_resubmitted_file -- removed variable
						EXCEPT
						SELECT
							p.[organisation_id], 
							p.[subsidiary_id],
							p.[organisation_size] ,
							p.[submission_period] ,
							p.[packaging_activity],
							p.[packaging_type] ,
							p.[packaging_class] ,
							p.[packaging_material] ,
							p.[packaging_material_subtype] ,
							p.[from_country],
							p.[to_country] ,
							p.[packaging_material_weight],
							p.[packaging_material_units] ,
							p.[transitional_packaging_units],
							vars.CS_Reference_number,
							vars.CSid,
							vars.submissionperiod
							FROM rpd.pom p
							left join variables vars on p.filename = vars.latest_accepted_file
							where p.filename = vars.latest_accepted_file ) -- removed variable
--select * from changed_and_new_data
--Find NEW members so we can exclude them from the count--
,find_new_members AS
(
	SELECT
	p.[organisation_id], p.[subsidiary_id]
								,vars.CS_Reference_number,
								vars.CSid,
								vars.submissionperiod
	FROM
	rpd.pom p
	left join variables vars on p.filename = vars.latest_resubmitted_file
	where p.filename = vars.latest_resubmitted_file -- removed variable

	EXCEPT

	SELECT
	p.[organisation_id], p.[subsidiary_id]
								,vars.CS_Reference_number,
								vars.CSid,
								vars.submissionperiod
	FROM
	rpd.pom p
	left join variables vars on p.filename = vars.latest_accepted_file
	where p.filename = latest_accepted_file -- removed variable
	)

, MemberCountTotals AS (SELECT 
CS_Reference_number,
		CSid,
		submissionperiod,
		MemberCount = COUNT(*)
		FROM
	(SELECT DISTINCT organisation_id, subsidiary_id,
						CS_Reference_number,
						CSid,
						submissionperiod FROM(	
		(SELECT DISTINCT Organisation_ID, subsidiary_id,
							CS_Reference_number,
							CSid,
							submissionperiod 
			FROM changed_and_new_data
			EXCEPT
			SELECT DISTINCT organisation_id, subsidiary_id,
							CS_Reference_number,
							CSid,
							submissionperiod
			FROM find_new_members)
		)sub
		) as new
		group by CS_Reference_number,
		CSid,
		submissionperiod
		) 

--SELECT * FROM MemberCountTotals




SELECT 
v.CS_Reference_number,
		v.CSid,
		v.submissionperiod,
		ISNULL(mt.MemberCount,0) as MemberCount from
		variables v
		LEFT JOIN MemberCountTotals mt
		ON v.CS_Reference_number = mt.CS_Reference_number
		AND v.CSid = mt.CSid
		AND v.submissionperiod = mt.submissionperiod;


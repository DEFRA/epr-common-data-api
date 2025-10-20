﻿IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[v_ProducerPaycalParameters_resub]')
) DROP VIEW [dbo].[v_ProducerPaycalParameters_resub];

GO

CREATE VIEW [dbo].[v_ProducerPaycalParameters_resub] AS 
	WITH OrganisationDetailsCTE AS (
        SELECT 
            cfm.OrganisationId as OrganisationExternalId
			,cd.Organisation_Id AS OrganisationId
			,cfm.ComplianceSchemeId
			,cd.FileName
			,cfm.FileId
			,cfm.RegistrationSetId
            ,CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace
            ,CASE
				UPPER(organisation_size)
				WHEN 'L' THEN 'large'
				WHEN 'S' THEN 'small'
				ELSE organisation_size
			 END AS ProducerSize
            ,cd.Organisation_Size AS OrganisationSize
			,CASE UPPER(cd.home_nation_code)
                WHEN 'EN' THEN 1
                WHEN 'NI' THEN 2
                WHEN 'SC' THEN 3
                WHEN 'WS' THEN 4
                WHEN 'WA' THEN 4
            END AS NationId
			,cd.leaver_date
			,cd.leaver_code
			,cd.organisation_change_reason
			,cd.joiner_date
			,cfm.submissionperiod
			,CAST('20'+reverse(substring(reverse(cfm.SubmissionPeriod),1,2)) AS INT) AS RelevantYear
			,CONVERT(DATETIME, Substring(cfm.[created], 1, 23)) SubmittedDateTime
			,CONVERT(DATETIME, Substring(se2.[created], 1, 23)) ApplicationSubmittedDateTime
			,CASE WHEN CAST('20'+reverse(substring(reverse(cfm.SubmissionPeriod),1,2)) AS INT) = 2025 THEN
				CASE 
					WHEN ISNULL(CONVERT(DATETIME, Substring(se2.[created], 1, 23)), 
						 CONVERT(DATETIME, Substring(cfm.[created], 1, 23))) > DATEFROMPARTS(CAST('20'+reverse(substring(reverse(cfm.SubmissionPeriod),1,2)) AS INT), 4, 1) THEN 1
					ELSE 0
				END
				ELSE 
				CASE 
					WHEN UPPER(TRIM(cd.organisation_size)) = 'L' AND
							ISNULL(CONVERT(DATETIME, Substring(se2.[created], 1, 23)), 
						 CONVERT(DATETIME, Substring(cfm.[created], 1, 23))) > DATEFROMPARTS(CAST('20'+reverse(substring(reverse(cfm.SubmissionPeriod),1,2)) AS INT) - 1, 10, 1) 
					THEN 1
					WHEN UPPER(TRIM(cd.organisation_size)) = 'S' AND 
							ISNULL(CONVERT(DATETIME, Substring(se2.[created], 1, 23)), 
						 CONVERT(DATETIME, Substring(cfm.[created], 1, 23))) >  DATEFROMPARTS(CAST('20'+reverse(substring(reverse(cfm.SubmissionPeriod),1,2)) AS INT), 4, 1) 
					THEN 1
					ELSE 0
				END 
				END as IsLateFeeApplicable
        FROM
            [rpd].[CompanyDetails] cd
			inner join rpd.cosmos_file_metadata cfm on cfm.FileName = cd.FileName
			LEFT JOIN rpd.SubmissionEvents se 
				LEFT JOIN rpd.SubmissionEvents se2 on se2.SubmissionId = se.SubmissionId and se2.Type = 'RegistrationApplicationSubmitted'
			on se.FileId = cfm.FileId and se.Type = 'Submitted'
        WHERE cd.Subsidiary_Id IS NULL
    )
	,SubsidiariesCTE AS (
		SELECT
		     cfm.organisationid as OrganisationExternalId
            ,cd.organisation_id as OrganisationId
			,cfm.ComplianceSchemeId
			,cd.FileName
            ,cfm.FileId
			,cfm.RegistrationSetId
			,CASE WHEN cd.Packaging_Activity_OM IN ('Primary', 'Secondary') THEN 1 ELSE 0 END AS IsOnlineMarketPlace
            ,CASE UPPER(organisation_size)
				WHEN 'L' THEN 'large'
				WHEN 'S' THEN 'small'
				ELSE organisation_size
			 END AS ProducerSize
			,cd.Organisation_Size AS OrganisationSize
			,CASE UPPER(cd.home_nation_code)
                WHEN 'EN' THEN 1
                WHEN 'NI' THEN 2
                WHEN 'SC' THEN 3
                WHEN 'WS' THEN 4
                WHEN 'WA' THEN 4
            END AS NationId
			,cd.leaver_date
			,cd.leaver_code
			,cd.organisation_change_reason
			,cd.joiner_date
			,cfm.submissionperiod
			,CAST('20'+reverse(substring(reverse(cfm.SubmissionPeriod),1,2)) AS INT) AS RelevantYear
			,cd.Subsidiary_Id AS SubsidiaryId
			,CONVERT(DATETIME, Substring(cfm.[created], 1, 23)) SubmittedDateTime
			,CONVERT(DATETIME, Substring(se2.[created], 1, 23)) ApplicationSubmittedDateTime
        FROM
            rpd.companydetails cd inner join rpd.cosmos_file_metadata cfm ON cfm.FileName = cd.FileName
			LEFT JOIN rpd.SubmissionEvents se 
				LEFT JOIN rpd.SubmissionEvents se2 ON se2.SubmissionId = se.SubmissionId and se2.Type = 'RegistrationApplicationSubmitted'
			ON se.FileId = cfm.FileId and se.Type = 'Submitted'
        WHERE cd.Subsidiary_Id IS NOT NULL
	)
	,EarliestSubsidiaryCTE AS (
		SELECT MIN(ISNULL(ApplicationSubmittedDateTime,SubmittedDateTime)) AS EarliestSubmissionDate, OrganisationId, ComplianceSchemeId, SubsidiaryId, FileId
		FROM SubsidiariesCTE GROUP BY organisationid, ComplianceSchemeId, SubsidiaryId, FileId
	)
	,SubsidiaryDetailsCTE AS (
	--Do the late fee calculation based on the joiner date and the earliest submission date
		select CASE WHEN RelevantYear = 2025 THEN
					CASE 
						WHEN e.EarliestSubmissionDate > DATEFROMPARTS(RelevantYear, 4, 1) THEN 1
						ELSE 0
					END
				  ELSE 
					CASE 
						WHEN UPPER(TRIM(s.organisationsize)) = 'L' AND
								e.EarliestSubmissionDate > DATEFROMPARTS(RelevantYear - 1, 10, 1) 
						THEN 1
						WHEN UPPER(TRIM(s.organisationsize)) = 'S' AND 
								e.EarliestSubmissionDate > DATEFROMPARTS(RelevantYear, 4, 1) 
						THEN 1
						ELSE 0
					END 
				 END as IsLateFeeApplicable
				,e.EarliestSubmissionDate
				,s.*
		FROM SubsidiariesCTE s LEFT JOIN EarliestSubsidiaryCTE e ON (s.SubsidiaryId = e.SubsidiaryId
			AND s.organisationid = e.organisationid AND s.FileId = e.FileId)
	)
	,SubsidiaryCountsCTE
    AS
    (
        SELECT
			cd.organisationid
			,cd.FileName
            ,COUNT(DISTINCT subsidiaryid) AS NumberOfSubsidiaries
            ,COUNT(CASE WHEN cd.IsOnlineMarketPlace = 1 THEN 1 END) AS OnlineMarketPlaceSubsidiaries
			,SUM(CASE WHEN cd.joiner_date IS NOT NULL THEN IsLateFeeApplicable ELSE 0 END) AS NumberOfLateSubsidiaries
        FROM
			SubsidiaryDetailsCTE cd
        WHERE cd.SubsidiaryId IS NOT NULL
        GROUP BY cd.organisationid, cd.FileName
    )
	,OrganisationPaycalDetailsCTE AS (
		SELECT 
		   OrganisationExternalId
		   ,od.OrganisationId
		   ,od.[FileName]
		   ,od.FileId
		   ,RegistrationSetId
		   ,CAST(od.IsOnlineMarketPlace AS BIT) AS IsOnlineMarketPlace
		   ,OrganisationSize
		   ,ProducerSize
		   ,NationId
		   ,ISNULL(NumberOfSubsidiaries,0) as NumberOfSubsidiaries
		   ,ISNULL(OnlineMarketPlaceSubsidiaries,0) as OnlineMarketPlaceSubsidiaries
		   ,ISNULL(NumberOfLateSubsidiaries,0) as NumberOfLateSubsidiaries
		FROM OrganisationDetailsCTE od
		left join SubsidiaryCountsCTE sc on sc.FileName = od.FileName AND od.OrganisationId = sc.organisationid
    )
SELECT
    *
FROM
    OrganisationPaycalDetailsCTE;
GO
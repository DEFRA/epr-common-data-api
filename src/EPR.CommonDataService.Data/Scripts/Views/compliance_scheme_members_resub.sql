IF EXISTS (
	SELECT 1
FROM sys.views
WHERE object_id = OBJECT_ID(N'[dbo].[v_ComplianceSchemeMembers_resub]')
) DROP VIEW [dbo].[v_ComplianceSchemeMembers_resub];
GO

/****** Object:  View [dbo].[v_ComplianceSchemeMembers_resub]    Script Date: 02/05/2025 10:20:04 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[v_ComplianceSchemeMembers_resub] AS WITH AllComplianceOrgFilesCTE
		as
		(
			SELECT distinct 
				c.[OrganisationId] as CSOExternalId
				,o.ReferenceNumber as CSOReference
				,CAST(SUBSTRING(c.SubmissionPeriod, PATINDEX('%[0-9][0-9][0-9][0-9]%', c.SubmissionPeriod), 4) AS INT) AS RelevantYear
				,c.submissionperiod
				,c.Created as SubmittedDate
				, c.ComplianceSchemeId
				,c.[FileName]
				,c.created
				,CONVERT(DATETIME, Substring(c.[created], 1, 23)) as SortBy --For a given Organisation, in a given submission period, finding the most recently accepted org file based on the submission date--
				,Row_Number() Over(
					Partition by
					c.ComplianceSchemeId,
					c.submissionperiod,
					c.organisationid
					order by CONVERT(DATETIME, Substring(c.[created], 1, 23)) desc
				) as RowNumber
			FROM rpd.organisations o
				INNER JOIN [rpd].[cosmos_file_metadata] c ON c.organisationid = o.externalid
					AND FileType = 'CompanyDetails'
			WHERE o.IsComplianceScheme = 1
		)
		,LatestUploadedFileCTE AS
		(
			SELECT * from AllComplianceOrgFilesCTE
			where RowNumber = 1
		)
		,All_MemberOrgsCTE
		as
		(
			SELECT DISTINCT 
				CSOExternalId as CSOExternalId
				,CSOReference
				,organisation_id as OrganisationReference
				,o.ExternalId as OrganisationId
				,o.Name
				,lcof.ComplianceSchemeId
				,submissionperiod
				,RelevantYear
				,SubmittedDate
				,CASE 
					WHEN SubmittedDate > DATEFROMPARTS(RelevantYear, 4, 1) THEN 1
					ELSE 0
				 END IsLateFeeApplicable
				,cd.leaver_code
				,cd.leaver_date
				,cd.joiner_date
				,cd.organisation_change_reason
				,lcof.FileName
				,Row_Number() over ( partition by 
												ComplianceSchemeId, 
												SubmissionPeriod, 
												organisation_id
									order by CONVERT(DATETIME, Substring(SubmittedDate, 1, 23)) asc
				) as RowNum
			from [rpd].[CompanyDetails] cd
				inner join AllComplianceOrgFilesCTE lcof on lcof.FileName = cd.FileName 
				inner join rpd.organisations o on o.ReferenceNumber = cd.organisation_id and cd.Subsidiary_id is null
		)
		,LatestMemberOrgsCTE 
		AS
		(
			SELECT DISTINCT 
				CSOExternalId as CSOExternalId
				,CSOReference
				,organisation_id as OrganisationReference
				,o.ExternalId as OrganisationId
				,o.Name
				,lcof.ComplianceSchemeId
				,submissionperiod
				,RelevantYear
				,SubmittedDate
				,CASE 
					WHEN SubmittedDate > DATEFROMPARTS(RelevantYear, 4, 1) THEN 1
					ELSE 0
				 END IsLateFeeApplicable
				,cd.leaver_code
				,cd.leaver_date
				,cd.joiner_date
				,cd.organisation_change_reason
				,lcof.FileName
				,Row_Number() over ( partition by 
												ComplianceSchemeId, 
												SubmissionPeriod, 
												organisation_id
									order by CONVERT(DATETIME, Substring(SubmittedDate, 1, 23)) asc
				) as RowNum
			from [rpd].[CompanyDetails] cd
				inner join LatestUploadedFileCTE lcof on lcof.FileName = cd.FileName 
				inner join rpd.organisations o on o.ReferenceNumber = cd.organisation_id and cd.Subsidiary_id is null
		)
		,LatestMemberOrgsWithAllDetailsCTE AS (
			SELECT
				lmo.CSOExternalId,
				lmo.CSOReference,
				lmo.OrganisationReference,
				lmo.OrganisationId,
				lmo.Name,
				lmo.ComplianceSchemeId,
				lmo.SubmissionPeriod,
				lmo.RelevantYear,
				amo.joiner_date as AllJoinerDate,
				-- Overriding with the first (earliest) submission date and its late fee flag
				COALESCE(amo.SubmittedDate, lmo.SubmittedDate) as SubmittedDate,
				COALESCE(amo.IsLateFeeApplicable, lmo.IsLateFeeApplicable) as IsLateFeeApplicable,
				COALESCE(NULLIF(amo.leaver_code,''), lmo.leaver_code) as leaver_code,
				COALESCE(amo.leaver_date, lmo.leaver_date) as leaver_date,
				COALESCE(NULLIF(amo.joiner_date,''), lmo.joiner_date) as joiner_date,
				COALESCE(amo.organisation_change_reason,lmo.organisation_change_reason) as organisation_change_reason,
				lmo.FileName as FileName,
				Row_Number() over ( partition by 
												lmo.ComplianceSchemeId, 
												lmo.SubmissionPeriod, 
												lmo.OrganisationReference
									order by CONVERT(DATETIME, Substring(lmo.SubmittedDate, 1, 23)) asc
				) as RowNum
			FROM LatestMemberOrgsCTE lmo
			LEFT JOIN All_MemberOrgsCTE amo
				ON lmo.OrganisationId = amo.OrganisationId
				AND lmo.ComplianceSchemeId = amo.ComplianceSchemeId
				AND lmo.SubmissionPeriod = amo.SubmissionPeriod
    	)
		SELECT u.CSOExternalId
		  ,u.CSOReference
		  ,u.ComplianceSchemeId
		  ,u.OrganisationReference as ReferenceNumber
		  ,u.OrganisationId as ExternalId
		  ,u.Name as OrganisationName
		  ,u.SubmissionPeriod
		  ,u.RelevantYear
		  ,u.SubmittedDate
		  ,u.IsLateFeeApplicable
		  ,u.leaver_code
		  ,u.leaver_date
		  ,u.joiner_date
		  ,u.organisation_change_reason
		  ,u.FileName
	from LatestMemberOrgsWithAllDetailsCTE u
		inner join rpd.organisations o on o.referencenumber = u.OrganisationReference
	where o.IsComplianceScheme = 0
	and u.RowNum = 1;
GO

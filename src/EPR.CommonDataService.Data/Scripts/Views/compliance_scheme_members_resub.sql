IF EXISTS (
	SELECT 1
FROM sys.views
WHERE object_id = OBJECT_ID(N'[dbo].[v_ComplianceSchemeMembers_resub]')
) DROP VIEW [dbo].[v_ComplianceSchemeMembers_resub];
GO

CREATE VIEW [dbo].[v_ComplianceSchemeMembers_resub] AS 
WITH AllComplianceOrgFilesCTE
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
				,c.FileId
				,c.RegistrationSetId
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
			WHERE c.ComplianceSchemeId is not null
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
				,lcof.FileId
				,lcof.RegistrationSetId
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
--select * from All_MemberOrgsCTE where ComplianceSchemeId = 'c7e1c823-998b-40a0-bf64-c9a94f8c4ebc'--'d1d1bfb5-75ae-4216-a5f5-f3811cbd923f'
		,All_MemberOrgsWithEarliestDateCTE AS (
			SELECT DISTINCT
				amo.CSOExternalId, 
				amo.CSOReference, 
				amo.OrganisationReference, 
				amo.OrganisationId, 
				amo.Name, 
				amo.ComplianceSchemeId, 
				amo.SubmissionPeriod, 
				amo.RelevantYear, 
				amo.SubmittedDate, 
				earliest.SubmittedDate AS EarliestSubmissionDate,
				amo.IsLateFeeApplicable, 
				amo.Leaver_Code, 
				amo.Leaver_Date, 
				amo.Joiner_Date, 
				amo.Organisation_Change_Reason, 
				amo.FileName, 
				amo.FileId, 
				amo.RegistrationSetId
			FROM All_MemberOrgsCTE amo
			CROSS APPLY (
				SELECT TOP 1 SubmittedDate
				FROM All_MemberOrgsCTE sub
				WHERE 
					sub.OrganisationId = amo.OrganisationId
					AND sub.ComplianceSchemeId = amo.ComplianceSchemeId
					AND sub.SubmissionPeriod = amo.SubmissionPeriod
				ORDER BY CONVERT(DATETIME, Substring(sub.SubmittedDate, 1, 23)) ASC
			) AS earliest
		)		
		,LatestMemberOrgsCTE 
		AS
		(
			SELECT DISTINCT 
				CSOExternalId as CSOExternalId
				,CSOReference
				,OrganisationReference
				,OrganisationId
				,Name
				,lcof.ComplianceSchemeId
				,submissionperiod
				,RelevantYear
				,SubmittedDate
				,EarliestSubmissionDate
				,CASE 
					WHEN EarliestSubmissionDate > DATEFROMPARTS(RelevantYear, 4, 1) THEN 1
					ELSE 0
				 END IsLateFeeApplicable
				,leaver_code
				,leaver_date
				,joiner_date
				,organisation_change_reason
				,FileName
				,FileId
				,RegistrationSetId
			from All_MemberOrgsWithEarliestDateCTE lcof
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
		  ,u.EarliestSubmissionDate
		  ,u.IsLateFeeApplicable
		  ,u.leaver_code
		  ,u.leaver_date
		  ,u.joiner_date
		  ,u.organisation_change_reason
		  ,u.FileName
		  ,u.FileId
	from LatestMemberOrgsCTE  u
		inner join rpd.organisations o on o.referencenumber = u.OrganisationReference
	where o.IsComplianceScheme = 0
GO
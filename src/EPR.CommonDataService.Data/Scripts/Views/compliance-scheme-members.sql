IF EXISTS (
	SELECT 1
FROM sys.views
WHERE object_id = OBJECT_ID(N'[dbo].[v_ComplianceSchemeMembers]')
) DROP VIEW [dbo].[v_ComplianceSchemeMembers];
GO

CREATE VIEW [dbo].[v_ComplianceSchemeMembers]
AS WITH
		AllComplianceOrgFilesCTE
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
					Partition by c.organisationid,
					c.submissionperiod,
					c.ComplianceSchemeId
					order by CONVERT(DATETIME, Substring(c.[created], 1, 23)) desc
				) as RowNumber
			FROM rpd.organisations o
				INNER JOIN [rpd].[cosmos_file_metadata] c ON c.organisationid = o.externalid
					AND FileType = 'CompanyDetails'
			WHERE o.IsComplianceScheme = 1
		)
		,Accepted_CSO_org_files
		AS
		(
			SELECT distinct 
				c.[OrganisationId] as ExternalId
				,o.[Id] as OrganisationId
				,c.[FileName]
				,c.[FileType]
				,c.SubmissionPeriod
				,c.created --For a given Organisation, in a given submission period, finding the most recently accepted Pom file based on the submission date--
				,Row_Number() Over(
				Partition by c.organisationid,
				c.submissionperiod
				order by CONVERT(DATETIME, Substring(c.[created], 1, 23)) desc
			) as RowNumber
			FROM rpd.organisations o
				INNER JOIN [rpd].[cosmos_file_metadata] c ON c.organisationid = o.externalid
				INNER JOIN [rpd].[submissionevents] se ON Trim(se.fileid) = Trim(c.fileid)
					AND se.[type] = 'RegulatorRegistrationDecision'
					AND se.decision = 'Accepted'
					AND Trim(c.filetype) = 'CompanyDetails'
		)
		,Latest_Accepted_CSO_Org_file
		as
		(
			-- we don't need accepted Files, our journey is for the Regulator to Accept or Reject the files
			--From the CTE retrieve the Filename of the identified file--
			SELECT DISTINCT Filename
				,FileType
				,submissionperiod
				,created
			FROM Accepted_CSO_org_files acof
			WHERE acof.RowNumber = 1
		)
		,Latest_CSO_Org_Files
		as
		(
			SELECT DISTINCT 
				CSOExternalId
				,CSOReference
				,ComplianceSchemeId
				,FileName
				,RelevantYear
				,SubmissionPeriod
				,created as SubmittedDate
			from AllComplianceOrgFilesCTE
			where RowNumber = 1
		) -- retrieve Organisations that are created with that Compliance Org File
		,Unaccepted_MemberOrgsCTE
		as
		(
			SELECT DISTINCT 
				CSOExternalId as CSOExternalId
				,CSOReference
				,organisation_id as OrganisationReference
				,o.ExternalId as OrganisationId
				,lcof.ComplianceSchemeId
				,submissionperiod
				,RelevantYear
				,SubmittedDate
				,CASE 
					WHEN SubmittedDate > DATEFROMPARTS(RelevantYear, 4, 1) THEN 1
					ELSE 0
				 END IsLateFeeApplicable
				,lcof.FileName
			from [rpd].[CompanyDetails] cd
				inner join Latest_CSO_Org_Files lcof on lcof.FileName = cd.FileName --inner join rpd.Organisations o on o.ReferenceNumber = cd.organisation_id
				inner join rpd.organisations o on o.ReferenceNumber = cd.organisation_id
		)
		,Accepted_MemberOrgsCTE
		as
		(
			SELECT DISTINCT organisation_id as OrganisationId
			from [rpd].[CompanyDetails] cd
				inner join Latest_Accepted_CSO_Org_file laofc on laofc.FileName = cd.FileName
				inner join [rpd].[Organisations] o on o.id = cd.organisation_id
					and o.IsComplianceScheme = 0
		)
	SELECT u.CSOExternalId
		  ,u.CSOReference
		  ,u.ComplianceSchemeId
		  ,u.OrganisationReference as ReferenceNumber
		  ,u.OrganisationId as ExternalId
		  ,u.SubmissionPeriod
		  ,u.RelevantYear
		  ,u.SubmittedDate
		  ,u.IsLateFeeApplicable
		  ,u.FileName
	from Unaccepted_MemberOrgsCTE u
		inner join rpd.organisations o on o.referencenumber = u.OrganisationReference
	where o.IsComplianceScheme = 0;
GO

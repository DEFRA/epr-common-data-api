IF EXISTS (
	SELECT 1
FROM sys.views
WHERE object_id = OBJECT_ID(N'[dbo].[v_ComplianceSchemeMembers_resub]')
) DROP VIEW [dbo].[v_ComplianceSchemeMembers_resub];
GO

CREATE VIEW [dbo].[v_ComplianceSchemeMembers_resub] AS with base_data as 
(
	select 
		c.[OrganisationId] as CSOExternalId
		,o.ReferenceNumber as CSOReference
		,cd.organisation_id as ReferenceNumber
		,p.ExternalId as OrganisationId
		,p.Name as OrganisationName
		,p.IsComplianceScheme
		,c.ComplianceSchemeId
		,c.submissionperiod
		,CAST('20'+reverse(substring(reverse(c.SubmissionPeriod),1,2)) AS INT) AS RelevantYear
		,c.Created as SubmittedDate
		,CONVERT(DATETIME, Substring(c.[created], 1, 23)) SubmittedDate_datetime
		,cd.leaver_code
		,cd.leaver_date
		,cd.joiner_date
		,cd.organisation_change_reason		
		,c.[FileName]
		,c.FileId
		,c.RegistrationSetId
	from [rpd].[cosmos_file_metadata] c
	inner join rpd.organisations o on c.organisationid = o.externalid
	inner join [rpd].[CompanyDetails] cd on c.FileName = cd.FileName 
	inner join rpd.organisations p on p.ReferenceNumber = cd.organisation_id and cd.Subsidiary_id is null
	where c.FileType = 'CompanyDetails'
	and o.IsComplianceScheme = 1
),
earliest_submission_by_cs_for_an_org_for_submissionperiod as 
(
	select OrganisationId, ComplianceSchemeId, SubmissionPeriod, min (SubmittedDate_datetime) as EarliestSubmissionDate
	from base_data
	group by OrganisationId, ComplianceSchemeId, SubmissionPeriod
),
base_data_with_latefee_and_earlySubmittedDate as
(
	select b.*
			,CASE WHEN RelevantYear = 2025 THEN
				CASE 
					WHEN e.EarliestSubmissionDate > DATEFROMPARTS(RelevantYear, 4, 1) THEN 1
					ELSE 0
				END
			  ELSE 
				CASE 
					WHEN e.EarliestSubmissionDate > DATEFROMPARTS(RelevantYear - 1, 10, 1) THEN 1
					ELSE 0
				END
			  END IsLateFeeApplicable
			, e.EarliestSubmissionDate
	from base_data b
	left join earliest_submission_by_cs_for_an_org_for_submissionperiod e
		on b.OrganisationId = e.OrganisationId
			and b.ComplianceSchemeId = e.ComplianceSchemeId
			and b.SubmissionPeriod = e.SubmissionPeriod
)
select distinct
	CSOExternalId,	CSOReference,	ComplianceSchemeId,	
	ReferenceNumber,	OrganisationId as ExternalId,	OrganisationName,	SubmissionPeriod,	RelevantYear,	SubmittedDate,	
	CONVERT(varchar, EarliestSubmissionDate, 126) as EarliestSubmissionDate,
	IsLateFeeApplicable,	leaver_code,	leaver_date,	joiner_date,	organisation_change_reason,	FileName,	FileId
From base_data_with_latefee_and_earlySubmittedDate 
where IsComplianceScheme = 0;
GO

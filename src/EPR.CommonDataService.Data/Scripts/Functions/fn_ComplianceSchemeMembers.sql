IF EXISTS (SELECT 1 FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'[dbo].[fn_ComplianceSchemeMembers]'))
    DROP FUNCTION [dbo].[fn_ComplianceSchemeMembers];
GO

CREATE FUNCTION [dbo].[fn_ComplianceSchemeMembers] (@OrganisationUUID [nvarchar](40),@SubmissionPeriod [nvarchar](25),@ComplianceSchemeId [nvarchar](40)) RETURNS TABLE
AS
RETURN (	   
	WITH AllComplianceOrgFilesCTE
		as
		(
			SELECT distinct 
				c.[OrganisationId] as CSOExternalId
				,o.ReferenceNumber as CSOReference
                ,o.Name as CSOOrgName
                ,CONVERT(int, RIGHT(RTRIM(c.SubmissionPeriod), 4)) AS RelevantYear
				,c.submissionperiod
				, c.ComplianceSchemeId
				,c.Created as SubmittedDate
				,c.RegistrationSetId
				,c.FileId
				,c.[FileName]
			FROM [rpd].[cosmos_file_metadata] c 
				INNER JOIN rpd.organisations o ON c.organisationid = o.externalid
                AND FileType = 'CompanyDetails'
			AND (@OrganisationUUID IS NULL OR c.OrganisationId = @OrganisationUUID)
            AND 
                (@SubmissionPeriod IS NULL OR c.SubmissionPeriod = @SubmissionPeriod)
            AND 
                (@ComplianceSchemeId IS NULL OR c.ComplianceSchemeId = @ComplianceSchemeId)
        )
    ,All_MemberOrgsCTE
    as
    (
        SELECT DISTINCT 
            CSOExternalId as CSOExternalId
            ,CSOReference
            ,CSOOrgName
            ,lcof.ComplianceSchemeId
            ,lcof.FileName
            ,lcof.FileId
            ,lcof.RegistrationSetId
            ,lcof.SubmittedDate as SubmittedOn
            ,CASE WHEN cd.FileName IS NULL THEN 1 ELSE 0 END AS IsDetailMissing
            ,o.Name as MemberName
            ,organisation_id as OrganisationReference
            ,o.ExternalId as OrganisationId
            ,submissionperiod
            ,RelevantYear
            ,SubmittedDate
            ,CONVERT(datetime, SUBSTRING(SubmittedDate,1,23)) AS SubmittedDate_dt
            ,CASE 
                WHEN SubmittedDate > DATEFROMPARTS(RelevantYear, 4, 1) THEN 1
                ELSE 0
            END IsLateFeeApplicable
            ,cd.organisation_size
            ,cd.leaver_code
            ,cd.leaver_date
            ,cd.joiner_date
            ,cd.organisation_change_reason
        from AllComplianceOrgFilesCTE lcof
            left join [rpd].[CompanyDetails] cd on lcof.FileName = cd.FileName  and cd.Subsidiary_id is null 
            LEFT join rpd.organisations o on o.ReferenceNumber = cd.organisation_id
    )
    ,EarliestDatesCTE AS
    (
        SELECT
        OrganisationId,
        ComplianceSchemeId,
        SubmissionPeriod,
        MIN(SubmittedDate_dt) AS EarliestSubmissionDate
        FROM All_MemberOrgsCTE
        where IsDetailMissing = 0
        GROUP BY
        OrganisationId,
        ComplianceSchemeId,
        SubmissionPeriod
    )		
    ,All_MemberOrgsWithEarliestDateCTE AS
    (
        SELECT
        amo.CSOExternalId, 
        amo.CSOReference,
        amo.CSOOrgName, 
        amo.ComplianceSchemeId, 
        amo.SubmissionPeriod, 
        amo.RelevantYear, 
        amo.FileName, 
        amo.FileId, 
        amo.RegistrationSetId,
        amo.MemberName, 
        amo.OrganisationReference, 
        amo.OrganisationId, 
        amo.SubmittedDate AS SubmittedDate,
        ed.EarliestSubmissionDate,
        DATEFROMPARTS(
            RelevantYear,
            4,
            1
        ) AS LateFeeCutoffDate,
        amo.organisation_size,
        amo.Leaver_Code, 
        amo.Leaver_Date, 
        amo.Joiner_Date, 
        amo.Organisation_Change_Reason 
        FROM All_MemberOrgsCTE amo
        INNER JOIN EarliestDatesCTE ed
        ON amo.OrganisationId      = ed.OrganisationId
        AND amo.ComplianceSchemeId  = ed.ComplianceSchemeId
        AND amo.SubmissionPeriod    = ed.SubmissionPeriod
    )
    ,LatestMemberOrgsCTE 
    AS
    (
        SELECT DISTINCT 
            CSOExternalId as CSOExternalId
            ,CSOReference
            ,CSOOrgName
            ,submissionperiod
            ,ComplianceSchemeId
            ,RelevantYear
            ,FileName
            ,FileId
            ,RegistrationSetId
            ,MemberName
            ,OrganisationReference
            ,OrganisationId
            ,SubmittedDate
            ,EarliestSubmissionDate
            ,LateFeeCutoffDate
            ,CASE 
                WHEN EarliestSubmissionDate > LateFeeCutoffDate 
                THEN 1 
                ELSE 0 
            END AS IsLateSubmission            
            ,organisation_size
            ,leaver_code
            ,leaver_date
            ,joiner_date
            ,organisation_change_reason
        from All_MemberOrgsWithEarliestDateCTE lcof
    )
	SELECT u.CSOOrgName
        ,u.CSOReference
        ,u.CSOExternalId
		,u.SubmissionPeriod	  
		,u.ComplianceSchemeId
		,u.RelevantYear
		,u.FileName
		,u.FileId
        ,u.RegistrationSetId
		,u.MemberName as MemberName
		,u.OrganisationReference as ReferenceNumber
		,u.OrganisationId as ExternalId
		,u.SubmittedDate
		,u.EarliestSubmissionDate
        ,u.LateFeeCutoffDate
        ,u.IsLateSubmission
		,u.organisation_size
        ,u.leaver_code
		,u.leaver_date
		,u.joiner_date
		,u.organisation_change_reason
	from LatestMemberOrgsCTE  u
)
GO

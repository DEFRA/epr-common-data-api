IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub]')
) DROP VIEW [dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub];

GO

CREATE VIEW [dbo].[v_UploadedRegistrationDataBySubmissionPeriod_resub] AS WITH
    LatestUploadedData
    AS
    (
        SELECT
            z.*
        FROM
            (
		SELECT
			o.Name as UploadingOrgName
            ,cfm.organisationid AS UploadingOrgExternalId
			,ComplianceSchemeId
			,submissionperiod
			,RegistrationSetId
			,Created as UploadDate
			,row_number() OVER (partition BY organisationid, SubmissionPeriod, ComplianceSchemeId ORDER BY created DESC) AS UploadSequence
            FROM
                rpd.cosmos_file_metadata cfm
				inner join rpd.Organisations o on o.ExternalId = cfm.organisationid
            WHERE SubmissionType = 'Registration'
			AND SubmissionPeriod like 'January to D%'
		) AS z
    )
    ,CompanyDetails
    AS
    (
        SELECT
		lud.UploadDate
		,lud.UploadSequence
		,lud.UploadingOrgName
        ,lud.UploadingOrgExternalId
		,lud.SubmissionPeriod
		,lud.ComplianceSchemeId
		,CASE WHEN lud.ComplianceSchemeId IS NULL THEN 0 ELSE 1 END AS IsComplianceUpload
		,cfm.complianceschemeid as cfm_csid
		,lud.RegistrationSetId
		,cd.organisation_id AS SubmittedReferenceNumber
		,ISNULL(cd.subsidiary_id,'') AS CompanySubRef
		,cd.organisation_name AS UploadOrgName
		,TRIM(cd.home_nation_code) as NationCode
		,cd.companies_house_number
		,cd.packaging_activity_om
		,cd.registration_type_code
		,UPPER(cd.organisation_size) AS OrganisationSize
		,CASE WHEN cfm.complianceschemeid IS NOT NULL THEN 1 ELSE 0 END AS IsComplianceScheme
		,cd.FileName AS CompanyFileName
		,isnull(trim(cd.leaver_code),'') as leaver_code,
		cd.leaver_date,
		cd.Organisation_change_reason,
		cd.joiner_date
		,cfm.RegistrationSetId AS CompanySetId
		,cfm.FileId AS CompanyFileId
		,cfm.Blobname AS CompanyBlobname
		,cfm.OriginalFileName AS CompanyUploadFileName
        FROM
            LatestUploadedData lud
            INNER JOIN rpd.cosmos_file_metadata cfm ON cfm.registrationsetid = lud.registrationsetid AND UPPER(cfm.FileType) = 'COMPANYDETAILS'
            INNER JOIN rpd.companydetails cd ON cfm.filename = cd.filename
        WHERE ISNULL(cd.subsidiary_id,'') = ''
    )
    ,PartnerFileDetails
    AS
    (
        SELECT
            DISTINCT
            lud.RegistrationSetId AS PartnerSetId
			,cfm.FileId AS PartnerFileId
			,cfm.FileName AS PartnerFileName
			,cfm.Blobname AS PartnerBlobname
			,cfm.OriginalFileName AS PartnerUploadFileName
        FROM
            LatestUploadedData lud
            INNER JOIN rpd.cosmos_file_metadata cfm ON cfm.registrationsetid = lud.registrationsetid AND UPPER(cfm.FileType) = 'PARTNERSHIPS'
    )
    ,BrandFileDetails
    AS
    (
        SELECT
            DISTINCT
            lud.RegistrationSetId AS BrandSetId
			,cfm.FileId AS BrandFileId
			,cfm.FileName AS BrandFileName
			,cfm.Blobname AS BrandBlobname
			,cfm.OriginalFileName AS BrandUploadFileName
        FROM
            LatestUploadedData lud
            INNER JOIN rpd.cosmos_file_metadata cfm ON cfm.registrationsetid = lud.registrationsetid AND UPPER(cfm.FileType) = 'BRANDS'
    )
    ,CompanyAndFileDetails
    AS
    (
        SELECT
            cd.UploadDate
			,cd.UploadSequence
			,cd.UploadingOrgName
            ,cd.UploadingOrgExternalId
			,cd.SubmissionPeriod
            ,cd.ComplianceSchemeId
			,cd.IsComplianceUpload
			,cd.RegistrationSetId
			,SubmittedReferenceNumber
            ,UploadOrgName
			,cd.NationCode
            ,Packaging_activity_om
            ,OrganisationSize
            ,IsComplianceScheme
			,CompanySetId
            ,CompanyFileName
            ,CompanyFileId
            ,CompanyBlobName
            ,CompanyUploadFileName
			,PartnerSetId
            ,PartnerFileName
            ,PartnerFileId
            ,PartnerBlobName
            ,PartnerUploadFileName
			,BrandSetId
            ,BrandFileName
            ,BrandFileId
            ,BrandBlobName
            ,BrandUploadFileName
        FROM
            CompanyDetails cd
            LEFT JOIN PartnerfileDetails pd ON pd.partnersetid = cd.companysetid
            LEFT JOIN Brandfiledetails bd ON bd.brandsetid = cd.companysetid
    )
SELECT
    *
FROM
    companyandfiledetails;
GO

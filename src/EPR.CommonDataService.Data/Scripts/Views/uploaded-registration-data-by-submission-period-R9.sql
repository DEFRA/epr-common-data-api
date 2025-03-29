IF EXISTS (
    SELECT 1
    FROM sys.views
    WHERE object_id = OBJECT_ID(N'[dbo].[v_UploadedRegistrationDataBySubmissionPeriod_R9]')
) DROP VIEW [dbo].[v_UploadedRegistrationDataBySubmissionPeriod_R9];

GO

CREATE VIEW [dbo].[v_UploadedRegistrationDataBySubmissionPeriod_R9] 
AS 
WITH
    LatestUploadedData
    AS
    (
        SELECT
            z.*
        FROM
            (
		SELECT
             organisationid AS ExternalId
			,SubmissionId
			,submissionperiod
			,RegistrationSetId
			,ComplianceSchemeId
			,CONVERT( BIT, CASE WHEN ComplianceSchemeId IS NULL THEN 0 ELSE 1 END) as IsComplianceUpload
			,Created
			,STRING_AGG(FileType, ',') AS FileTypes
			,row_number() OVER (partition BY organisationid, SubmissionPeriod, ComplianceSchemeId ORDER BY created DESC) AS RowNum
            FROM
                rpd.cosmos_file_metadata
            WHERE SubmissionType = 'Registration'
			AND SubmissionPeriod like 'January to D%'
            GROUP BY organisationid, submissionperiod, registrationsetid, submissionid, complianceschemeid, created
		) AS z
        --WHERE z.RowNum = 1
    )
,CompanyDetails
    AS
    (
        SELECT
         cfm.organisationid AS SubmittingExternalId
		,cd.organisation_id AS SubmittedReferenceNumber
		,ISNULL(cd.subsidiary_id,'') AS CompanySubRef
		,cd.organisation_name AS UploadOrgName
		,lud.SubmissionId
		,lud.SubmissionPeriod
		,TRIM(cd.home_nation_code) as NationCode
		,cd.companies_house_number
		,cd.packaging_activity_om
		,cd.registration_type_code
		,UPPER(cd.organisation_size) AS OrganisationSize
		,cfm.complianceschemeid
		,lud.complianceschemeid as csi
		,lud.IsComplianceUpload as icd
		,CASE WHEN cfm.complianceschemeid IS NOT NULL THEN 1 ELSE 0 END AS IsComplianceScheme
		,cd.FileName AS CompanyFileName
		,cfm.RegistrationSetId AS CompanySetId
		,cfm.FileId AS CompanyFileId
		,cfm.Blobname AS CompanyBlobname
		,cfm.OriginalFileName AS CompanyUploadFileName
        ,lud.Created
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
			,lud.ExternalId
			,lud.SubmissionPeriod
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
			,lud.ExternalId AS BrandExternalId
			,lud.SubmissionPeriod AS BrandSubmissionPeriod
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
            cd.SubmittingExternalId
            ,SubmittedReferenceNumber
            ,UploadOrgName
			,cd.SubmissionId
			,cd.SubmissionPeriod
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
            ,cd.Created
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
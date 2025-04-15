IF EXISTS (SELECT 1 FROM sys.sql_modules WHERE object_id = OBJECT_ID(N'[dbo].[fn_GetUploadedOrganisationDetails_resub]'))
    DROP FUNCTION [dbo].[fn_GetUploadedOrganisationDetails_resub];
GO

CREATE FUNCTION [dbo].[fn_GetUploadedOrganisationDetails_resub] (@OrganisationUUID [nvarchar](40),@SubmissionPeriod [nvarchar](25)) RETURNS TABLE
AS
RETURN (	   

WITH
    LatestUploadedData
    AS
    (
        SELECT
            z.*
        FROM
            (
			SELECT
				o.Name as UploadingOrganisationName
				,organisationid AS SubmittingExternalId
				,submissionperiod
				,ComplianceSchemeId
				,RegistrationSetId
				,Created
				,row_number() OVER (partition BY organisationid, ComplianceSchemeId, SubmissionPeriod ORDER BY created DESC) AS RowNum
			FROM
				rpd.cosmos_file_metadata cfm
				inner join rpd.Organisations o on o.externalid = cfm.organisationid
			WHERE SubmissionType = 'Registration'
				AND (ISNULL(@SubmissionPeriod,'') = '' OR SubmissionPeriod = @SubmissionPeriod)
				AND (ISNULL(@OrganisationUUID,'') = '' OR organisationid = @OrganisationUUID)
		) AS z
        WHERE z.RowNum = 1
    )
,CompanyDetails
    AS
    (
        SELECT
			lud.UploadingOrganisationName
			,lud.SubmittingExternalId
			,lud.SubmissionPeriod
			,lud.complianceschemeid
			,CASE WHEN lud.complianceschemeid IS NOT NULL THEN 1 ELSE 0 END AS IsComplianceScheme
			,lud.RegistrationSetId
			,cd.organisation_id AS UploadedReferenceNumber
			,ISNULL(cd.subsidiary_id,'') AS CompanySubRef
			,cd.organisation_name AS UploadOrgName
			,TRIM(cd.home_nation_code) AS NationCode
			,cd.companies_house_number
			,cd.packaging_activity_om
			,cd.registration_type_code
			,UPPER(cd.organisation_size) AS OrganisationSize
			,cd.FileName AS CompanyFileName
			,cfm.RegistrationSetId AS CompanySetId
			,cfm.FileId AS CompanyFileId
			,cfm.Blobname AS CompanyBlobname
			,cfm.OriginalFileName AS CompanyUploadFileName
        FROM
            LatestUploadedData lud
            INNER JOIN rpd.cosmos_file_metadata cfm ON cfm.registrationsetid = lud.registrationsetid
			AND UPPER(cfm.FileType) = 'COMPANYDETAILS'
            INNER JOIN rpd.companydetails cd ON cfm.filename = cd.filename
        WHERE ISNULL(cd.subsidiary_id,'') = ''
    )
,PartnerFileDetails
    AS
    (
        SELECT
            DISTINCT
			cfm.RegistrationSetId as PartnerSetId
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
			cfm.RegistrationSetId as BrandSetId
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
            cd.UploadingOrganisationName
			,cd.SubmittingExternalId
			,cd.complianceschemeid
			,cd.SubmissionPeriod
			,cd.isComplianceScheme
			,cd.RegistrationSetId
			,cd.UploadedReferenceNumber
			,cd.NationCode
            ,Packaging_activity_om
            ,organisationsize
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
    companyandfiledetails
)
GO
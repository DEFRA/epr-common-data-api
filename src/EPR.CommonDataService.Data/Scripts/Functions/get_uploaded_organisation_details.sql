IF EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[fn_GetUploadedOrganisationDetails]'))
DROP FUNCTION [dbo].[fn_GetUploadedOrganisationDetails];
GO
CREATE FUNCTION dbo.fn_GetUploadedOrganisationDetails(@OrganisationUUID nvarchar(40), @SubmissionPeriod nvarchar(25))
RETURNS TABLE
AS
--declare @@OrganisationUUID nvarchar(50);
--declare @submissionperiod nvarchar(50);
--select * from rpd.organisations where referencenumber = '105741'
--set @@OrganisationUUID = '6AAF64E3-A6E8-4920-BD5B-BEE6CA320C4C';
--set @@OrganisationUUID = '6d895205-3638-4848-87eb-c55e7495f344';
--set @submissionperiod = 'January to December 2024';
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
                organisationid AS SubmittingExternalId
			,submissionperiod
			,RegistrationSetId
			,Created
			,STRING_AGG(FileType, ',') AS FileTypes
			,row_number() OVER (partition BY organisationid, SubmissionPeriod ORDER BY created DESC) AS RowNum
            FROM
                rpd.cosmos_file_metadata
            WHERE SubmissionType = 'Registration'
                AND (ISNULL(@SubmissionPeriod,'') = '' OR SubmissionPeriod = @SubmissionPeriod)
                AND (ISNULL(@OrganisationUUID,'') = '' OR organisationid = @OrganisationUUID)
            GROUP BY organisationid, submissionperiod, registrationsetid, created
		) AS z
        WHERE z.RowNum = 1
    )
--select * from LatestUploadedData order by ExternalId
,CompanyDetails
    AS
    (
        SELECT
            lud.SubmittingExternalId
		,cd.organisation_id AS ReferenceNumber
		,ISNULL(cd.subsidiary_id,'') AS CompanySubRef
		,cd.organisation_name AS UploadOrgName
		,lud.SubmissionPeriod
		,TRIM(cd.home_nation_code) AS NationCode
		,cd.companies_house_number
		,cd.packaging_activity_om
		,cd.registration_type_code
		,UPPER(cd.organisation_size) AS OrganisationSize
		,cfm.complianceschemeid
		,CASE WHEN cfm.complianceschemeid IS NOT NULL THEN 1 ELSE 0 END AS IsComplianceScheme
		,cd.FileName AS CompanyFileName
		,cfm.RegistrationSetId AS CompanySetId
		,cfm.FileId AS CompanyFileId
		,cfm.Blobname AS CompanyBlobname
		,cfm.OriginalFileName AS CompanyUploadFileName
        FROM
            LatestUploadedData lud
            INNER JOIN rpd.cosmos_file_metadata cfm ON cfm.registrationsetid = lud.registrationsetid AND UPPER(cfm.FileType) = 'COMPANYDETAILS'
            INNER JOIN rpd.companydetails cd ON cfm.filename = cd.filename
                AND (ISNULL(@OrganisationUUID,'') = '' OR cfm.organisationid = @OrganisationUUID )
                AND (ISNULL(@SubmissionPeriod,'') = '' OR lud.SubmissionPeriod = @SubmissionPeriod)
        WHERE ISNULL(cd.subsidiary_id,'') = ''
    )
--select * from CompanyDetails
,PartnerFileDetails
    AS
    (
        SELECT
            DISTINCT
            lud.RegistrationSetId AS PartnerSetId
			,lud.SubmittingExternalId
			,lud.SubmissionPeriod
			,cfm.FileId AS PartnerFileId
			,cfm.FileName AS PartnerFileName
			,cfm.Blobname AS PartnerBlobname
			,cfm.OriginalFileName AS PartnerUploadFileName
        FROM
            LatestUploadedData lud
            INNER JOIN rpd.cosmos_file_metadata cfm ON cfm.registrationsetid = lud.registrationsetid AND UPPER(cfm.FileType) = 'PARTNERSHIPS'
                AND (ISNULL(@OrganisationUUID,'') = '' OR cfm.organisationid = @OrganisationUUID )
    )
--select * from partnerfiledetails order by externalid
,BrandFileDetails
    AS
    (
        SELECT
            DISTINCT
            lud.RegistrationSetId AS BrandSetId
			,lud.SubmittingExternalId AS BrandExternalId
			,lud.SubmissionPeriod AS BrandSubmissionPeriod
			,cfm.FileId AS BrandFileId
			,cfm.FileName AS BrandFileName
			,cfm.Blobname AS BrandBlobname
			,cfm.OriginalFileName AS BrandUploadFileName
        FROM
            LatestUploadedData lud
            INNER JOIN rpd.cosmos_file_metadata cfm ON cfm.registrationsetid = lud.registrationsetid AND UPPER(cfm.FileType) = 'PARTNERSHIPS'
                AND (ISNULL(@OrganisationUUID,'') = '' OR cfm.organisationid = @OrganisationUUID )
    )
--select * from brandfiledetails order by externalid
,CompanyAndFileDetails
    AS
    (
        SELECT
            cd.SubmittingExternalId
            ,ReferenceNumber
			,cd.SubmissionPeriod
			,cd.NationCode
            ,UploadOrgName
            ,Packaging_activity_om
            ,organisationsize
            ,isComplianceScheme
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
);

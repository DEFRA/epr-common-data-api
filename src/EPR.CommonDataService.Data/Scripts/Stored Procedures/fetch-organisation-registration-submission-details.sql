IF EXISTS (SELECT
    1
FROM
    sys.procedures
WHERE object_id = OBJECT_ID(N'[dbo].[sp_FetchOrganisationRegistrationSubmissionDetails]'))
DROP PROCEDURE [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails];
GO

CREATE PROC [dbo].[sp_FetchOrganisationRegistrationSubmissionDetails]
    @SubmissionId UNIQUEIDENTIFIER
AS
BEGIN
SET NOCOUNT ON;
 
    DECLARE @OrganisationIDForSubmission INT;
    DECLARE @OrganisationUUIDForSubmission UNIQUEIDENTIFIER;
    DECLARE @SubmissionPeriod nvarchar(4000);
    DECLARE @CSOReferenceNumber nvarchar(4000);
    DECLARE @ApplicationReferenceNumber nvarchar(4000);
    DECLARE @IsComplianceScheme bit;
    -- Fetch global IDs for the submission
    SELECT
        @OrganisationIDForSubmission = O.Id -- the int id of the organisation

    ,@OrganisationUUIDForSubmission = O.ExternalId -- the uuid of the organisation

    ,@CSOReferenceNumber = O.ReferenceNumber -- the reference number of the organisation

    ,@IsComplianceScheme = O.IsComplianceScheme -- whether the org is a compliance scheme

    ,@SubmissionPeriod = S.SubmissionPeriod -- the submission period of the submissions

    ,@ApplicationReferenceNumber = S.AppReferenceNumber
    -- the AppRef number of the submission
    FROM
        [rpd].[Submissions] AS S
        INNER JOIN [rpd].[Organisations] O ON S.OrganisationId = O.ExternalId
    WHERE S.SubmissionId = @SubmissionId;
    WITH
        -- basic OrganisationInformation
        SubmissionSummary
        AS
        (
            SELECT DISTINCT
                submission.SubmissionId
            ,submission.OrganisationId
            ,submission.OrganisationName
            ,submission.OrganisationReferenceNumber
            ,submission.IsComplianceScheme
            ,submission.ProducerSize
            ,CASE
				WHEN submission.IsComplianceScheme = 1 THEN 'compliance'
				ELSE submission.ProducerSize
			END AS OrganisationType
            ,submission.RelevantYear
            ,submission.IsLateSubmission
            ,submission.SubmittedDateTime
            ,submission.SubmissionStatus
            ,submission.SubmissionPeriod
            ,submission.StatusPendingDate
            ,submission.ApplicationReferenceNumber
            ,RegistrationReferenceNumber
            ,submission.NationId
            ,submission.NationCode
            ,submission.RegulatorUserId
            ,submission.SubmittedUserId
            ,submission.RegulatorDecisionDate
            ,submission.ProducerCommentDate
            ,submission.ProducerSubmissionEventId
            ,submission.RegulatorSubmissionEventId
            FROM
                [dbo].[v_OrganisationRegistrationSummaries] AS submission
            WHERE submission.SubmissionId = @SubmissionId
        ) -- the paycal parameterisation for the organisation itself

    ,ProducerPaycalParametersCTE
        AS
        (
            SELECT
                ExternalId
            ,ProducerSize
            ,IsOnlineMarketplace
            ,NumberOfSubsidiaries
            ,NumberOfSubsidiariesBeingOnlineMarketPlace
            FROM
                [dbo].[v_ProducerPaycalParameters] AS ppp
            WHERE ppp.ExternalId = @OrganisationUUIDForSubmission
        )
    ,SubmissionOrganisationDetails
        AS
        (
            SELECT
                DISTINCT
                submission.SubmissionId
            ,submission.OrganisationId
            ,submission.OrganisationName
            ,submission.OrganisationReferenceNumber
            ,submission.IsComplianceScheme
            ,submission.ProducerSize
            ,submission.ProducerSize AS OrganisationType
            ,submission.RelevantYear
            ,submission.SubmittedDateTime
            ,submission.IsLateSubmission
            ,submission.SubmissionPeriod
            ,submission.SubmissionStatus
            ,submission.StatusPendingDate
            ,submission.ApplicationReferenceNumber
            ,RegistrationReferenceNumber
            ,submission.NationId
            ,submission.NationCode
            ,submission.RegulatorUserId
            ,submission.SubmittedUserId
            ,submission.RegulatorDecisionDate
            ,submission.ProducerCommentDate
            ,submission.ProducerSubmissionEventId
            ,submission.RegulatorSubmissionEventId
            ,CONVERT(bit, ISNULL(ppp.IsOnlineMarketplace, 0)) AS IsOnlineMarketplace
            ,ISNULL(ppp.NumberOfSubsidiaries, 0) AS NumberOfSubsidiaries
            ,ISNULL(
            ppp.NumberOfSubsidiariesBeingOnlineMarketPlace,
            0
        ) AS NumberOfSubsidiariesBeingOnlineMarketPlace
            FROM
                SubmissionSummary AS submission
                LEFT JOIN ProducerPaycalParametersCTE ppp ON ppp.ExternalId = submission.OrganisationId
        )
    ,LatestProducerCommentEventsCTE
        AS
        (
            SELECT
                DISTINCT
                decision.SubmissionId
            ,Comments AS ProducerComment
            ,Created AS ProducerCommentDate
            FROM
                [apps].[SubmissionEvents] AS decision
                INNER JOIN SubmissionOrganisationDetails submittedregistrations ON decision.SubmissionEventId = submittedregistrations.ProducerSubmissionEventId
        )
    ,LatestRegulatorCommentCTE
        AS
        (
            SELECT
                DISTINCT
                decision.SubmissionId
            ,Comments AS RegulatorComment
            ,Created AS RegulatorCommentDate
            FROM
                [apps].[SubmissionEvents] AS decision
                INNER JOIN SubmissionOrganisationDetails submittedregistrations ON decision.SubmissionEventId = submittedregistrations.RegulatorSubmissionEventId
        )
    ,SubmissionOrganisationCommentsDetailsCTE
        AS
        (
            SELECT DISTINCT 
                submission.SubmissionId
            ,submission.OrganisationId
            ,submission.OrganisationName
            ,submission.OrganisationReferenceNumber
            ,submission.IsComplianceScheme
            ,submission.ProducerSize
            ,CASE
				WHEN submission.IsComplianceScheme = 1 THEN 'compliance'
				ELSE submission.ProducerSize
			END AS OrganisationType
            ,submission.RelevantYear
            ,submission.SubmittedDateTime
            ,submission.IsLateSubmission
            ,submission.SubmissionPeriod
            ,submission.SubmissionStatus
            ,submission.StatusPendingDate
            ,submission.ApplicationReferenceNumber
            ,submission.RegistrationReferenceNumber
            ,submission.NationId
            ,submission.NationCode
            ,submission.RegulatorUserId
            ,submission.SubmittedUserId
            ,decision.RegulatorCommentDate AS RegulatorDecisionDate
            ,decision.RegulatorComment
            ,producer.ProducerComment
            ,submission.ProducerCommentDate
            ,submission.IsOnlineMarketplace
            ,submission.NumberOfSubsidiaries
            ,submission.NumberOfSubsidiariesBeingOnlineMarketPlace
            ,submission.ProducerSubmissionEventId
            ,submission.RegulatorSubmissionEventId
            FROM
                SubmissionOrganisationDetails submission
                LEFT JOIN LatestRegulatorCommentCTE decision ON decision.SubmissionId = submission.SubmissionId
                LEFT JOIN LatestProducerCommentEventsCTE producer ON producer.SubmissionId = submission.SubmissionId
        ) --select * from SubmissionOrganisationCommentsDetailsCTE ;

    ,AllOrganisationFiles
        AS
        (
            SELECT
                FileId
            ,BlobName
            ,FileType
            ,FileName
            ,TargetDirectoryName
            ,RegistrationSetId
            ,ExternalId
            ,SubmissionType
            ,created
            FROM
                (
            SELECT
                    FileId
                ,BlobName
                ,FileType
                ,OriginalFileName AS FileName
                ,TargetDirectoryName
                ,RegistrationSetId
                ,OrganisationId AS ExternalId
                ,SubmissionType
                ,created
                ,ROW_NUMBER() OVER (
                    PARTITION BY organisationid,
                    filetype
                    ORDER BY created DESC
                ) AS row_num
                FROM
                    [rpd].[cosmos_file_metadata]
                WHERE FileType IN ('Partnerships', 'Brands', 'CompanyDetails')
                    AND IsSubmitted = 1
                    AND SubmissionType = 'Registration'
        ) AS a
            WHERE a.row_num = 1
                AND ExternalId = @OrganisationUUIDForSubmission
        )
    ,AllBrandFiles
        AS
        (
            SELECT
                FileId AS BrandFileId
            ,BlobName AS BrandBlobName
            ,FileType AS BrandFileType
            ,FileName AS BrandFileName
            ,ExternalId
            ,created
            ,ROW_NUMBER() OVER (
            PARTITION BY ExternalId
            ORDER BY created DESC
        ) AS row_num
            FROM
                AllOrganisationFiles aof
            WHERE aof.FileType = 'Brands'
        )
    ,AllPartnershipFiles
        AS
        (
            SELECT
                FileId AS PartnerFileId
            ,BlobName AS PartnerBlobName
            ,FileType AS PartnerFileType
            ,FileName AS PartnerFileName
            ,ExternalId
            ,created
            ,ROW_NUMBER() OVER (
            PARTITION BY ExternalId
            ORDER BY created DESC
        ) AS row_num
            FROM
                AllOrganisationFiles aof
            WHERE aof.FileType = 'Partnerships'
        )
    ,AllCompanyFiles
        AS
        (
            SELECT
                FileId AS CompanyFileId
            ,BlobName AS CompanyBlobName
            ,FileType AS CompanyFileType
            ,FileName AS CompanyFileName
            ,ExternalId
            ,created
            ,ROW_NUMBER() OVER (
            PARTITION BY ExternalId
            ORDER BY created DESC
        ) AS row_num
            FROM
                AllOrganisationFiles aof
            WHERE aof.FileType = 'CompanyDetails'
        )
    ,LatestBrandsFile
        AS
        (
            SELECT
                BrandFileId
            ,BrandBlobName
            ,BrandFileType
            ,BrandFileName
            ,ExternalId
            FROM
                AllBrandFiles abf
            WHERE abf.row_num = 1
        )
    ,LatestPartnerFile
        AS
        (
            SELECT
                PartnerFileId
            ,PartnerBlobName
            ,PartnerFileType
            ,PartnerFileName
            ,ExternalId
            FROM
                AllPartnershipFiles apf
            WHERE apf.row_num = 1
        )
    ,LatestCompanyFiles
        AS
        (
            SELECT
                CompanyFileId
            ,CompanyBlobName
            ,CompanyFileType
            ,CompanyFileName
            ,ExternalId
            FROM
                AllCompanyFiles acf
            WHERE acf.row_num = 1
        )
    ,AllCombinedOrgFiles
        AS
        (
            SELECT
                lcf.ExternalId AS OrganisationExternalId
            ,CompanyFileId
            ,CompanyFileName
            ,CompanyBlobName
            ,BrandFileId
            ,BrandFileName
            ,BrandBlobName
            ,PartnerFileId
            ,PartnerFileName
            ,PartnerBlobName
            FROM
                LatestCompanyFiles lcf
                LEFT OUTER JOIN LatestBrandsFile lbf
                LEFT OUTER JOIN LatestPartnerFile lpf ON lpf.ExternalId = lbf.ExternalId ON lcf.ExternalId = lbf.ExternalId
        ) -- All submission data combined with the individual file data

    ,JoinDataWithPartnershipAndBrandsCTE
        AS
        (
            SELECT
                joinedSubmissions.*
            ,CompanyFileId AS CompanyDetailsFileId
            ,CompanyFileName AS CompanyDetailsFileName
            ,CompanyBlobName AS CompanyDetailsBlobName
            ,BrandFileId AS BrandsFileId
            ,BrandFileName AS BrandsFileName
            ,BrandBlobName BrandsBlobName
            ,PartnerFileName AS PartnershipFileName
            ,PartnerFileId AS PartnershipFileId
            ,PartnerBlobName AS PartnershipBlobName
            FROM
                SubmissionOrganisationCommentsDetailsCTE AS joinedSubmissions
                LEFT JOIN AllCombinedOrgFiles acof ON acof.OrganisationExternalId = joinedSubmissions.OrganisationId
        ) --		select * from JoinDataWithPartnershipAndBrandsCTE 
-- For the Submission Period of the Submission
-- Use the new view to obtain information required for the Paycal API
-- The Organisation reference number of the Submission's organisation is used
-- It is controlled by whether the IsComplianceScheme flag is 1

    ,CompliancePaycalCTE
        AS
        (
            SELECT
                CSOReference
            ,csm.ReferenceNumber
            ,csm.RelevantYear
            ,ppp.ProducerSize
            ,csm.SubmittedDate
            ,csm.IsLateFeeApplicable
            ,ppp.IsOnlineMarketPlace
            ,ppp.NumberOfSubsidiaries
            ,ppp.NumberOfSubsidiariesBeingOnlineMarketPlace
            ,csm.submissionperiod
            ,@SubmissionPeriod AS WantedPeriod
            FROM
                dbo.v_ComplianceSchemeMembers csm
                INNER JOIN dbo.v_ProducerPayCalParameters ppp ON ppp.OrganisationReference = csm.ReferenceNumber
            WHERE @IsComplianceScheme = 1
                AND csm.CSOReference = @CSOReferenceNumber
                AND csm.SubmissionPeriod = @SubmissionPeriod
        ) -- Build a rowset of membership organisations and their producer paycal api parameter requirements
-- the properties of the above is built into a JSON string

    ,JsonifiedCompliancePaycalCTE
        AS
        (
            SELECT
                CSOReference
            ,ReferenceNumber
            ,'{"MemberId": "' + CAST(ReferenceNumber AS NVARCHAR(25)) + '", ' + '"MemberType": "' + ProducerSize + '", ' + '"IsOnlineMarketPlace": ' + CASE
            WHEN IsOnlineMarketPlace = 1 THEN 'true'
            ELSE 'false'
        END + ', ' + '"NumberOfSubsidiaries": ' + CAST(NumberOfSubsidiaries AS NVARCHAR(MAX)) + ', ' + '"NumberOfSubsidiariesOnlineMarketPlace": ' + CAST(
            NumberOfSubsidiariesBeingOnlineMarketPlace AS NVARCHAR(MAX)
        ) + ', ' + '"RelevantYear": ' + CAST(RelevantYear AS NVARCHAR(4)) + ', ' + '"SubmittedDate": "' + CAST(SubmittedDate AS nvarchar(16)) + '", ' + '"IsLateFeeApplicable": ' + CASE
            WHEN IsLateFeeApplicable = 1 THEN 'true'
            ELSE 'false'
        END + ', ' + '"SubmissionPeriodDescription": "' + submissionperiod + '"}' AS OrganisationDetailsJsonString
            FROM
                CompliancePaycalCTE
        ) -- the above CTE is then compressed into a single row using the STRIN_AGG function

    ,AllCompliancePaycalParametersAsJSONCTE
        AS
        (
            SELECT
                CSOReference
            ,'[' + STRING_AGG(OrganisationDetailsJsonString, ', ') + ']' AS FinalJson
            FROM
                JsonifiedCompliancePaycalCTE
            WHERE CSOReference = @CSOReferenceNumber
            GROUP BY CSOReference
        )
    -- bring all the above into one 1
    SELECT DISTINCT
        r.SubmissionId
        ,r.OrganisationId
        ,r.OrganisationName AS OrganisationName
        ,r.OrganisationReferenceNumber AS OrganisationReference
        ,r.ApplicationReferenceNumber
        ,r.RegistrationReferenceNumber
        ,r.SubmissionStatus
        ,r.StatusPendingDate
        ,r.SubmittedDateTime
        ,r.IsLateSubmission
        ,r.SubmissionPeriod
        ,r.RelevantYear
        ,r.IsComplianceScheme
        ,r.ProducerSize AS OrganisationSize
        ,r.OrganisationType
        ,r.NationId
        ,r.NationCode
        ,r.RegulatorComment
        ,r.ProducerComment
        ,r.RegulatorDecisionDate
        ,r.ProducerCommentDate
        ,r.ProducerSubmissionEventId
        ,r.RegulatorSubmissionEventId
        ,r.RegulatorUserId
        ,o.CompaniesHouseNumber
        ,o.BuildingName
        ,o.SubBuildingName
        ,o.BuildingNumber
        ,o.Street
        ,o.Locality
        ,o.DependentLocality
        ,o.Town
        ,o.County
        ,o.Country
        ,o.Postcode
        ,r.SubmittedUserId
        ,p.FirstName
        ,p.LastName
        ,p.Email
        ,p.Telephone
        ,sr.Name AS ServiceRole
        ,sr.Id AS ServiceRoleId
        ,r.IsOnlineMarketplace
        ,r.NumberOfSubsidiaries
        ,r.NumberOfSubsidiariesBeingOnlineMarketPlace AS NumberOfOnlineSubsidiaries
        ,r.CompanyDetailsFileId
        ,r.CompanyDetailsFileName
        ,r.CompanyDetailsBlobName
        ,r.PartnershipFileId
        ,r.PartnershipFileName
        ,r.PartnershipBlobName
        ,r.BrandsFileId
        ,r.BrandsFileName
        ,r.BrandsBlobName
        --,r.OrgFileId
        --,r.OrgFileName
        --,r.OrgBlobName
        --,r.OrgOriginalFileName,
        ,acpp.FinalJson AS CSOJson
    FROM
        JoinDataWithPartnershipAndBrandsCTE r
        INNER JOIN [rpd].[Organisations] o
        LEFT JOIN AllCompliancePaycalParametersAsJSONCTE acpp ON acpp.CSOReference = o.ReferenceNumber ON o.ExternalId = r.OrganisationId
        INNER JOIN [rpd].[Users] u ON u.UserId = r.SubmittedUserId
        INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
        INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
        INNER JOIN [rpd].[ServiceRoles] sr ON sr.Id = poc.PersonRoleId
END
GO

-- Dropping view if it exists
IF EXISTS (SELECT 1 FROM sys.views WHERE object_id = OBJECT_ID(N'[apps].[v_RegistrationsSummaries]'))
DROP VIEW [apps].[v_RegistrationsSummaries];
GO

CREATE VIEW [apps].[v_RegistrationsSummaries]
AS WITH  file_id_set_id as
(
	select distinct RegistrationSetId, FileId, FileName, load_ts
	from [apps].[SubmissionEvents] 
	where RegistrationSetId is not null 
	and FileId is not null
)
,file_type_id as
(
	select distinct FileType, FileId
	from [apps].[SubmissionEvents] 
	where FileType is not null 
	and FileId is not null
)
, blob_and_File_id as
(
select distinct BlobName, FileId
from [apps].[SubmissionEvents] 
where 
BlobName is not null
and 
FileId is not null
)
, file_type_id_blobname_filename as
(
	select ftyid.FileType, ftyid.FileId, bfid.BlobName, set_id.FileName, set_id.RegistrationSetId, set_id.load_ts
	from blob_and_File_id bfid
	inner join file_type_id ftyid on bfid.FileId = ftyid.FileId
	inner join file_id_set_id set_id on set_id.FileId = bfid.FileId
)
,AllSubmittedEventsCTE AS (
    SELECT
        SubmissionEventId,
        SubmissionId,
        FileId AS CompanyDetailsFileId,
        Type,
        Created AS RegistrationDate,
        ROW_NUMBER() OVER (
            PARTITION BY FileId
            ORDER BY load_ts DESC -- mark latest submissionEvent synced from cosmos
        ) as RowNum
    FROM [apps].[SubmissionEvents]
    WHERE Type = 'Submitted'
    )

    -- Get LATEST submitted event by created per FileId (to remove cosmos sync duplicates)
        ,LatestSubmittedEventsCTE AS (
        SELECT
            SubmissionEventId,
            SubmissionId,
            Type,
            CompanyDetailsFileId,
            RegistrationDate
        FROM AllSubmittedEventsCTE
        WHERE RowNum = 1
        )

    -- Get Decision events for submitted (match by CompanyDetailsFileId)
        ,AllRelatedDecisionEventsCTE AS (
        SELECT
            submitted.CompanyDetailsFileId,
            decision.SubmissionEventId,
            decision.SubmissionId,
            decision.Decision,
            decision.Comments,
            decision.Created AS DecisionDate,
            ROW_NUMBER() OVER(
                PARTITION BY decision.FileId  -- mark latest submissionEvent synced from cosmos
                ORDER BY decision.load_ts DESC
            ) as RowNum
        FROM [apps].[SubmissionEvents] decision
        INNER JOIN LatestSubmittedEventsCTE submitted ON submitted.CompanyDetailsFileId = decision.FileId
        WHERE decision.Type = 'RegulatorRegistrationDecision'
        )

        ,LatestRelatedDecisionEventsCTE AS (
        SELECT
            CompanyDetailsFileId,
            SubmissionEventId,
            SubmissionId,
            Decision,
            Comments,
            DecisionDate
        FROM AllRelatedDecisionEventsCTE
        WHERE RowNum = 1 --  get only latest
        )

        ,JoinedSubmittedAndDecisionsCTE AS (
        SELECT
            submitted.SubmissionId,
            submitted.RegistrationDate,
            submitted.CompanyDetailsFileId,
            decision.DecisionDate,
            decision.Decision,
            decision.Comments
        FROM LatestSubmittedEventsCTE submitted
        LEFT JOIN LatestRelatedDecisionEventsCTE decision ON decision.CompanyDetailsFileId = submitted.CompanyDetailsFileId
        WHERE decision.Decision IS NULL -- get ALL pending
        OR submitted.RegistrationDate >= FORMAT(DATEADD(MONTH, -6, GETDATE()), 'yyyy-MM-dd') -- or last 6 months with decisions (accepted/rejected)
        )

        ,AllRelatedSubmissionsCTE AS (
        SELECT
            s.SubmissionId,
            s.OrganisationId,
            s.ComplianceSchemeId,
            s.UserId,
            s.SubmissionPeriod,
            jsd.CompanyDetailsFileId,
            ROW_NUMBER() OVER(
                PARTITION BY s.SubmissionId
                ORDER BY s.load_ts DESC
            ) as RowNum -- mark latest submission synced from cosmos
        FROM [apps].[Submissions] s
        INNER JOIN JoinedSubmittedAndDecisionsCTE jsd ON jsd.SubmissionId = s.SubmissionId
        )

        ,LatestRelatedSubmissionsCTE AS (
        SELECT
            SubmissionId,
            OrganisationId,
            ComplianceSchemeId,
            UserId,
            SubmissionPeriod,
            CompanyDetailsFileId
        FROM AllRelatedSubmissionsCTE
        WHERE RowNum = 1
        )

-- Use the above CTEs to get all submissions with submitted event, and join decision if exists
        ,JoinedSubmissionsAndEventsCTE AS (
        SELECT
            s.SubmissionId,
            s.OrganisationId,
            s.ComplianceSchemeId,
            s.UserId,
            s.SubmissionPeriod,
            jsd.CompanyDetailsFileId,
            jsd.Decision,
            jsd.Comments,
            jsd.RegistrationDate,
            jsd.DecisionDate,
            ROW_NUMBER() OVER(
                PARTITION BY s.SubmissionId
                ORDER BY jsd.RegistrationDate DESC
            ) as RowNum -- original row number based on submitted date
        FROM JoinedSubmittedAndDecisionsCTE jsd
        INNER JOIN LatestRelatedSubmissionsCTE s ON jsd.SubmissionId = s.SubmissionId
        )

        ,JoinedSubmissionsAndEventsWithResubmissionCTE AS (
        SELECT
            l.*,
            (
            SELECT COUNT(*)
            FROM JoinedSubmissionsAndEventsCTE j
            WHERE
                j.SubmissionId = l.SubmissionId AND
                j.RowNum > l.RowNum AND
                j.Decision IS NOT NULL -- how many decisions BEFORE this one           
            ) AS PreviousDecisions,
            (
            SELECT TOP 1 j.Comments
            FROM JoinedSubmissionsAndEventsCTE j
            WHERE
                j.SubmissionId = l.SubmissionId AND
                j.RowNum > l.RowNum AND
                j.Decision='Rejected' -- get last rejection comments BEFORE this one
            ORDER BY j.RegistrationDate DESC
            ) AS PreviousRejectionComments
        FROM JoinedSubmissionsAndEventsCTE l
        WHERE
        (l.Decision IS NULL AND RowNum=1) -- show pending if latest
        OR l.Decision IS NOT NULL -- and show all decisions
        )

        ,AllCompanyDetailsCTE AS (
        SELECT
            joinedSubmissions.CompanyDetailsFileId,
            companyDetailsAntiVirus.FileName AS CompanyDetailsFileName,
            companyDetailsAntiVirus.BlobName AS CompanyDetailsBlobName,
            companyDetailsAntiVirus.RegistrationSetId,
            companyDetailsAntiVirus.FileType,
            ROW_NUMBER() OVER(
            PARTITION BY companyDetailsAntiVirus.FileId
                ORDER BY companyDetailsAntiVirus.load_ts DESC
            ) as RowNum
        FROM file_type_id_blobname_filename companyDetailsAntiVirus
        INNER JOIN JoinedSubmissionsAndEventsWithResubmissionCTE joinedSubmissions ON joinedSubmissions.CompanyDetailsFileId = companyDetailsAntiVirus.FileId
        WHERE companyDetailsAntiVirus.FileType = 'CompanyDetails'
        --AND companyDetailsAntiVirus.Type = 'AntivirusCheck'
        )

        ,LatestCompanyDetailsCTE AS (
        SELECT
            CompanyDetailsFileId,
            CompanyDetailsFileName,
            CompanyDetailsBlobName,
            RegistrationSetId,
            FileType
        FROM AllCompanyDetailsCTE
        WHERE RowNum = 1
        )

        ,BrandsFilenameAndIdCTE AS (
        SELECT
            brandsAntiVirus.FileId AS BrandsFileId,
            brandsAntiVirus.FileName AS BrandsFileName,
            brandsAntiVirus.BlobName AS BrandsBlobName,
            latestCompanyDetails.CompanyDetailsFileId AS CompanyDetailsFileId,
            ROW_NUMBER() OVER(
                PARTITION BY latestCompanyDetails.CompanyDetailsFileId
                ORDER BY brandsAntiVirus.load_ts DESC
            ) as RowNum
        FROM file_type_id_blobname_filename brandsAntiVirus
        INNER JOIN LatestCompanyDetailsCTE latestCompanyDetails ON brandsAntiVirus.RegistrationSetId = latestCompanyDetails.RegistrationSetId
        WHERE brandsAntiVirus.FileType = 'Brands'
        --AND brandsAntiVirus.Type = 'AntivirusCheck'
        )

        ,LatestBrandDetailsCTE AS (
        SELECT
            BrandsFileId,
            BrandsFileName,
            BrandsBlobName,
            CompanyDetailsFileId
        FROM BrandsFilenameAndIdCTE
        WHERE RowNum = 1
        )

        ,PartnershipFilenameAndIdCTE AS (
        SELECT
            partnershipAntiVirus.FileId AS PartnershipFileId,
            partnershipAntiVirus.FileName AS PartnershipFileName,
            partnershipAntiVirus.BlobName AS PartnershipBlobName,
            latestCompanyDetails.CompanyDetailsFileId AS CompanyDetailsFileId,
            ROW_NUMBER() OVER(
                PARTITION BY latestCompanyDetails.CompanyDetailsFileId
                ORDER BY partnershipAntiVirus.load_ts DESC
            ) as RowNum
        FROM file_type_id_blobname_filename partnershipAntiVirus
        INNER JOIN LatestCompanyDetailsCTE latestCompanyDetails ON partnershipAntiVirus.RegistrationSetId = latestCompanyDetails.RegistrationSetId
        WHERE partnershipAntiVirus.FileType = 'Partnerships'
        --AND partnershipAntiVirus.Type = 'AntivirusCheck'
        )

        ,LatestPartnershipDetailsCTE AS (
        SELECT
            PartnershipFileId,
            PartnershipFileName,
            PartnershipBlobName,
            CompanyDetailsFileId
        FROM PartnershipFilenameAndIdCTE
        WHERE RowNum = 1
        )

        ,JoinDataWithPartnershipAndBrandsCTE AS (
        SELECT
            joinedSubmissions.*,
            companyDetails.CompanyDetailsFileName,
            companyDetails.CompanyDetailsBlobName,
            brands.BrandsFileName,
            brands.BrandsFileId,
            brands.BrandsBlobName,
            partnerships.PartnershipFileName,
            partnerships.PartnershipFileId,
            partnerships.PartnershipBlobName
        FROM JoinedSubmissionsAndEventsWithResubmissionCTE AS joinedSubmissions
        INNER JOIN LatestCompanyDetailsCTE companyDetails ON companyDetails.CompanyDetailsFileId = joinedSubmissions.CompanyDetailsFileId
        LEFT JOIN LatestBrandDetailsCTE brands ON brands.CompanyDetailsFileId = joinedSubmissions.CompanyDetailsFileId
        LEFT JOIN LatestPartnershipDetailsCTE partnerships ON partnerships.CompanyDetailsFileId = joinedSubmissions.CompanyDetailsFileId
        )

-- Create subquery for latest enrolment
        ,LatestEnrolment AS (
        SELECT
            e.ConnectionId,
            e.ServiceRoleId,
            e.LastUpdatedOn,
            ROW_NUMBER() OVER(
                PARTITION BY e.ConnectionId
                ORDER BY e.LastUpdatedOn
                DESC
            ) as rn
            FROM [rpd].[Enrolments] e
            )

SELECT
    SubmissionId,
    r.OrganisationId,
    r.ComplianceSchemeId,
    o.Name As OrganisationName,
    o.ReferenceNumber as OrganisationReference,
    o.CompaniesHouseNumber,
    o.SubBuildingName,
    o.BuildingName,
    o.BuildingNumber,
    o.Street,
    o.Locality,
    o.DependentLocality,
    o.Town,
    o.County,
    o.Country,
    o.Postcode,
    CASE
        WHEN r.ComplianceSchemeId IS NOT NULL THEN 'Compliance Scheme'
        ELSE 'Direct Producer'
        END AS  OrganisationType,
    pt.Name as ProducerType,
    r.UserId,
    p.FirstName,
    p.LastName,
    p.Email,
    p.Telephone,
    sr.Name as ServiceRole,
    r.CompanyDetailsFileId,
    r.CompanyDetailsFileName,
    r.CompanyDetailsBlobName,
    r.PartnershipFileName,
    r.PartnershipFileId,
    r.PartnershipBlobName,
    r.BrandsFileName,
    r.BrandsFileId,
    r.BrandsBlobName,
    SubmissionPeriod,
    RegistrationDate,
    CASE
        WHEN Decision IS NULL THEN 'Pending'
        ELSE Decision
        END AS Decision,
    Comments,
    CASE
        WHEN PreviousDecisions > 0 THEN 1
        ELSE 0
        END AS IsResubmission,
    PreviousRejectionComments,
    CASE
        WHEN r.ComplianceSchemeId IS NOT NULL THEN cs.NationId
        ELSE o.NationId
        END AS NationId
FROM JoinDataWithPartnershipAndBrandsCTE r
INNER JOIN [rpd].[Organisations] o ON o.ExternalId = r.OrganisationId
LEFT JOIN [rpd].[ProducerTypes] pt ON pt.Id = o.ProducerTypeId
INNER JOIN [rpd].[Users] u ON u.UserId = r.UserId
INNER JOIN [rpd].[Persons] p ON p.UserId = u.Id
INNER JOIN [rpd].[PersonOrganisationConnections] poc ON poc.PersonId = p.Id
INNER JOIN LatestEnrolment le ON le.ConnectionId = poc.Id AND le.rn = 1 -- join on only latest enrolment
INNER JOIN [rpd].[ServiceRoles] sr on sr.Id = le.ServiceRoleId
LEFT JOIN [rpd].[ComplianceSchemes] cs ON cs.ExternalId = r.ComplianceSchemeId -- join CS to get nation above
WHERE o.IsDeleted = 0;
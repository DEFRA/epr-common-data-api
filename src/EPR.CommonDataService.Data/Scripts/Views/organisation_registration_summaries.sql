IF EXISTS (SELECT 1 FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[v_OrganisationRegistrationSummaries]'))
DROP VIEW [dbo].[v_OrganisationRegistrationSummaries];
GO

create view [dbo].[v_OrganisationRegistrationSummaries]
as 
WITH
    AllFilesAndOrgs
    AS
    (
        SELECT
            a.*
        FROM
            (
		SELECT
                cmd.organisationid AS CosmosOrgId
			,o.name AS OrganisationName
			,o.ReferenceNumber AS OrgRefNum
			,cmd.SubmissionPeriod
			,Row_number() OVER (
				partition BY cmd.organisationid, SubmissionPeriod
				ORDER BY CONVERT(DATETIME, Substring(cmd.Created, 1, 23)) DESC
			) AS org_rownumber
			,cmd.Created AS UploadTime
			,cmd.FileName AS OrgFileName
			,cmd.IsSubmitted
			,cmd.ComplianceSchemeId
			,CASE
				WHEN cmd.complianceschemeid IS NULL THEN 0
				ELSE 1
			END AS IsComplianceScheme
            FROM
                rpd.cosmos_file_metadata cmd
                INNER JOIN rpd.organisations o ON o.externalid = cmd.organisationid
            WHERE TRIM(FileType) = 'CompanyDetails'
                AND TRIM(SubmissionType) = 'Registration'
                AND SubmissionPeriod LIKE 'January to December%'
                AND Created > '2024-12-06'
		)	AS a
        WHERE a.org_rownumber = 1
    )
	,CDData
    AS
    (
        SELECT
            a.*
        FROM
            (
			SELECT
                cd.organisation_id
                ,filename
                ,organisation_size
                ,load_ts
                ,row_number() OVER ( partition BY organisation_id ORDER BY load_ts DESC) AS rownum
            FROM
                rpd.companydetails cd
            WHERE cd.load_ts > '2024-12-06'
		) AS a
			WHERE a.rownum = 1
    )
	,latest_org_record_and_details
    AS
    (
        SELECT
            cd.organisation_id AS ReferenceNumber
			,af.OrganisationName
			,cd.FileName AS CDFileName
			,CASE
				WHEN cd.organisation_size IS NULL THEN NULL
				WHEN LOWER(cd.organisation_size) = 'l' THEN 'Large'
				WHEN LOWER(cd.organisation_size) = 's' THEN 'Small'
				ELSE NULL
			END AS ProducerSize
			,af.CosmosOrgId
			,af.SubmissionPeriod
			,af.OrgFileName
			,af.IsSubmitted
			,af.ComplianceSchemeId
			,af.IsComplianceScheme
			,Row_number() OVER (
				partition BY organisation_id
				ORDER BY cd.load_ts DESC
			) AS org_rownumber
        FROM
            allfilesandorgs af
            INNER JOIN CDData cd ON cd.organisation_id = af.OrgRefNum
        WHERE cd.load_ts > '2024-12-06'
    )
    ,latest_org_record_and_details_old
    AS
    (
        SELECT
            a.*
        FROM
            (
            SELECT
                o.Name
                ,o.ReferenceNumber AS OrgRefNum
                ,cmd.SubmissionPeriod
                ,CASE
                    WHEN cd.organisation_size IS NULL THEN NULL
                    WHEN LOWER(cd.organisation_size) = 'l' THEN 'Large'
                    WHEN LOWER(cd.organisation_size) = 's' THEN 'Small'
                    ELSE NULL
                END AS ProducerSize
                ,cmd.Created AS UploadTime
                ,cmd.FileId AS OrgFileId
                ,cmd.FileName AS OrgFileName
                ,cmd.BlobName AS OrgBlobName
                ,cmd.OriginalFileName AS OrgOriginalFileName
                ,cmd.IsSubmitted
                ,cmd.ComplianceSchemeId
                ,CASE
                    WHEN cmd.complianceschemeid IS NULL THEN 0
                    ELSE 1
                END AS IsComplianceScheme
                ,Row_number() OVER (
                    partition BY cmd.organisationid
                    ORDER BY CONVERT(DATETIME, Substring(cmd.Created, 1, 23)) DESC
                ) AS org_rownumber
            FROM
                rpd.cosmos_file_metadata cmd
                INNER JOIN rpd.companydetails cd ON cd.FileName = cmd.FileName
                INNER JOIN rpd.organisations o ON o.referencenumber = cd.organisation_id
            WHERE TRIM(FileType) = 'CompanyDetails'
                AND TRIM(SubmissionType) = 'Registration'
                AND SubmissionPeriod LIKE 'January to December%'
                AND Created > '2024-12-06'
        ) AS a
        WHERE a.org_rownumber = 1
    )
    ,LatestOrganisationRegistrationSubmissionsCTE
    AS
    (
        SELECT
            a.*
        FROM
            (
            SELECT
                org.Name AS OrganisationName
                ,org.ReferenceNumber
                ,s.AppReferenceNumber AS ApplicationReferenceNumber
                ,s.SubmissionPeriod
                ,s.SubmissionId
                ,s.OrganisationId AS InternalOrgId
                ,s.Created AS SubmittedDate
                ,org.Id AS OrganisationInternalId
                ,org.NationId AS ProducerNationId
                ,CASE
                    org.NationId
                    WHEN 1 THEN 'GB-ENG'
                    WHEN 2 THEN 'GB-NIR'
                    WHEN 3 THEN 'GB-SCT'
                    WHEN 4 THEN 'GB-WLS'
                END AS ProducerNationCode
                ,s.Created
                ,s.SubmissionType
                ,s.UserId AS SubmittedUserId
                ,CAST(
                    SUBSTRING(
                        s.SubmissionPeriod,
                        PATINDEX('%[0-9][0-9][0-9][0-9]%', s.SubmissionPeriod),
                        4
                    ) AS INT
                ) AS RelevantYear
                ,CAST(
                    CASE
                        WHEN s.Created > DATEFROMPARTS(CONVERT( int, SUBSTRING(
                                        s.SubmissionPeriod,
                                        PATINDEX('%[0-9][0-9][0-9][0-9]', s.SubmissionPeriod),
                                        4
                                    )),4,1) THEN 1
                        ELSE 0
                    END AS BIT
                ) AS IsLateSubmission
                ,ROW_NUMBER() OVER (
                    PARTITION BY s.OrganisationId,
                    s.SubmissionPeriod
                    ORDER BY s.load_ts DESC -- mark latest submission synced from cosmos
                ) AS RowNum
            FROM
                [apps].[Submissions] AS s
                INNER JOIN [rpd].[Organisations] org ON org.ExternalId = s.OrganisationId
				--INNER JOIN [apps].[SubmissionEvents] as se
				--	ON se.SubmissionId = s.SubmissionId
				--	and se.Type = 'RegistrationApplicationSubmitted'
            WHERE s.AppReferenceNumber IS NOT NULL
                AND s.SubmissionType = 'Registration'
                AND s.SubmissionPeriod LIKE 'January to December%'
                AND org.IsDeleted = 0
				ANd s.IsSubmitted = 1
        ) AS a
        WHERE a.RowNum = 1
    )
    ,SubmissionWithOrgDataCTE
    AS
    (
        SELECT
            SubmissionId
            ,InternalOrgId AS OrganisationId
            ,OrganisationInternalId
            ,submissions.OrganisationName
            ,submissions.ReferenceNumber
            ,ApplicationReferenceNumber
            ,ProducerNationId
            ,ProducerNationCode
            ,Created AS SubmittedDateTime
            ,SubmissionType
            ,submissions.SubmissionPeriod
            ,RelevantYear
            ,IsLateSubmission
            ,SubmittedUserId
            ,IsComplianceScheme
            ,ProducerSize
        FROM
            LatestOrganisationRegistrationSubmissionsCTE AS submissions
            left JOIN latest_org_record_and_details lord ON lord.ReferenceNumber = submissions.ReferenceNumber
                AND lord.SubmissionPeriod = submissions.SubmissionPeriod
    )
--select * from SubmissionWithOrgDataCTE
    ,AllRelatedOrganisationRegistrationDecisionEventsCTE
    AS
    (
        SELECT
            decisions.SubmissionId
            ,decisions.SubmissionEventId AS DecisionEventId
            ,decisions.Comments AS RegulatorComment
            ,decisions.RegistrationReferenceNumber AS RegistrationReferenceNumber
            ,decisions.Type AS DecisionType
            ,CASE
                WHEN LTRIM(RTRIM(decisions.Decision)) = 'Accepted' THEN 'Granted'
                WHEN LTRIM(RTRIM(decisions.Decision)) = 'Rejected' THEN 'Refused'
                WHEN decisions.decision IS NULL THEN 'Pending'
                ELSE decisions.Decision
            END AS SubmissionStatus
            ,decisions.Created AS RegulatorDecisionDate
            ,decisions.UserId AS RegulatorUserId
            ,decisions.DecisionDate AS StatusPendingDate
            ,ROW_NUMBER() OVER (
                PARTITION BY decisions.SubmissionId
                ORDER BY decisions.Created DESC -- mark latest submissionEvent synced from cosmos
            ) AS RowNum
        FROM
            [apps].[SubmissionEvents] AS decisions
            INNER JOIN SubmissionWithOrgDataCTE registrations
            ON decisions.SubmissionId = registrations.SubmissionId
        WHERE decisions.Type = 'RegulatorRegistrationDecision'
            AND decisions.SubmissionId = registrations.SubmissionId

    )
   ,LatestGrantedRegistrationEventCTE
    AS
    (
        SELECT
            DecisionEventId AS GrantedEventId
            ,SubmissionId
            ,RegistrationReferenceNumber
        FROM
            AllRelatedOrganisationRegistrationDecisionEventsCTE decision
        WHERE LTRIM(RTRIM(SubmissionStatus)) IN ('Granted', 'Accepted')
    )
	,LatestDecisionEventsCTE
    AS
    (
        SELECT
            DecisionEventId
            ,SubmissionId
            ,RegulatorComment
            ,RegistrationReferenceNumber
            ,RegulatorDecisionDate
            ,DecisionType
            ,SubmissionStatus
            ,RegulatorUserId
            ,StatusPendingDate
        FROM
            AllRelatedOrganisationRegistrationDecisionEventsCTE
        WHERE RowNum = 1
    )
	,AllRelatedProducerCommentEventsCTE
    AS
    (
        SELECT
            a.*
        FROM
            (
			SELECT
                producercomment.SubmissionEventId
				,producercomment.SubmissionId
				,producercomment.Comments AS ProducerComment
				,producercomment.Created AS ProducerCommentDate
				,ROW_NUMBER() OVER (
					PARTITION BY producercomment.SubmissionId
					ORDER BY Created DESC -- mark latest submissionEvent synced from cosmos
				) AS RowNum
            FROM
                [apps].[SubmissionEvents] AS producercomment
                INNER JOIN SubmissionWithOrgDataCTE submittedregistrations ON 
				 producercomment.SubmissionId = submittedregistrations.SubmissionId
            WHERE producercomment.Type = 'RegistrationApplicationSubmitted'
		) AS a
        WHERE a.RowNum = 1
    )
	,AllSubmissionsAndDecisionsAndCommentCTE
    AS
    (
        SELECT
            DISTINCT
            submissions.SubmissionId
            ,submissions.OrganisationId
            ,submissions.OrganisationInternalId
            ,submissions.OrganisationName
            ,submissions.ReferenceNumber
            ,submissions.SubmittedUserId
            ,submissions.IsComplianceScheme
            ,submissions.ProducerSize
            ,submissions.ApplicationReferenceNumber
            ,granteddecision.RegistrationReferenceNumber
            ,submissions.SubmittedDateTime
            ,submissions.RelevantYear
            ,submissions.SubmissionPeriod
            ,submissions.IsLateSubmission
            ,decisions.RegistrationReferenceNumber AS DecisionRegistrationReferenceNumber
            ,ISNULL(decisions.SubmissionStatus, 'Pending') as SubmissionStatus
            ,decisions.RegulatorUserId
            ,decisions.StatusPendingDate
            ,decisions.RegulatorDecisionDate
            ,producercomments.ProducerCommentDate
            ,producercomments.SubmissionEventId AS ProducerSubmissionEventId
            ,decisions.DecisionEventId AS RegulatorSubmissionEventId
            ,submissions.ProducerNationId
            ,submissions.ProducerNationCode
        FROM
            SubmissionWithOrgDataCTE submissions
            LEFT JOIN LatestDecisionEventsCTE decisions
            ON decisions.SubmissionId = submissions.SubmissionId
            LEFT JOIN LatestGrantedRegistrationEventCTE granteddecision
            ON granteddecision.SubmissionId = submissions.SubmissionId
            LEFT JOIN AllRelatedProducerCommentEventsCTE producercomments
            ON producercomments.SubmissionId = submissions.SubmissionId
    )

SELECT
    DISTINCT
    submissions.SubmissionId
    ,submissions.OrganisationId
    ,submissions.OrganisationInternalId
    ,submissions.OrganisationName
    ,submissions.ReferenceNumber AS OrganisationReferenceNumber
    ,CASE 
        WHEN submissions.IsComplianceScheme = 1 THEN 'compliance'
        ELSE submissions.ProducerSize
    END AS OrganisationType
    ,submissions.IsComplianceScheme
    ,submissions.ProducerSize
    ,submissions.RelevantYear
	,submissions.IsLateSubmission
    ,submissions.SubmittedDateTime
    ,submissions.SubmissionStatus
    ,submissions.StatusPendingDate
    ,submissions.SubmissionPeriod
    ,submissions.ApplicationReferenceNumber
    ,CASE 
        WHEN submissions.RegistrationReferenceNumber IS NOT NULL 
            THEN submissions.RegistrationReferenceNumber
        ELSE submissions.DecisionRegistrationReferenceNumber
    END AS RegistrationReferenceNumber
    ,submissions.ProducerNationId AS NationId
    ,submissions.ProducerNationCode AS NationCode
    ,submissions.RegulatorUserId
    ,submissions.SubmittedUserId
    ,submissions.RegulatorDecisionDate
    ,submissions.ProducerCommentDate
    ,submissions.ProducerSubmissionEventId
    ,submissions.RegulatorSubmissionEventId
FROM
    AllSubmissionsAndDecisionsAndCommentCTE submissions;
GO

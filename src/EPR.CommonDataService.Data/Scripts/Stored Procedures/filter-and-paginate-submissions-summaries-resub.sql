-- Dropping stored procedure if it exists
IF EXISTS (SELECT 1 FROM sys.procedures WHERE object_id = OBJECT_ID(N'[apps].[sp_FilterAndPaginateSubmissionsSummaries_resub]'))
DROP PROCEDURE [apps].[sp_FilterAndPaginateSubmissionsSummaries_resub];
GO

CREATE PROC [apps].[sp_FilterAndPaginateSubmissionsSummaries_resub] @OrganisationName [NVARCHAR](255),@OrganisationReference [NVARCHAR](255),@RegulatorUserId [NVARCHAR](50),@StatusesCommaSeperated [NVARCHAR](50),@OrganisationType [NVARCHAR](50),@PageSize [INT],@PageNumber [INT],@DecisionsDelta [NVARCHAR](MAX),@SubmissionYearsCommaSeperated [NVARCHAR](1000),@SubmissionPeriodsCommaSeperated [NVARCHAR](1500),@ActualSubmissionPeriodsCommaSeperated [NVARCHAR](1500) AS
BEGIN
 
 -- get regulator user nation id
    DECLARE @NationId INT;

    SELECT @NationId = o.NationId
    FROM rpd.Users u
             INNER JOIN rpd.Persons p ON p.UserId = u.Id
             INNER JOIN rpd.PersonOrganisationConnections poc ON poc.PersonId = p.Id
             INNER JOIN rpd.Organisations o ON o.Id = poc.OrganisationId
             INNER JOIN rpd.Enrolments e ON e.ConnectionId = poc.Id
             INNER JOIN rpd.ServiceRoles sr ON sr.Id = e.ServiceRoleId
    WHERE
            sr.ServiceId=2 AND -- only regulator service users
            u.UserId=@RegulatorUserId;  -- with provided ID

-- Initial Filter CTE
WITH InitialFilter AS (
    SELECT distinct SubmissionId, OrganisationId, ComplianceSchemeId, OrganisationName, OrganisationReference, OrganisationType, ProducerType, UserId, FirstName, LastName, Email, Telephone, ServiceRole, FileId, SubmissionYear, Combined_SubmissionCode as SubmissionCode, Combined_ActualSubmissionPeriod as ActualSubmissionPeriod, SubmissionPeriod, SubmittedDate, Decision, IsResubmissionRequired, Comments, IsResubmission, PreviousRejectionComments, NationId, PomFileName,  PomBlobName
    FROM apps.SubmissionsSummaries ss
    WHERE
        (
            (NULLIF(@OrganisationName, '') IS NOT NULL AND OrganisationName LIKE '%' + @OrganisationName + '%')
            OR
            (NULLIF(@OrganisationReference, '') IS NOT NULL AND OrganisationReference LIKE '%' + @OrganisationReference + '%')
            OR
            (NULLIF(@OrganisationName, '') IS NULL AND NULLIF(@OrganisationReference, '') IS NULL)
        )
      AND (NationId = @NationId)
      AND
        (
            (@OrganisationType IS NULL OR @OrganisationType = 'All' OR @OrganisationType = '')
            OR
            (@OrganisationType = 'ComplianceScheme' AND ComplianceSchemeId IS NOT NULL)
            OR
            (@OrganisationType = 'DirectProducer' AND ComplianceSchemeId IS NULL)
         )
      AND (ISNULL(@SubmissionYearsCommaSeperated, '') = '' OR SubmissionYear IN (SELECT value FROM STRING_SPLIT(@SubmissionYearsCommaSeperated, ',')))
      AND (ISNULL(@SubmissionPeriodsCommaSeperated, '') = '' OR SubmissionPeriod IN (SELECT value FROM STRING_SPLIT(@SubmissionPeriodsCommaSeperated, ',')))
      AND (ISNULL(@ActualSubmissionPeriodsCommaSeperated, '') = '' OR ActualSubmissionPeriod IN (SELECT value FROM STRING_SPLIT(@ActualSubmissionPeriodsCommaSeperated, ',')))
    )
    -- This is the first fee resubmission record
    ,FirstResubmissionReferenceNumberCreated AS (
     SELECT se.SubmissionId, MIN(CONVERT(DATETIME,substring(Created,1,23))) AS FirstReferenceNumberCreated
        FROM apps.SubmissionEvents se
        INNER JOIN InitialFilter i
            ON se.SubmissionId = i.SubmissionId
        WHERE se.[Type] = 'PackagingResubmissionReferenceNumberCreated'
     GROUP BY se.SubmissionId
    )

    ,ResubmissionApplicationSubmittedData AS (
        SELECT se.FileId, se.SubmissionId, se.[Type] AS EventType
        FROM FirstResubmissionReferenceNumberCreated fr
     INNER JOIN apps.SubmissionEvents se 
      ON fr.SubmissionId = se.SubmissionId
       AND se.[Type] = 'PackagingResubmissionApplicationSubmitted'
       AND CONVERT(DATETIME,substring(se.Created,1,23)) > fr.FirstReferenceNumberCreated
        INNER JOIN InitialFilter i
            ON se.SubmissionId = i.SubmissionId    
    )

    ,SubmittedOrResubmissionWithoutNewEvents AS (
        SELECT se.FileId, se.SubmissionId, fr.FirstReferenceNumberCreated
        FROM apps.SubmissionEvents se
        INNER JOIN InitialFilter i
            ON se.SubmissionId = i.SubmissionId
     LEFT JOIN FirstResubmissionReferenceNumberCreated fr
      ON se.SubmissionId = fr.SubmissionId
        WHERE se.[Type] = 'Submitted'
      AND (fr.FirstReferenceNumberCreated IS NULL OR CONVERT(DATETIME,substring(se.Created,1,23)) < fr.FirstReferenceNumberCreated)
    )

    ,SubmissionsAggregated AS (
     SELECT FileId, SubmissionId FROM ResubmissionApplicationSubmittedData
     UNION
     SELECT FileId, SubmissionId FROM SubmittedOrResubmissionWithoutNewEvents
    )

    ,RemovedEarlyResubmissionIndicators AS (
      SELECT initial.SubmissionId,
          initial.OrganisationId,
          ComplianceSchemeId,
          OrganisationName,
          OrganisationReference,
          OrganisationType,
          ProducerType,
          initial.Userid,
          FirstName,
          LastName,
          Email,
          Telephone,
          ServiceRole,
          initial.FileId,
          SubmissionYear,
          SubmissionCode,
          ActualSubmissionPeriod,
          initial.SubmissionPeriod,
          SubmittedDate,
          initial.Decision,
          initial.IsResubmissionRequired,
          initial.Comments,
          initial.IsResubmission,
          PreviousRejectionComments,
          NationId,
          PomFileName,
          PomBlobName
      FROM InitialFilter initial
            INNER JOIN SubmissionsAggregated sa
                ON initial.FileId = sa.FileId
                AND initial.SubmissionId = sa.SubmissionId                  
    )

 ,RankedJsonParsedUpdates AS (
        SELECT
            JSON_VALUE([value], '$.FileId') AS FileId,
            JSON_VALUE([value], '$.Decision') AS Decision,
            JSON_VALUE([value], '$.Comments') AS Comments,
            JSON_VALUE([value], '$.IsResubmissionRequired') AS IsResubmissionRequired,
            ROW_NUMBER() OVER (PARTITION BY JSON_VALUE([value], '$.FileId') ORDER BY (SELECT NULL)) AS rn
        FROM OPENJSON(@DecisionsDelta)
    )

    ,JsonParsedUpdates AS (
        SELECT
            FileId,
            Decision,
            Comments,
            IsResubmissionRequired
        FROM RankedJsonParsedUpdates
        WHERE rn = 1
    )

    ,OverriddenStatuses AS (
        SELECT
            f.*,
            COALESCE(j.Decision, f.Decision) AS UpdatedDecision,
            COALESCE(j.Comments, f.Comments) AS UpdatedComments,
            COALESCE(j.IsResubmissionRequired, f.IsResubmissionRequired) AS UpdatedIsResubmissionRequired
        FROM RemovedEarlyResubmissionIndicators f
                 LEFT JOIN JsonParsedUpdates j ON j.FileId = f.FileId
    )

    ,StatusFilteredResults AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                ORDER BY
                    CASE
                        WHEN UpdatedDecision = 'Pending' THEN 1
                        WHEN UpdatedDecision = 'Rejected' THEN 2
                        WHEN UpdatedDecision = 'Accepted' THEN 3
                        ELSE 4
                    END,
                    SubmittedDate
            ) AS RowNum
        FROM OverriddenStatuses
        WHERE
            (ISNULL(@StatusesCommaSeperated, '') = '' OR UpdatedDecision IN (SELECT value FROM STRING_SPLIT(@StatusesCommaSeperated, ',')))
    )

 -- Fetch the paginated results
 SELECT
     [SubmissionId],
     [OrganisationId],
     [ComplianceSchemeId],
     [OrganisationName],
     [OrganisationReference],
     [OrganisationType],
     [ProducerType],
     [UserId],
     [FirstName],
     [LastName],
     [Email],
     [Telephone],
     [ServiceRole],
     [FileId],
	 [SubmissionYear], 
	 [SubmissionCode], 
	 [ActualSubmissionPeriod],
     [SubmissionPeriod],
     [SubmittedDate],
     [UpdatedDecision] AS Decision,
     [UpdatedIsResubmissionRequired] AS IsResubmissionRequired,
     [UpdatedComments] AS Comments,
     [IsResubmission],
     [PreviousRejectionComments],
     [NationId],
     [PomFileName],
     [PomBlobName],
     (SELECT COUNT(*) FROM StatusFilteredResults where UpdatedDecision in ('Pending','Rejected','Accepted')) AS TotalItems
 FROM StatusFilteredResults
 WHERE RowNum > (@PageSize * (@PageNumber - 1))
   AND RowNum <= @PageSize * @PageNumber
   AND UpdatedDecision in ('Pending','Rejected','Accepted')
 ORDER BY RowNum;

END;
GO
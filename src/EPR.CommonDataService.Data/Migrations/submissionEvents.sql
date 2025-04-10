-- Decision
IF NOT EXISTS (
    SELECT *
    FROM sys.columns 
    WHERE Name = N'Decision' 
    AND Object_ID = Object_ID(N'rpd.SubmissionEvents')
)
BEGIN
ALTER TABLE rpd.SubmissionEvents
    ADD [Decision] [nvarchar](4000) NULL
END

-- IsResubmissionRequired
IF NOT EXISTS (
    SELECT *
    FROM sys.columns 
    WHERE Name = N'IsResubmissionRequired' 
    AND Object_ID = Object_ID(N'rpd.SubmissionEvents')
)
BEGIN
ALTER TABLE rpd.SubmissionEvents
    ADD [IsResubmissionRequired] [bit] NULL
END

-- Comments
IF NOT EXISTS (
    SELECT *
    FROM sys.columns 
    WHERE Name = N'Comments' 
    AND Object_ID = Object_ID(N'rpd.SubmissionEvents')
)
BEGIN
ALTER TABLE rpd.SubmissionEvents
    ADD [Comments] [nvarchar](4000) NULL
END

-- PackagingResubmissionReferenceNumber
IF NOT EXISTS (
    SELECT *
    FROM sys.columns 
    WHERE Name = N'PackagingResubmissionReferenceNumber' 
    AND Object_ID = Object_ID(N'rpd.SubmissionEvents')
)
BEGIN
ALTER TABLE rpd.SubmissionEvents
    ADD [PackagingResubmissionReferenceNumber] [nvarchar](4000) NULL
END
-- NumberOfLateSubsidiaries for Direct Producer
IF NOT EXISTS (
    SELECT *
    FROM sys.columns 
    WHERE Name = N'NumberOfLateSubsidiaries' 
    AND Object_ID = Object_ID(N'dbo.t_ProducerPaycalParameters_resub')
)
BEGIN
ALTER TABLE dbo.t_ProducerPaycalParameters_resub
    ADD [NumberOfLateSubsidiaries] [int] NULL
END
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'sp_DynamicTableMerge')
    DROP PROCEDURE [apps].[sp_DynamicTableMerge]
GO

CREATE PROCEDURE [apps].[sp_DynamicTableMerge]
    @sourceSchema NVARCHAR(200),
    @sourceTableName NVARCHAR(200),
    @targetSchema NVARCHAR(200),
    @targetTableName NVARCHAR(200),
    @matchColumns NVARCHAR(MAX) -- Comma-separated list of column names
AS
BEGIN
    DECLARE @matchSQL NVARCHAR(MAX) = ''
    DECLARE @insertCols NVARCHAR(MAX) = ''
    DECLARE @insertValues NVARCHAR(MAX) = ''
    DECLARE @onClause NVARCHAR(MAX) = ''
    DECLARE @sql NVARCHAR(MAX)

     -- CTE to find all common columns
    ;WITH AllCommonColumns AS (
    SELECT c.COLUMN_NAME
    FROM INFORMATION_SCHEMA.COLUMNS c
             INNER JOIN INFORMATION_SCHEMA.COLUMNS c2 ON c.COLUMN_NAME = c2.COLUMN_NAME
    WHERE c.TABLE_SCHEMA = @sourceSchema AND c.TABLE_NAME = @sourceTableName
      AND c2.TABLE_SCHEMA = @targetSchema AND c2.TABLE_NAME = @targetTableName
    )

     -- Construct insertCols and insertValues using all common columns
     SELECT
             @insertCols = STRING_AGG(COLUMN_NAME, ', '),
             @insertValues = STRING_AGG('Source.' + COLUMN_NAME, ', ')
     FROM AllCommonColumns

    -- CTE to find common columns excluding matching cols passed to stored proc
    ;WITH CommonColumnsWithoutMatchColumns AS (
        SELECT c.COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS c
                 INNER JOIN INFORMATION_SCHEMA.COLUMNS c2 ON c.COLUMN_NAME = c2.COLUMN_NAME
        WHERE c.TABLE_SCHEMA = @sourceSchema AND c.TABLE_NAME = @sourceTableName
          AND c2.TABLE_SCHEMA = @targetSchema AND c2.TABLE_NAME = @targetTableName
          AND c.COLUMN_NAME NOT IN (SELECT value FROM STRING_SPLIT(@matchColumns, ','))
    )
    
     -- Construct matchSQL excluding match columns
     SELECT
             @matchSQL = STRING_AGG('Target.' + COLUMN_NAME + ' = Source.' + COLUMN_NAME, ', ')
     FROM CommonColumnsWithoutMatchColumns
    
    -- Dynamic ON Clause Construction
    SELECT @onClause = STRING_AGG('Target.' + value + ' = Source.' + value, ' AND ')
    FROM STRING_SPLIT(@matchColumns, ',')

    -- Construct the full MERGE statement
    SET @sql = 'MERGE INTO ' + QUOTENAME(@targetSchema) + '.' + QUOTENAME(@targetTableName) + ' AS Target ' +
               'USING ' + QUOTENAME(@sourceSchema) + '.' + QUOTENAME(@sourceTableName) + ' AS Source ' +
               'ON (' + @onClause + ') ' +
               'WHEN MATCHED THEN UPDATE SET ' + @matchSQL + ' ' +
               'WHEN NOT MATCHED BY TARGET THEN INSERT (' + @insertCols + ') VALUES (' + @insertValues + ') ' +
               'WHEN NOT MATCHED BY SOURCE THEN DELETE;'

	--PRINT @sql -- Do not check in PRINT statements as these are not compatible with the synapse pyodb and cause intermittent silent crashes

    -- Execute the dynamic SQL
    EXEC sp_executesql @sql
END
GO
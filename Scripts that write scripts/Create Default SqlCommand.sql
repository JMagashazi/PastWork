USE [GRIMM]
GO

DECLARE @TableName VARCHAR(100) = 'BreakfastMenu';
DECLARE @SrcSchema VARCHAR(20) = 'dbo';
DECLARE @DestSchema VARCHAR(20) = 'dbo';


DECLARE @Columns VARCHAR(MAX)
SELECT @Columns = COALESCE(@Columns, '') + '[' + [COLUMN_NAME] + '], '
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_NAME] = @TableName
AND [TABLE_SCHEMA] = @DestSchema
AND [COLUMN_NAME] <> 'IsArchive';

DECLARE @Script VARCHAR(MAX)
SET @Script = 'SELECT TOP 1 '+ @Columns + 'convert(nchar(1), ''I'') collate Latin1_General_BIN as [SYS_CHANGE_OPERATION] FROM [' + @SrcSchema + '].[' + @TableName + ']'

Select @Script
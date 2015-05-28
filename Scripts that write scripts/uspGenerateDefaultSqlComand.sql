USE [DS_ITSM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[uspGenerateDefaultSqlCommand] (@TableName VARCHAR(100))
AS

DECLARE @SrcSchema VARCHAR(20) = 'dbo';
DECLARE @DestSchema VARCHAR(20) = 'itsm';

DECLARE @Columns VARCHAR(MAX)
SELECT @Columns = COALESCE(@Columns, '') + '[' + [COLUMN_NAME] + '], '
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_NAME] = @TableName
AND [TABLE_SCHEMA] = @DestSchema
AND [COLUMN_NAME] <> 'IsArchive';

DECLARE @Script VARCHAR(MAX)
SET @Script = 'SELECT TOP 1 '+ @Columns + 'convert(bit, ''false'') as [IsArchive], convert(nchar(1), ''I'') collate Latin1_General_BIN as [SYS_CHANGE_OPERATION] FROM [' + @SrcSchema + '].[' + @TableName + ']'

SELECT @Script as 'Default SqlCommand Value';

GO



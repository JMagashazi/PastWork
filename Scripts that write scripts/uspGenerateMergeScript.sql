USE [DS_ITSM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[uspGenerateMergeScript] (@TableName VARCHAR(100))
AS

DECLARE @Schema VARCHAR(MAX)
SET @Schema = 'itsm';

DECLARE @Keys VARCHAR(MAX)
SELECT @Keys = COALESCE(@Keys + ' AND ', '') + 'target.' + [COLUMN_NAME] + ' = source.' + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[KEY_COLUMN_USAGE]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @TableName

DECLARE @UpdateColumns VARCHAR(MAX)
SELECT @UpdateColumns = COALESCE(@UpdateColumns + ',
', '') + '		target.' + [COLUMN_NAME] + '		=source.' + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @TableName
AND [COLUMN_NAME] NOT IN (
SELECT [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[KEY_COLUMN_USAGE]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @TableName)

DECLARE @InsertColumns VARCHAR(MAX)
SELECT @InsertColumns = COALESCE(@InsertColumns + ', ', '') + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @TableName

DECLARE @ValuesColumns VARCHAR(MAX)
SELECT @ValuesColumns = COALESCE(@ValuesColumns + ', ', '') + 'source.' + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @TableName

Declare @Script VARCHAR(MAX)
SET @Script = 'USE [DS_ITSM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [stage].[uspMerge' + @TableName + ']
AS
	merge ' + @Schema + '.' + @TableName + ' as target
	using stage.' + @TableName + ' as source on ' + @Keys +'

	when matched and source.SYS_CHANGE_OPERATION in (''U'', ''I'') then
	UPDATE SET
' + @UpdateColumns + '
	when not matched and source.SYS_CHANGE_OPERATION in (''U'', ''I'') then
		insert (' + @InsertColumns + ')
		values(' + @ValuesColumns + ')

	when matched and source.SYS_CHANGE_OPERATION = ''D'' then
		delete
;

GO'

SELECT @Script as 'Merge Script';

GO



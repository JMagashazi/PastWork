USE [DS_ITSM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[uspGenerateSqlCommandVBScript] (@TableName VARCHAR(100))
AS

DECLARE @SrcSchema VARCHAR(MAX)
SET @SrcSchema = 'dbo';

DECLARE @DestSchema VARCHAR(MAX)
SET @DestSchema = 'itsm';


DECLARE @InsertColumns VARCHAR(MAX)
SELECT @InsertColumns = COALESCE(@InsertColumns + ', ', '') + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @TableName;

DECLARE @IsNullKeys VARCHAR(MAX)
SELECT @IsNullKeys = COALESCE(@IsNullKeys + '', '') + 'ISNULL(data.' + [COLUMN_NAME] + ', TableCT.' + [COLUMN_NAME] + ')' + [COLUMN_NAME] + ', '
FROM [INFORMATION_SCHEMA].[KEY_COLUMN_USAGE]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @TableName;

DECLARE @DataColumns VARCHAR(MAX)
SELECT @DataColumns = COALESCE(@DataColumns + '', '') + 'data.' + [COLUMN_NAME] + ', '
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @TableName
AND [COLUMN_NAME] NOT IN (
SELECT [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[KEY_COLUMN_USAGE]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @TableName);

DECLARE @JoinKeys VARCHAR(MAX)
SELECT @JoinKeys = COALESCE(@JoinKeys + ' AND ', '') + 'data.' + [COLUMN_NAME] + ' = TableCT.' + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[KEY_COLUMN_USAGE]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @TableName;


Declare @Script VARCHAR(MAX)
SET @Script = 'Dts.Variables("User::SqlCommand").Value = " DECLARE @LastSyncVersion bigint =" + Dts.Variables("User::LastSyncVersion").Value.ToString() +
" Declare @CT_MinValidVersion BIGINT = ISNULL(CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(''' + @SrcSchema + '.' + @TableName + ''')),0) " +
" IF @LastSyncVersion=-1 OR (@LastSyncVersion < @CT_MinValidVersion and @LastSyncVersion<>0) " + " begin" +
" select ' + @InsertColumns + ', convert(bit, " + Dts.Variables("User::bArchive").Value.ToString() + ") as IsArchive, convert(nchar(1), ''I'') collate Latin1_General_BIN as SYS_CHANGE_OPERATION" +
" from ' + @SrcSchema + '.' + @TableName + ';" + " end" + " ELSE" + " begin" +
" select ' + @IsNullKeys + @DataColumns + 'convert(bit, " + Dts.Variables("User::bArchive").Value.ToString() + ") as IsArchive, TableCT.SYS_CHANGE_OPERATION" +
" FROM CHANGETABLE(CHANGES ' + @SrcSchema + '.' + @TableName + ', @LastSyncVersion) TableCT" +
" left JOIN ' + @SrcSchema + '.' + @TableName + ' data ON ' + @JoinKeys + ';" + " end"
Dts.TaskResult = ScriptResults.Success';


SELECT @Script as 'SqlCommand VB Script';

GO



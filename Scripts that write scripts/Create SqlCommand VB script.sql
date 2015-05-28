USE [GRIMM]
GO

DECLARE @Table VARCHAR(MAX)
SET @Table = 'BreakfastMenuFoodItem';

DECLARE @TableName VARCHAR(MAX)
SET @TableName = @Table;

DECLARE @SrcSchema VARCHAR(MAX)
SET @SrcSchema = 'dbo';

DECLARE @DestSchema VARCHAR(MAX)
SET @DestSchema = 'dbo';


DECLARE @InsertColumns VARCHAR(MAX)
SELECT @InsertColumns = COALESCE(@InsertColumns + ', ', '') + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @Table;

DECLARE @IsNullKeys VARCHAR(MAX)
SELECT @IsNullKeys = COALESCE(@IsNullKeys + '', '') + 'ISNULL(data.' + [COLUMN_NAME] + ', TableCT.' + [COLUMN_NAME] + ')' + [COLUMN_NAME] + ', '
FROM [INFORMATION_SCHEMA].[KEY_COLUMN_USAGE]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @Table;

DECLARE @DataColumns VARCHAR(MAX)
SELECT @DataColumns = COALESCE(@DataColumns + '', '') + 'data.' + [COLUMN_NAME] + ', '
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @Table
AND [COLUMN_NAME] NOT IN (
SELECT [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[KEY_COLUMN_USAGE]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @Table);

DECLARE @JoinKeys VARCHAR(MAX)
SELECT @JoinKeys = COALESCE(@JoinKeys + ' AND ', '') + 'data.' + [COLUMN_NAME] + ' = TableCT.' + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[KEY_COLUMN_USAGE]
WHERE [TABLE_SCHEMA] = @DestSchema
AND [TABLE_NAME] = @Table;

DECLARE @Columns VARCHAR(MAX)
SELECT @Columns = COALESCE(@Columns, '') + '[' + [COLUMN_NAME] + '], '
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_NAME] = @TableName
AND [TABLE_SCHEMA] = @DestSchema;


Declare @Script VARCHAR(MAX)
SET @Script = 
'"if 1=0 begin SELECT TOP 1 '+ @Columns + 'convert(nchar(1), ''I'') collate Latin1_General_BIN as [SYS_CHANGE_OPERATION] FROM [' + @SrcSchema + '].[' + @TableName + '] end " +
" else begin select ' + @IsNullKeys + @DataColumns + 'TableCT.SYS_CHANGE_OPERATION" +
" FROM CHANGETABLE(CHANGES ' + @SrcSchema + '.' + @TableName + ', " + (DT_WSTR, 100) @[User::LastSyncVersion] + ") TableCT" +
" left JOIN ' + @SrcSchema + '.' + @TableName + ' data ON ' + @JoinKeys + '
WHERE TableCT.SYS_CHANGE_CONTEXT IS NULL OR TableCT.SYS_CHANGE_CONTEXT <> CAST (''" + @[User::LocalContext] + "'' AS varbinary(128));" + " end"';

SELECT @Script AS 'HERE IS YOUR SCRIPT GOOD SIR OR MADAM';


--'Dts.Variables("User::SqlCommand").Value = " DECLARE @LastSyncVersion bigint =" + Dts.Variables("User::LastSyncVersion").Value.ToString() +
--" Declare @CT_MinValidVersion BIGINT = ISNULL(CHANGE_TRACKING_MIN_VALID_VERSION(OBJECT_ID(''' + @SrcSchema + '.' + @TableName + ''')),0) " +
--" IF @LastSyncVersion=-1 OR (@LastSyncVersion < @CT_MinValidVersion and @LastSyncVersion<>0) " + " begin" +
--" select ' + @InsertColumns + ', convert(bit, " + Dts.Variables("User::bArchive").Value.ToString() + ") as IsArchive, convert(nchar(1), ''I'') collate Latin1_General_BIN as SYS_CHANGE_OPERATION" +
--" from ' + @SrcSchema + '.' + @TableName + ';" + " end" + " ELSE" + " begin" +
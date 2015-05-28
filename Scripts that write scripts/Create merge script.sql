USE [GRIMM]
GO

DECLARE @Table VARCHAR(MAX)
SET @Table = 'Reservation';

DECLARE @Schema VARCHAR(MAX)
SET @Schema = 'dbo';

DECLARE @Keys VARCHAR(MAX)
SELECT @Keys = COALESCE(@Keys + ' AND ', '') + 'target.' + [COLUMN_NAME] + ' = source.' + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @Table
AND [ORDINAL_POSITION] = 1;

DECLARE @UpdateColumns VARCHAR(MAX)
SELECT @UpdateColumns = COALESCE(@UpdateColumns + ',
', '') + '		target.' + [COLUMN_NAME] + '		=source.' + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @Table
AND [ORDINAL_POSITION] <> 1;

DECLARE @InsertColumns VARCHAR(MAX)
SELECT @InsertColumns = COALESCE(@InsertColumns + ', ', '') + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @Table

DECLARE @ValuesColumns VARCHAR(MAX)
SELECT @ValuesColumns = COALESCE(@ValuesColumns + ', ', '') + 'source.' + [COLUMN_NAME]
FROM [INFORMATION_SCHEMA].[COLUMNS]
WHERE [TABLE_SCHEMA] = @Schema
AND [TABLE_NAME] = @Table

Declare @Script VARCHAR(MAX)
SET @Script = 'USE [GRIMM]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [stage].[merge' + @Table + ']
	@remoteContext varchar(100)
AS
	BEGIN
	DECLARE @remote_id varbinary(128); 
	SELECT @remote_id = CAST(@remoteContext AS varbinary(128)); 
	
	SET IDENTITY_INSERT ' + @Schema + '.' + @Table + ' ON; 
	
	WITH CHANGE_TRACKING_CONTEXT (@remote_id)
	merge ' + @Schema + '.' + @Table + ' as target
	using stage.' + @Table + ' as source on ' + @Keys +'

	when matched and source.SYS_CHANGE_OPERATION in (''U'', ''I'') then
	UPDATE SET
' + @UpdateColumns + '
	when not matched and source.SYS_CHANGE_OPERATION in (''U'', ''I'') then
		insert (' + @InsertColumns + ')
		values(' + @ValuesColumns + ')

	when matched and source.SYS_CHANGE_OPERATION = ''D'' then
		delete
;
	SET IDENTITY_INSERT ' + @Schema + '.' + @Table + ' OFF;
	END
;
GO'

SELECT @Script as 'Script'

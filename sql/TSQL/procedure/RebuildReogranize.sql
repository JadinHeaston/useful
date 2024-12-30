USE DatabaseName;

DECLARE @DatabaseName NVARCHAR(MAX) = '';

DECLARE @IndexName NVARCHAR(MAX);

DECLARE @TableName NVARCHAR(MAX);

DECLARE @CurrentIndexName NVARCHAR(MAX);

DECLARE @CurrentTableName NVARCHAR(MAX);

DECLARE @CurrentRemediation NVARCHAR(MAX);

DECLARE @CmdRemediate NVARCHAR(MAX);

DECLARE @CmdReorganize NVARCHAR(MAX) = 'REORGANIZE';

DECLARE @CmdRebuild NVARCHAR(MAX) = 'REBUILD PARTITION = ALL WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)';

/*
 Displaying index statistics.
 */
DECLARE @tempIndexTable TABLE (
	RowID int NOT NULL PRIMARY KEY identity(1, 1),
	IndexName NVARCHAR(MAX),
	IndexType NVARCHAR(MAX),
	TableName NVARCHAR(MAX),
	AvgFragmentationInPercent FLOAT,
	ObjectTypeDescription NVARCHAR(MAX),
	index_size_mb FLOAT,
	remediation NVARCHAR(MAX)
);

INSERT INTO
	@tempIndexTable (
		IndexName,
		IndexType,
		TableName,
		AvgFragmentationInPercent,
		ObjectTypeDescription,
		index_size_mb,
		remediation
	) (
		SELECT
			i.[name],
			s.[index_type_desc],
			o.[name],
			s.[avg_fragmentation_in_percent],
			o.[type_desc],
			(CAST(s.page_count AS float) * CAST(8 AS float)) / CAST(1000 AS float) AS index_size_mb,
			CASE
				WHEN s.page_count > 32
				AND s.[avg_fragmentation_in_percent] > 10
				AND s.[avg_fragmentation_in_percent] < 30 THEN 'REORGANIZE'
				WHEN s.page_count > 32
				AND s.[avg_fragmentation_in_percent] > 30 THEN 'REBUILD'
				ELSE NULL
			END AS remediation
		FROM
			sys.[dm_db_index_physical_stats] (DB_ID(@DatabaseName), NULL, NULL, NULL, NULL) AS s
			INNER JOIN sys.[indexes] AS i ON s.[object_id] = i.[object_id]
			AND s.[index_id] = i.[index_id]
			INNER JOIN sys.[objects] AS o ON i.[object_id] = o.[object_id]
		WHERE
			(
				s.[avg_fragmentation_in_percent] > 10
				AND (
					i.[Name] LIKE '%IX%'
					OR i.[Name] LIKE '%PK%'
				)
			)
	);

PRINT 'Initial Indexes: ';

SELECT
	*
FROM
	@tempIndexTable
ORDER BY
	[AvgFragmentationInPercent] DESC;

/*
 Performing remediation. Comment the RETURN; to run this portion.
 */
RETURN;

DECLARE @totalCount INTEGER;

SELECT
	@totalCount = count(1)
FROM
	@tempIndexTable;

DECLARE @counter INTEGER = 1;

WHILE(@counter <= @totalCount) BEGIN
SET
	@CurrentIndexName = (
		SELECT
			top 1 [IndexName]
		FROM
			@tempIndexTable
		WHERE
			[RowID] = @counter
	);

SET
	@CurrentTableName = (
		SELECT
			top 1 [TableName]
		FROM
			@tempIndexTable
		WHERE
			[RowID] = @counter
	);

SET
	@CurrentRemediation = (
		SELECT
			top 1 [remediation]
		FROM
			@tempIndexTable
		WHERE
			[RowID] = @counter
	);

BEGIN TRY PRINT 'Remediation (' + @CurrentRemediation + ') starting [' + @CurrentIndexName + '] ON [' + @CurrentTableName + '] at ' + CONVERT(varchar, getdate(), 121);

IF @CurrentRemediation = 'REORGANIZE'
SET
	@CmdRemediate = 'ALTER INDEX [' + @CurrentIndexName + '] ON [' + @CurrentTableName + '] ' + @CmdReorganize;

IF @CurrentRemediation = 'REBUILD'
SET
	@CmdRemediate = 'ALTER INDEX [' + @CurrentIndexName + '] ON [' + @CurrentTableName + '] ' + @CmdRebuild;

EXEC (@CmdRemediate);

PRINT 'Remediation (' + @CurrentRemediation + ') executed [' + @CurrentIndexName + '] ON [' + @CurrentTableName + '] at ' + CONVERT(varchar, getdate(), 121);

END TRY BEGIN CATCH;

PRINT 'Failed to remediate (' + @CurrentRemediation + ') [' + @CurrentIndexName + '] ON [' + @CurrentTableName + ']';

PRINT ERROR_MESSAGE();

END CATCH;

SET
	@counter = @counter + 1;

END;

/*
 Displaying updated index statistics.
 */
DELETE FROM
	@tempIndexTable
INSERT INTO
	@tempIndexTable (
		IndexName,
		IndexType,
		TableName,
		AvgFragmentationInPercent,
		ObjectTypeDescription,
		index_size_mb,
		remediation
	) (
		SELECT
			i.[name],
			s.[index_type_desc],
			o.[name],
			s.[avg_fragmentation_in_percent],
			o.[type_desc],
			(CAST(s.page_count AS float) * CAST(8 AS float)) / CAST(1000 AS float) AS index_size_mb,
			CASE
				WHEN s.page_count > 32
				AND s.[avg_fragmentation_in_percent] > 10
				AND s.[avg_fragmentation_in_percent] < 30 THEN 'REORGANIZE'
				WHEN s.page_count > 32
				AND s.[avg_fragmentation_in_percent] > 30 THEN 'REBUILD'
				ELSE NULL
			END AS remediation
		FROM
			sys.[dm_db_index_physical_stats] (DB_ID(@DatabaseName), NULL, NULL, NULL, NULL) AS s
			INNER JOIN sys.[indexes] AS i ON s.[object_id] = i.[object_id]
			AND s.[index_id] = i.[index_id]
			INNER JOIN sys.[objects] AS o ON i.[object_id] = o.[object_id]
		WHERE
			(
				s.[avg_fragmentation_in_percent] > 10
				AND (
					i.[Name] LIKE '%IX%'
					OR i.[Name] LIKE '%PK%'
				)
			)
	);

SELECT
	*
FROM
	@tempIndexTable
ORDER BY
	[AvgFragmentationInPercent] DESC;
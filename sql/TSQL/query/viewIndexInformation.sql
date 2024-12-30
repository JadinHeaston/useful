USE DatabaseName;

DECLARE @DatabaseName NVARCHAR(MAX) = DatabaseName;

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
		i.[Name] LIKE '%IX%'
		OR i.[Name] LIKE '%PK%'
	)
ORDER BY
	s.[avg_fragmentation_in_percent] DESC;
SELECT
	[column],
	COUNT(*) AS Count
FROM
	TABLE
GROUP BY
	[column]
HAVING
	COUNT(*) > 1;
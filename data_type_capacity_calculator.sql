SELECT * FROM
(
	SELECT T.TABLE_SCHEMA AS 'database', T.TABLE_NAME AS 'table', C.COLUMN_NAME AS 'column', C.DATA_TYPE AS 'data_type', T.AUTO_INCREMENT - 1 AS 'latest_id',
	CASE
        WHEN C.DATA_TYPE = 'bigint'  			THEN ROUND( (T.AUTO_INCREMENT * 100) / 18446744073709551615, 0)
		WHEN C.DATA_TYPE IN ('int', 'integer')  THEN ROUND( (T.AUTO_INCREMENT * 100) / 4294967295, 0)
		WHEN C.DATA_TYPE ='mediumint'  			THEN ROUND( (T.AUTO_INCREMENT * 100) / 16777215, 0)
		WHEN C.DATA_TYPE = 'smallint'  			THEN ROUND( (T.AUTO_INCREMENT * 100) / 65535, 0)
		WHEN C.DATA_TYPE = 'tinyint'  			THEN ROUND( (T.AUTO_INCREMENT * 100) / 255, 0)
	END AS 'percentage_of_capacity'
	 FROM  
		INFORMATION_SCHEMA.TABLES AS T
			INNER JOIN
		INFORMATION_SCHEMA.COLUMNS AS C
	ON T.TABLE_NAME = C.TABLE_NAME
	WHERE T.AUTO_INCREMENT IS NOT NULL AND C.EXTRA LIKE "%auto_increment%"
) AS auto_increment_columns
WHERE auto_increment_columns.percentage_of_capacity > 95;
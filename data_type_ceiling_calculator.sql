USE sys;
DROP PROCEDURE IF EXISTS auto_increment_limit_calculator;

DELIMITER $$
CREATE PROCEDURE auto_increment_limit_calculator(
	IN ALERT_THRESHOLD TINYINT UNSIGNED
)
BEGIN


    DECLARE done INT DEFAULT 0;
    DECLARE DB VARCHAR(64); -- DATABASE
    DECLARE T VARCHAR(64); -- TABLE
    DECLARE C VARCHAR(64); -- COLUMN
    DECLARE DT longtext; -- DATA_TYPE
	DECLARE MAX_INT BIGINT UNSIGNED DEFAULT 0;
    DECLARE column_cursor CURSOR FOR 
        SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME , DATA_TYPE
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE EXTRA LIKE "%auto_increment%";
    DECLARE CONTINUE HANDLER FOR NOT FOUND 
        SET done = 1;
	
	SET @THRESHOLD := IFNULL(ALERT_THRESHOLD, 0);
	-- Even though argument must be unsigned/positive, a negative check is done because of author's sanity
    IF @THRESHOLD < 0 OR @THRESHOLD >= 100 THEN
		SET @ERROR_MESSAGE := CONCAT(ALERT_THRESHOLD, ' is out of bounds: expected integer from 0 t0 99 inclusive.');
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = @ERROR_MESSAGE;
	END IF;


	-- Save OUTPUT in TEMPORARY TABLE
	DROP TABLE IF EXISTS OUT_TEMP;
    CREATE TEMPORARY TABLE OUT_TEMP( DB VARCHAR(64), T VARCHAR(64), C VARCHAR(64), Capacity TINYINT UNSIGNED);

    OPEN column_cursor;
      
    column_loop: LOOP
        SET done = 0; -- the default value 0 gets changed somehow, so it is explicitly set at the start of each iteration
        FETCH column_cursor INTO DB, T, C, DT;
        IF done THEN
            LEAVE column_loop;
        END IF;
		SET @query_on_last_id_string := CONCAT(
				'SELECT ',
				C,
				' INTO @LAST_ID FROM ',
				DB,
				'.',
				T,
				' ORDER BY ',
				C,
				' DESC LIMIT 1;'
		);
        PREPARE query_on_last_id FROM @query_on_last_id_string;
        EXECUTE query_on_last_id; -- OUTPUTs to variable @LAST_ID
        DEALLOCATE PREPARE query_on_last_id;

        CASE DT
			-- ALL max values are based on UNSIGNED maximums for DATA_TYPE
			WHEN 'mediumint' THEN 
				SET MAX_INT = 16777215;
			WHEN 'int' THEN
				SET MAX_INT = 4294967295;
			WHEN 'integer' THEN
				SET MAX_INT = 4294967295;
			WHEN 'bigint' THEN
				SET MAX_INT = 18446744073709551615;
		END CASE;
		-- Calculate percentage (rounded to nearest integer) of capacity taken via the ratio of (Biggest current ID) / (Largest possible ID)
        SET @CAPACITY := (SELECT ROUND( (@LAST_ID / MAX_INT) * 100, 0));
		-- THRESHOLD = 0 effectively turns off THRESHOLD since lowest value is 0
		IF @CAPACITY >= @THRESHOLD THEN
			INSERT INTO OUT_TEMP (DB, T, C, Capacity) VALUES (DB, T, C, @CAPACITY);
		END IF;

    END LOOP;

    CLOSE column_cursor;

	-- OUTPUT all results which is already pre-filtered by THRESHOLD  
	SELECT * FROM OUT_TEMP;
	DROP TEMPORARY TABLE OUT_TEMP;

END $$
DELIMITER ;
CALL auto_increment_limit_calculator(2);
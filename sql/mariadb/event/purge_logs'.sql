DELIMITER //
CREATE EVENT purge_logs ON SCHEDULE EVERY 1 DAY STARTS '2024-05-29 20:00:00' DO BEGIN DECLARE cutoff_date DATETIME;

-- Calculate the cutoff date (1 week ago)
SET
	cutoff_date = NOW() - INTERVAL 1 WEEK;

-- Delete old logs from general_logs table
DELETE FROM
	general_logs
WHERE
	log_time < cutoff_date;

-- Delete old logs from slow_logs table
DELETE FROM
	slow_logs
WHERE
	log_time < cutoff_date;

END//
DELIMITER ;
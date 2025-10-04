-- Cleanup seeded/test data for ExiledCMS (MySQL)
-- Use with: docker exec -i mysql mysql -uroot -p$MYSQL_ROOT_PASSWORD ${DB_NAME:-exiledcms} < /path/to/cleanup_db_mysql.sql

SET
FOREIGN_KEY_CHECKS=0;
DELETE
FROM users
WHERE login IN ('admin', 'tester', 'banned');
DELETE
FROM news
WHERE id IN (1, 2, 3);
SET
FOREIGN_KEY_CHECKS=1;

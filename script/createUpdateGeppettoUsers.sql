-- Scripts to populate geppetto user table and update passwords
-- You wil have to sign in to the db: mysql -u root -p[substitute_with_db_password]
-- and executes the following scripts

-- CREATE GEPPETTO USERS
use redmine;
select login,hashed_password from users INTO OUTFILE '/tmp/redmineusers.csv' FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n';
use geppetto;
LOAD DATA INFILE '/tmp/redmineusers.csv' INTO TABLE USER FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' (@col1,@col2) set login=@col1,name=@col1,password=@col2;
INSERT INTO USER (login,name,password) VALUES ('osbanonymous','osbanonymous',[substitute_with_anonymous_user_password]);


-- UPDATE GEPPETTO USERS
use redmine;
select login,hashed_password from users INTO OUTFILE '/tmp/redmineusers.csv' FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n';
use geppetto;
CREATE TEMPORARY TABLE TEMP_USER LIKE USER;
LOAD DATA INFILE '/tmp/redmineusers.csv' INTO TABLE TEMP_USER FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' (@col1,@col2) set login=@col1,name=@col1,password=@col2;
UPDATE USER INNER JOIN TEMP_USER on TEMP_USER.login = USER.login SET USER.password = TEMP_USER.password;
DROP TEMPORARY TABLE TEMP_USER;
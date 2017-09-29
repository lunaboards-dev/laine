CREATE DATABASE `{{dbname}}` DEFAULT CHARSET=utf8 COLLATE utf8_bin;
USE {{dbname}};
CREATE TABLE posts (
	date bigint NOT NULL,
	board text NOT NULL,
	id bigint NOT NULL,
	post text NOT NULL
) ENGINE = InnoDB;
CREATE TABLE threads (
	board text NOT NULL,
	name text NOT NULL,
	id bigint NOT NULL,
	ip text NOT NULL,
	lastupdate bigint NOT NULL,
	locked BOOLEAN NOT NULL,
	pinned BOOLEAN NOT NULL,
	marked BOOLEAN NOT NULL
) ENGINE = InnoDB;
CREATE TABLE admins (
	name text NOT NULL,
	perm text NOT NULL,
	phash text NOT NULL,
	boardperm text NOT NULL,
	k text NOT NULL
) ENGINE = InnoDB;
GRANT ALL PRIVILEGES ON {{dbname}}.* TO '{{user}}'@'%' IDENTIFIED BY '{{pass}}';

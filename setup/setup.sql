DROP DATABASE laine;
CREATE DATABASE laine;
USE laine;
CREATE TABLE posts (
	date bigint,
	board text,
	id bigint,
	post text
);
CREATE TABLE threads (
	board text,
	name text,
	id biginit,
	ip text,
	lastupdate bigint,
	locked tinyint(1),
	pinned tinyint(1),
	marked tinyint(1)
);
CREATE TABLE admins (
	name text,
	perm text,
	phash text,
	boardperm text,
	k text
);

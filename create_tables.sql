-- Database schema creation script for ExiledProject CMS
USE
exiledcms;

-- Drop existing tables if they exist (for fresh start)
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS news;

-- Create users table
CREATE TABLE users
(
    Id               CHAR(36)     NOT NULL PRIMARY KEY,
    Login            VARCHAR(64)  NOT NULL UNIQUE,
    PasswordHash     VARCHAR(200) NOT NULL,
    PasswordSalt     VARCHAR(200) NOT NULL,
    Require2FA       TINYINT(1) NOT NULL DEFAULT 0,
    IsBanned         TINYINT(1) NOT NULL DEFAULT 0,
    BanReason        VARCHAR(512),
    UserUuid         CHAR(36)     NOT NULL,
    TwoFactorSecret  VARCHAR(200),
    TwoFactorEnabled TINYINT(1) NOT NULL DEFAULT 0,
    MustSetup2FA     TINYINT(1) NOT NULL DEFAULT 1
);

-- Create news table
CREATE TABLE news
(
    Id          INT AUTO_INCREMENT PRIMARY KEY,
    Title       VARCHAR(200)  NOT NULL,
    Description VARCHAR(4000) NOT NULL,
    CreatedAt   DATETIME      NOT NULL
);

-- This script creates the tables but does not insert users.
-- The application will seed the users automatically when it starts
-- and the tables exist. This allows proper password hashing.
-- Day 07: schema for the application. Database: LearnInsuranceDB, schema: learninsurancedb
-- (unquoted identifiers fold to lower case, so LearnInsuranceDB.* and learninsurancedb.* are the same schema).
CREATE SCHEMA IF NOT EXISTS learninsurancedb;
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_salt / crypt for the seeded admin password (bcrypt)

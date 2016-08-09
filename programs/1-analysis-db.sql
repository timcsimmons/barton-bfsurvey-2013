------------------------------------------------------------------------
-- Program: 1-analysis-db.sql
-- Directory: bfsurvey/programs
-- Project: Breastfeeding survey analysis
-- Author: Tim Simmons
--
-- Purpose:
-- Notes:
--   Run from a temporary sqlite3 session in this directory using
--   .read setup.sql
--   .read 1-analysis-db.sql
------------------------------------------------------------------------


ATTACH DATABASE '../data/survey.sqlite3' AS raw;


DROP TABLE IF EXISTS survey;
CREATE TABLE survey(
      RespondentID INTEGER PRIMARY KEY
    , sex INTEGER
    , age_yc INTEGER
    , bf_status INTEGER
    , age_mother INTEGER
    , AP BOOLEAN
    , AP_reason INTEGER
);



-- Recode year of birth
DROP TABLE IF EXISTS yob;
CREATE TABLE yob(year INTEGER, BIRTH_YEAR TEXT);
INSERT INTO yob(BIRTH_YEAR)
SELECT DISTINCT BIRTH_YEAR
FROM raw.BFSURVEY_ALL
ORDER BY 1
;

UPDATE yob
SET year = BIRTH_YEAR
WHERE length(BIRTH_YEAR) = 4
    AND SUBSTR(BIRTH_YEAR, 1, 2) IN ('19', '20')
;

UPDATE yob
SET year = NULL
WHERE year = ''
;

UPDATE yob SET year = 1978 WHERE BIRTH_YEAR = '1078';
UPDATE yob SET year = 1980 WHERE BIRTH_YEAR = '1080';
UPDATE yob SET year = 1982 WHERE BIRTH_YEAR = '1082';
UPDATE yob SET year = 1982 WHERE BIRTH_YEAR = '1882';
UPDATE yob SET year = 1994 WHERE BIRTH_YEAR = '1894';
UPDATE yob SET year = 1976 WHERE BIRTH_YEAR = '1976  LOL!';
UPDATE yob SET year = 1980 WHERE BIRTH_YEAR = '2980';
UPDATE yob SET year = 1982 WHERE BIRTH_YEAR = '3-30-1982';




INSERT INTO survey(RespondentId, sex, age_yc, bf_status, age_mother)
SELECT s.RespondentID
    , s.SEX AS sex
    , s.AGE_YC AS age_yc
    , s.BF_STATUS AS bf_status

    -- The minimum possible age of mother based on self-reported
    -- year of birth
    , 2013 - yob.year - 1 AS age_mother
FROM raw.BFSURVEY_ALL AS s
    LEFT JOIN yob
        ON s.BIRTH_YEAR = yob.BIRTH_YEAR
;


DROP TABLE yob;

-- Derive analysis population

DROP TABLE IF EXISTS codes.AP_reason;

CREATE TABLE codes.AP_reason(Code INTEGER, Description TEXT);
INSERT INTO codes.AP_reason(Code, Description) VALUES
      (1, 'Respondent was male')
    , (2, 'Youngest child older than 18 months')
    , (3, 'Youngest child weaned more than 18 months ago')
    , (4, 'Youngest child never breastfed')
    , (5, 'Respondent not confirmed 18 years or older');


UPDATE survey
SET AP_reason =
    CASE
      WHEN sex = 2 AND age_yc = 1 AND bf_status IN (1, 2)
              AND age_mother >= 18
	  THEN 0
      WHEN sex <> 2 THEN 1
      WHEN age_yc <> 1 THEN 2
      WHEN bf_status = 3 THEN 3
      WHEN bf_status = 4 THEN 4
      WHEN age_mother < 18 OR age_mother IS NULL THEN 5
      ELSE NULL
    END
;

UPDATE survey
SET AP = CASE WHEN AP_reason = 0 THEN 1 ELSE 0 END
;



-- Store codes used for the main table
DROP TABLE IF EXISTS codes.sex;

CREATE TABLE codes.sex AS
SELECT Code, Description
FROM raw.SEX
;

DROP TABLE IF EXISTS codes.age_yc;

CREATE TABLE codes.age_yc AS
SELECT Code, Description
FROM raw.AGE_YC
;

DROP TABLE IF EXISTS codes.bf_status;

CREATE TABLE codes.bf_status AS
SELECT Code, Description
FROM raw.BF_STATUS
;



DETACH DATABASE raw;

.save '../data/analysis.sqlite3'

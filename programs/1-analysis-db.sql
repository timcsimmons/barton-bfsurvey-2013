-- -*- mode: sql; sql-product: sqlite; -*-

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





DROP TABLE IF EXISTS survey;
CREATE TABLE survey(
      RespondentID INTEGER PRIMARY KEY

    , start_date

    -- Inclusion criteria
    , sex INTEGER
    , age_yc INTEGER
    , bf_status INTEGER
    , age_mother INTEGER

    -- Demographics and populations
    , race INTEGER
    , ethnicity INTEGER
    , education INTEGER
    , income INTEGER
    , marital_status INTEGER
    , AP BOOLEAN
    , AP_reason INTEGER
    , pumper INTEGER

    -- Covariates
    , height FLOAT
    , weight FLOAT
    , bmi FLOAT
    , bmi_category INTEGER
    , metformin INTEGER
    , BC_pills INTEGER
    , BC_age INTEGER
    , heart_surgery INTEGER
    , chest_injury INTEGER
    , breast_any_procedure INTEGER
    , breast_procedures TEXT
    , transfusion INTEGER
    , hemorrhage INTEGER
    , diabetes_1 INTEGER
    , diabetes_2 INTEGER
    , diabetes_g INTEGER
    , POS INTEGER
    , thyroid INTEGER
    , depression INTEGER
    , breast_type INTEGER
    , menarche INTEGER
    , irregular_period INTEGER
    , breast_change INTEGER
    , conception INTEGER
    , natural_conception INTEGER
    , delivery_mode INTEGER
    , baby_gestational_age FLOAT
    , baby_healthy INTEGER
    , baby_tongue_tie INTEGER
    , first_bf INTEGER
    , baby_in_bed INTEGER
    , pacifier INTEGER
    , swaddle INTEGER
    , baby_formula INTEGER
    , solid_food INTEGER

    -- Exposures
    , bc_NFP
    , bc_barrier
    , bc_copper_IUD
    , bc_hormonal_IUD
    , bc_progestin_pill
    , bc_combination_pill
    , bc_patch
    , bc_implant
    , bc_shot
    , bc_ring
    , bc_other

    -- Outcomes
    , milk_supply INTEGER
    , low_milk_supply INTEGER
);




------------------------------------------------------------------------
-- Create lookup tables for recoding
------------------------------------------------------------------------

DROP TABLE IF EXISTS codes.pumper;
CREATE TABLE codes.pumper(Code INTEGER, Description TEXT);
INSERT INTO codes.pumper(Code, Description) VALUES
      (1, 'Expressed milk to feed baby in first six months of life')
    , (0, 'Did not express milk to feed baby in first six months of life');

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

-- Recode race and ethnicity
DROP TABLE IF EXISTS codes.race;
CREATE TABLE codes.race AS
SELECT Code, Description
FROM raw.RACE
;

DROP TABLE IF EXISTS codes.ethnicity;
CREATE TABLE codes.ethnicity(Code INTEGER, raw_Code TEXT, Description TEXT);
INSERT INTO codes.ethnicity VALUES
      (1, 'HISPANIC', 'Hispanic or Latino')
    , (2, 'NOT HISPANIC', 'Not Hispanic or Latino');


DROP TABLE IF EXISTS codes.income;
CREATE TABLE codes.income AS
SELECT Code, Description
FROM raw.INCOME
;


-- Recode height
DROP TABLE IF EXISTS codes.height;
CREATE TABLE codes.height(Code FLOAT, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.height(raw_Code, Description)
SELECT Code, Description
FROM raw.MOTHER_HEIGHT
;

-- Each code represents an inch and 1 corresponds to "under 4'11" This
-- recoding then matches the true height in inches except at the
-- endpoints where it is one below the lower limit and one above the
-- upper.
UPDATE codes.height
SET Code = (raw_Code - 1) + 4*12 + 10
;


DROP TABLE IF EXISTS codes.marital_status;
CREATE TABLE codes.marital_status(
    Code INTEGER,
    Description TEXT
);
INSERT INTO marital_status(Code, Description)
SELECT Code, Description FROM raw.MARRIED UNION
SELECT Code, Description FROM raw.WIDOWED UNION
SELECT Code, Description FROM raw.DIVORCED UNION
SELECT Code, Description FROM raw.SEPARATED UNION
SELECT Code, Description FROM raw.NEV_MARRIED
;

DROP TABLE IF EXISTS marital;
CREATE TABLE marital(RespondentID INTEGER, status INTEGER);

WITH cte_marital AS (
    SELECT RespondentID, MARRIED AS status
    FROM raw.BFSURVEY_ALL
        UNION
    SELECT RespondentID, WIDOWED AS status
    FROM raw.BFSURVEY_ALL
        UNION
    SELECT RespondentID, DIVORCED AS status
    FROM raw.BFSURVEY_ALL
        UNION
    SELECT RespondentID, SEPARATED AS status
    FROM raw.BFSURVEY_ALL
        UNION
    SELECT RespondentID, NEV_MARRIED AS status
    FROM raw.BFSURVEY_ALL
)
INSERT INTO marital
SELECT RespondentID, MIN(status) AS status
FROM cte_marital
WHERE status IS NOT NULL
GROUP BY RespondentID
;


DROP TABLE IF EXISTS codes.metformin;
CREATE TABLE codes.metformin(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.metformin(raw_Code, Description)
SELECT Code, Description
FROM raw.METFORMIN
;

UPDATE codes.metformin
SET Code =
    CASE Description
      WHEN 'Yes' THEN 1
      WHEN 'No'  THEN 0
      ELSE NULL
    END
;

DROP TABLE IF EXISTS codes.BC_pills;
CREATE TABLE codes.BC_pills(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.BC_pills VALUES
      (1, 0, 'Yes')
    , (0, 1, 'No');


-- Recode age when first used birth control pills (entered as free text).
-- Use the lower limit when a range is provided.
DROP TABLE IF EXISTS codes.BC_age;
CREATE TABLE codes.BC_age(Code INTEGER, Description TEXT);
INSERT INTO codes.BC_age(Code, Description) VALUES
      (NULL, '')
    , (18, '18')
    , (16, '16')
    , (17, '17')
    , (19, '19')
    , (15, '15')
    , (20, '20')
    , (21, '21')
    , (14, '14')
    , (22, '22')
    , (23, '23')
    , (24, '24')
    , (13, '13')
    , (25, '25')
    , (26, '26')
    , (12, '12')
    , (27, '27')
    , (28, '28')
    , (30, '30')
    , (29, '29')
    , (11, '11')
    , (18, '18 years')
    , (NULL, '20''s')
    , (33, '33')
    , (10, '10')
    , (14, '14 years old')
    , (16, '16 years')
    , (16, '16 yrs')
    , (17, '17?')
    , (18, '18-19')
    , (18, '18-20')
    , (19, '19 years')
    , (20, '20 years old')
    , (31, '31')
    , (35, '35')
    , (30, '.30')
    , (12, '12 - to regulate my periods')
    , (12, '12, irregular period')
    , (12, '12-16')
    , (14, '14, stoped at 19')
    , (14, '14- for acne and heavy menstrual cycles')
    , (14, '14-18')
    , (15, '15 but I haven''t taken them in 15 years since.')
    , (15, '15 yrs old')
    , (15, '15-19')
    , (15, '15-20 on and off. Allergic.')
    , (15, '15ish')
    , (16, '16 and never again')
    , (16, '16 but only for a year')
    , (16, '16 maybe. But I haven''t taken them in 10 years')
    , (16, '16 or 17')
    , (16, '16 started done @18')
    , (16, '16 stopped taking birth control then stopped due to pregnancy and still not taking any form of birth control due to breastfeeding')
    , (16, '16- only took them for a few months tho')
    , (16, '16-18')
    , (16, '16-24')
    , (16, '16.  Stopped at 16 too')
    , (17, '17 but only for a five Month peirod.')
    , (17, '17 for skin for 3 months then 21.')
    , (17, '17 or 18')
    , (17, '17 years old')
    , (18, '18 (1 month only)')
    , (18, '18 (stopped after 4 mths, never took again)')
    , (18, '18 but stopped at 20 put iud I and taken out in 2011 got pregnant and now on depo')
    , (18, '18 dont take anymore')
    , (18, '18 only took for  few months')
    , (18, '18 years old yaz, then 21 levin')
    , (18, '18 yrs')
    , (18, '18 yrs old')
    , (18, '18-20 years old')
    , (NULL, '183')
    , (18, '18?  Don''t remember. Did not use them long term.')
    , (18, '18? Maybe?')
    , (19, '19 (for 9 months only then never again)')
    , (19, '19 - didn''t last long')
    , (19, '19 but didn''t take from 23-29')
    , (19, '19yrs old for 3 months only')
    , (NULL, '1i')
    , (NULL, '1year')
    , (20, '20 (only took them for 4 months)')
    , (20, '20 ish')
    , (20, '20 y/o')
    , (20, '20''')
    , (20, '20, only for 6 months or so')
    , (20, '20.')
    , (20, '200')
    , (20, '20ish')
    , (NULL, '20s')
    , (21, '21 - used Nuvaring not pills')
    , (21, '21 only for a couple months')
    , (21, '21 only for about 2 yrs')
    , (21, '21yts old')
    , (22, '22 Nuva ring')
    , (22, '22 but not for long due to side effects')
    , (22, '22 years')
    , (22, '22, for about 6 montgs')
    , (22, '22- for 1.5 yrs')
    , (22, '22-23')
    , (24, '24 & only took the pill for a few months')
    , (24, '24. Only for 1 month to control bleeding after my son''s birth')
    , (25, '25-26')
    , (25, '25?')
    , (27, '27 (mini pill for 1 month & stopped)')
    , (27, '27 after birth my first child')
    , (28, '28 and I only took them for one year')
    , (NULL, '2w')
    , (32, '32')
    , (36, '36')
    , (NULL, '?')
    , (13, 'Age 13-18')
    , (14, 'Age 14-22 on and off')
    , (17, 'Age 17-19')
    , (21, 'Age 21-28')
    , (29, 'College, maybe 20?')
    , (NULL, 'Early 20s')
    , (21, 'For one year when I was 21')
    , (NULL, 'I don''t remember.')
    , (18, 'I8')
    , (NULL, 'In my 20s')
    , (NULL, 'Loestrine')
    , (NULL, 'Not sure')
    , (20, 'Once at 20')
    , (18, 'Only for a year when I was 18')
    , (NULL, 'Ortho tri cyclin')
    , (NULL, 'Twenty something')
    , (NULL, 'Unsure')
    , (25, 'Well I get the depo shot. 25')
    , (NULL, 'Yaz, estrostep, nuvaring')
    , (14, 'age 14 to 21')
    , (22, 'for 1 month when i was 22')
    , (25, 'iud - 25')
    , (NULL, 'only for 1 month for ivf');


DROP TABLE IF EXISTS codes.heart_surgery;
CREATE TABLE codes.heart_surgery(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.heart_surgery VALUES
      (1, 1, 'Heart surgery')
    , (0, NULL, 'No heart surgery');

DROP TABLE IF EXISTS codes.chest_injury;
CREATE TABLE codes.chest_injury(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.chest_injury(Code, raw_Code, Description) VALUES
      (1, 2, 'Chest injury')
    , (0, NULL, 'No chest injury');


DROP TABLE IF EXISTS codes.breast_procedures;
CREATE TABLE codes.breast_procedures(Code INTEGER, Description TEXT);
INSERT INTO codes.breast_procedures
SELECT Code, Description FROM raw.BREAST_BIOPSY_ONE UNION
SELECT Code, Description FROM raw.BREAST_BIOPSY_BOTH UNION
SELECT Code, Description FROM raw.LUMPECTOMY_ONE UNION
SELECT Code, Description FROM raw.LUMPECTOMY_BOTH UNION
SELECT Code, Description FROM raw.BREAST_REDUC UNION
SELECT Code, Description FROM raw.BREAST_IMPLANT UNION
SELECT Code, Description FROM raw.MAST_ONE UNION
SELECT Code, Description FROM raw.MAST_BOTH UNION
SELECT Code, Description FROM raw.RADIATION_ONE UNION
SELECT Code, Description FROM raw.RADIATION_BOTH UNION
SELECT Code, Description FROM raw.OTHER_BREAST_SURGERY
ORDER BY 1
;

DROP TABLE IF EXISTS breast_procedures;
CREATE TABLE breast_procedures(RespondentID INTEGER, breast_procedures TEXT);

WITH cte_breast_procedures AS (
    SELECT RespondentID, BREAST_BIOPSY_ONE AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE BREAST_BIOPSY_ONE IS NOT NULL
        UNION
    SELECT RespondentID, BREAST_BIOPSY_BOTH AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE BREAST_BIOPSY_BOTH IS NOT NULL
        UNION
    SELECT RespondentID, LUMPECTOMY_ONE AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE LUMPECTOMY_ONE IS NOT NULL
        UNION
    SELECT RespondentID, LUMPECTOMY_BOTH AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE LUMPECTOMY_BOTH IS NOT NULL
        UNION
    SELECT RespondentID, BREAST_REDUC AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE BREAST_REDUC IS NOT NULL
        UNION
    SELECT RespondentID, BREAST_IMPLANT AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE BREAST_IMPLANT IS NOT NULL
        UNION
    SELECT RespondentID, MAST_ONE AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE MAST_ONE IS NOT NULL
        UNION
    SELECT RespondentID, MAST_BOTH AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE MAST_BOTH IS NOT NULL
        UNION
    SELECT RespondentID, RADIATION_ONE AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE RADIATION_ONE IS NOT NULL
        UNION
    SELECT RespondentID, RADIATION_BOTH AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE RADIATION_BOTH IS NOT NULL
        UNION
    SELECT RespondentID, OTHER_BREAST_SURGERY AS breast_procedure
    FROM raw.BFSURVEY_ALL
    WHERE OTHER_BREAST_SURGERY IS NOT NULL
)
INSERT INTO breast_procedures(RespondentID, breast_procedures)
SELECT RespondentID, GROUP_CONCAT(breast_procedure, ',') AS breast_procedures
FROM cte_breast_procedures
GROUP BY RespondentID
;


DROP TABLE IF EXISTS codes.breast_any_procedure;
CREATE TABLE codes.breast_any_procedure(Code INTEGER, Description TEXT);
INSERT INTO codes.breast_any_procedure VALUES
      (1, 'Any breast procedure')
    , (0, 'No breast procedure');


DROP TABLE IF EXISTS codes.transfusion;
CREATE TABLE codes.transfusion(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.transfusion(Code, raw_Code, Description) VALUES
      (1, 1, 'Ever needed transfusion due to excessive blood loss')
    , (0, 2, 'Never needed transfusion due to excessive blood loss');


DROP TABLE IF EXISTS codes.hemorrhage;
CREATE TABLE codes.hemorrhage(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.hemorrhage(Code, raw_Code, Description) VALUES
      (1, 1, 'Ever experienced hemorrhage or excessive bleeding after any birth')
    , (0, 2, 'Never experienced hemorrhage or excessive bleeding after any birth');

CREATE TABLE hemorrhage AS
SELECT RespondentID
    , (SELECT Code FROM codes.hemorrhage WHERE raw_Code = HEMOR_BLEED_EVER) AS bled_ever
    , (SELECT Code FROM codes.hemorrhage WHERE raw_Code = HEMORR_BLEED_CURRENT) AS bled_yc
FROM raw.BFSURVEY_ALL
;




DROP TABLE IF EXISTS codes.diabetes_1;
DROP TABLE IF EXISTS codes.diabetes_2;
DROP TABLE IF EXISTS codes.diabetes_g;
DROP TABLE IF EXISTS codes.POS;
DROP TABLE IF EXISTS codes.thyroid;
DROP TABLE IF EXISTS codes.depression;

CREATE TABLE codes.diabetes_1(Code INTEGER, raw_Code INTEGER, Description TEXT);
CREATE TABLE codes.diabetes_2(Code INTEGER, raw_Code INTEGER, Description TEXT);
CREATE TABLE codes.diabetes_g(Code INTEGER, raw_Code INTEGER, Description TEXT);
CREATE TABLE codes.POS(Code INTEGER, raw_Code INTEGER, Description TEXT);
CREATE TABLE codes.thyroid(Code INTEGER, raw_Code INTEGER, Description TEXT);
CREATE TABLE codes.depression(Code INTEGER, raw_Code INTEGER, Description TEXT);


INSERT INTO codes.diabetes_1 VALUES
      (1, 1, 'Diagnosed with type I diabetes')
    , (0, NULL, 'Not diagnosed with type I diabetes');

INSERT INTO codes.diabetes_2 VALUES
      (1, 2, 'Diagnosed with type II diabetes')
    , (0, NULL, 'Not diagnosed with type II diabetes');

INSERT INTO codes.diabetes_g VALUES
      (1, 3, 'Diagnosed with gestational diabetes')
    , (0, NULL, 'Not diagnosed with gestational diabetes');

INSERT INTO codes.POS VALUES
      (1, 4, 'Diagnosed with polycystic ovarian syndrome')
    , (0, NULL, 'Not diagnosed with polycystic ovarian syndrome');

INSERT INTO codes.thyroid VALUES
      (1, 5, 'Diagnosed with a thyroid disorder')
    , (0, NULL, 'Not diagnosed with a thyroid disorder');

INSERT INTO codes.depression VALUES
      (1, 6, 'Diagnosed with depression')
    , (0, NULL, 'Not diagnosed with depression');


DROP TABLE IF EXISTS conditions;
CREATE TABLE conditions AS
WITH cte_conditions AS (
    SELECT RespondentID, TYPE1_DIABETES AS condition
    FROM raw.BFSURVEY_ALL
    WHERE TYPE1_DIABETES IS NOT NULL
        UNION
    SELECT RespondentID, TYPE2_DIABETES AS condition
    FROM raw.BFSURVEY_ALL
    WHERE TYPE2_DIABETES IS NOT NULL
        UNION
    SELECT RespondentID, GEST_DIABETES AS condition
    FROM raw.BFSURVEY_ALL
    WHERE GEST_DIABETES IS NOT NULL
        UNION
    SELECT RespondentID, POS AS condition
    FROM raw.BFSURVEY_ALL
    WHERE POS IS NOT NULL
        UNION
    SELECT RespondentID, TYROID AS condition
    FROM raw.BFSURVEY_ALL
    WHERE TYROID IS NOT NULL
        UNION
    SELECT RespondentID, DEPRESSION AS condition
    FROM raw.BFSURVEY_ALL
    WHERE DEPRESSION IS NOT NULL
        UNION
    SELECT RespondentID, NO_DIABETES_THYROID_DEP AS condition
    FROM raw.BFSURVEY_ALL
    WHERE NO_DIABETES_THYROID_DEP IS NOT NULL
)
SELECT RespondentID
    , MAX(CASE WHEN condition = 1 THEN 1 ELSE 0 END) AS diabetes_1
    , MAX(CASE WHEN condition = 2 THEN 1 ELSE 0 END) AS diabetes_2
    , MAX(CASE WHEN condition = 3 THEN 1 ELSE 0 END) AS diabetes_g
    , MAX(CASE WHEN condition = 4 THEN 1 ELSE 0 END) AS POS
    , MAX(CASE WHEN condition = 5 THEN 1 ELSE 0 END) AS thyroid
    , MAX(CASE WHEN condition = 6 THEN 1 ELSE 0 END) AS depression
FROM cte_conditions
GROUP BY RespondentID
;



DROP TABLE IF EXISTS codes.breast_type;
CREATE TABLE codes.breast_type(Code INTEGER, Description TEXT);
INSERT INTO codes.breast_type VALUES
      (1, 'Type 1')
    , (2, 'Type 2')
    , (3, 'Type 3')
    , (4, 'Type 4')
    , (90, 'Other');


DROP TABLE IF EXISTS codes.breast_type_other;
CREATE TABLE codes.breast_type_other(Code INTEGER, Description TEXT);
INSERT INTO codes.breast_type_other VALUES
      (1, '#1 but not as perky!')
    , (2, '#2 but much bigger 40H!')
    , (2, '-like2 but bigger')
    , (1, '1 but smaller')
    , (1, '1, but bigger (D)')
    , (2, '2 but bigger')
    , (2, '2 but much larger. Shallow tops, large bottoms nipples see, to hang downward')
    , (2, '2 but much much bigger. I''m an I cup.')
    , (2, '2 longer & larger')
    , (3, '3 but bigger')
    , (3, '3 but much bigger')
    , (3, '3, but lots bigger')
    , (90, '38 DD hang low with nipples pointing down. No gap, just a lot of cleavage.')
    , (4, '4 bigger maybe flatter nipple')
    , (4, '4 but bigger')
    , (90, 'A blend between 1 and 2')
    , (90, 'A combination of type 1 and type 2')
    , (90, 'A combo of types 1 & 2 but larger')
    , (90, 'A cross between type 2 and type 1, with very small areolae.')
    , (90, 'A good degree larger')
    , (90, 'A in between of 1 n 2 more like one but not so perfect')
    , (90, 'A little bigger')
    , (90, 'As big as 1, but pointing down like 3. A mix of 1 & 3.')
    , (1, 'As round as type 1 but my nipples point down and my breasts are much larger')
    , (90, 'Before breastfeeding: type 1 After: type 2')
    , (90, 'Before my breast surgery, I had one that liked like a type 3, barely an A cup, and one that looked like a type 4, barely a B cup. After surgery obviously they look quite different but that''s irrelevant.')
    , (90, 'Between 1 and 3, large.')
    , (90, 'Between Type 1 and 2, fuller/rounder like 1, nipples more towards the bottom like 2')
    , (90, 'Between Types 1 and 2.')
    , (90, 'Between type 1 & 2-- A little more like type 2: set far apart and nipples not quite in the middle, but a little more full like type 1, especially since getting pregnant.')
    , (90, 'Between type 1 and 2 big droop down point out.')
    , (90, 'Between type 1 and 2 but bigger')
    , (90, 'Between type 1 and 2.  But larger.')
    , (90, 'Between type 1 and 3')
    , (90, 'Between types 1 and 2')
    , (90, 'But bigger')
    , (90, 'But slightly down')
    , (90, 'Can''t decide between type 2 & 3 (prior to implant surgery)')
    , (2, 'Closest to type 2, but bigger, nipples are higher')
    , (90, 'Combination of 1 & 3 but very large 38 fff')
    , (90, 'Combination of 1 (for size) and 2 (for nipple)')
    , (90, 'Combination of 1 and 2 only larger breast and nipples, nipples sort of face outwards.')
    , (90, 'Combination of type 1 and type 2')
    , (90, 'Combo between type 1 and type 3')
    , (90, 'Even and large like type 1, but nipples in more of a down position like type 4.')
    , (90, 'Full like #1 but spaced apart like #2')
    , (90, 'Full like type one, nipples like type 3')
    , (90, 'I can''t distinguish the difference between the pictures')
    , (90, 'I have IGT, but I would call my breasts snoopy breasts, large space, long bowed outside and large dark aerolas')
    , (90, 'In between Type 1 and Type 2 (smaller than 1, larger and not as droopy looking as 2)')
    , (90, 'In between type 1 and 2')
    , (90, 'In between type 1 and 2 but bigger')
    , (90, 'In-between type 1 and 2 but closer together.')
    , (90, 'Kind of a cross between type 1 and type 2... but bigger.')
    , (3, 'Kind of like type 3 but much larger.')
    , (2, 'Kinda like #2, as in the pointed downward, but bigger in size. I am a 42DDD')
    , (2, 'LIke type 2 but way bigger...nipple at the bottom of breasts')
    , (1, 'Large nipples, but like type 1')
    , (2, 'Larger than type 2')
    , (90, 'Left - type 1; right - type 3 with a spilt nipple')
    , (90, 'Left like 3, right like 2')
    , (1, 'Lik Type 1 but bigger')
    , (90, 'Like 1 and 2')
    , (1, 'Like 1 but a bit smaller')
    , (1, 'Like 1 but bigger')
    , (1, 'Like 1 but bigger and point down more')
    , (1, 'Like 1 but bigger areola')
    , (90, 'Like 1 but bigger nipples, or Like 2 but bigger.')
    , (1, 'Like 1 but larger')
    , (1, 'Like 1 but larger areola.')
    , (1, 'Like 1 but larger areolas')
    , (1, 'Like 1 but perkier')
    , (1, 'Like 1 but saggier')
    , (1, 'Like 1 with larger nipples')
    , (1, 'Like 1, but bigger')
    , (90, 'Like 1, but larger with nipples pointing down like 3. The nipples are crossed eyed.')
    , (1, 'Like 1, but saggier and pointing further down.  ;-)')
    , (2, 'Like 2 before breastfeeding but bigger now')
    , (2, 'Like 2 but bigger')
    , (2, 'Like 2 but bigger right one very much so')
    , (2, 'Like 2 but droop more')
    , (2, 'Like 2 but larger')
    , (2, 'Like 2 but larger (they used to look like type 1!)  :/')
    , (2, 'Like 2 but much larger')
    , (2, 'Like 2 but size 36 H')
    , (2, 'Like 2 but size J''s')
    , (2, 'Like 2 but slightly bigger')
    , (2, 'Like 2 but smaller')
    , (2, 'Like 2, but larger')
    , (2, 'Like 2, but much larger')
    , (2, 'Like 2, much bigger')
    , (3, 'Like 3 but bigger')
    , (3, 'Like 3 but much bigger')
    , (3, 'Like 3 but much larger')
    , (3, 'Like 3 but size D')
    , (90, 'Like 3 but the nipples point straight out like type 1, not downward.')
    , (4, 'Like 4 but bigger')
    , (1, 'Like Type 1 but bigger and bigger areolas')
    , (1, 'Like Type 1 but larger by a bunch!')
    , (1, 'Like Type 1 but left breast is larger')
    , (1, 'Like Type 1 but much bigger')
    , (1, 'Like Type 1 but my left breast is slightly larger than the right breast')
    , (1, 'Like Type 1 but smaller')
    , (1, 'Like Type 1, but bigger')
    , (1, 'Like Type 1, but larger')
    , (90, 'Like Type 1, but with the large areolas like Type 3 & 4')
    , (2, 'Like Type 2 but a bit bigger')
    , (2, 'Like Type 2 but bigger')
    , (2, 'Like Type 2 but bigger (H cup)')
    , (2, 'Like Type 2 but larger')
    , (2, 'Like Type 2 but much larger (DD cup)')
    , (2, 'Like Type 2 but size C (normally when not breastfeeding)')
    , (2, 'Like Type 2 but smaller and not identical sizes')
    , (3, 'Like Type 3 but bigger')
    , (3, 'Like Type 3 but much larger')
    , (3, 'Like Type 3 but much more full breasts (still with the large areola)')
    , (3, 'Like Type 3, but no mammary fold')
    , (4, 'Like Type 4 but closer together and larger')
    , (1, 'Like Type one but much bigger')
    , (90, 'Like a softball in a tube sock, nipples pointing down. Very large.')
    , (1, 'Like one but larger and more droopy')
    , (1, 'Like one but larger areola and pointing downwards')
    , (3, 'Like three but bigger')
    , (1, 'Like type 1 (nipples fairly centered/perky) but much bigger overall, with larger areolas.')
    , (1, 'Like type 1 but 42DDD.')
    , (1, 'Like type 1 but a little smaller')
    , (1, 'Like type 1 but bigger')
    , (1, 'Like type 1 but bigger and a little more saggy')
    , (1, 'Like type 1 but bigger and nipples larger')
    , (1, 'Like type 1 but bigger size double D')
    , (1, 'Like type 1 but bigger, larger areolas, smaller nipples')
    , (1, 'Like type 1 but bigger.')
    , (1, 'Like type 1 but larger')
    , (1, 'Like type 1 but larger areolas and larger in mass')
    , (1, 'Like type 1 but larger nipples and areola')
    , (1, 'Like type 1 but much bigger')
    , (1, 'Like type 1 but much bigger with wider flatter lighter nipples')
    , (1, 'Like type 1 but much bigger. E cup.')
    , (1, 'Like type 1 but much larger areola and nipple. Size 42H')
    , (1, 'Like type 1 but much larger. (I have a roughly 13" difference between my ribcage and fullest breast measurement)')
    , (1, 'Like type 1 but much smaller.')
    , (90, 'Like type 1 but my nipples are down further like in type 2')
    , (1, 'Like type 1 but my nipples are dropping down a bit more')
    , (1, 'Like type 1 but nipples a little lower and areoles a little bigger')
    , (1, 'Like type 1 but nipples are larger')
    , (90, 'Like type 1 but nipples lower, not as low as type 2 though.')
    , (1, 'Like type 1 but smaller')
    , (1, 'Like type 1 but smaller (when not nursing)')
    , (1, 'Like type 1 but smaller, nipples were flat but baby changed that')
    , (1, 'Like type 1 but the right is a little larger than the left')
    , (1, 'Like type 1 but way bigger')
    , (1, 'Like type 1, but bigger.')
    , (1, 'Like type 1, but larger')
    , (1, 'Like type 1, but nipples farther to the outside edge of the breasts')
    , (1, 'Like type 1, but slightly farther apart and range in size depending on how far post partum I am each baby I breast feed')
    , (1, 'Like type 1, but smaller')
    , (1, 'Like type 1, but smaller with smaller nipples.')
    , (2, 'Like type 2 asemetrical but bigger')
    , (2, 'Like type 2 but MUCH bigger')
    , (2, 'Like type 2 but bigger')
    , (2, 'Like type 2 but bigger aerola''s')
    , (2, 'Like type 2 but bigger and broader')
    , (2, 'Like type 2 but bigger and hangier')
    , (2, 'Like type 2 but bigger and rounder')
    , (2, 'Like type 2 but bigger and the nipples are more at the bottom. They are almost underneath, its presented a lot of feeding problems.')
    , (2, 'Like type 2 but bigger with one side being smaller than the other side')
    , (2, 'Like type 2 but larger')
    , (2, 'Like type 2 but larger and fuller')
    , (2, 'Like type 2 but larger breasts')
    , (2, 'Like type 2 but larger with larger nipple')
    , (2, 'Like type 2 but much bigger')
    , (2, 'Like type 2 but much larger')
    , (2, 'Like type 2 but much larger and more tubular')
    , (2, 'Like type 2 but much larger, 34H')
    , (2, 'Like type 2 but much smaller & no breast crease')
    , (2, 'Like type 2 but slightly larger')
    , (90, 'Like type 2 but smaller (before being pregnant) now it look more like type 1')
    , (2, 'Like type 2 but smaller nipples, bigger breasts')
    , (90, 'Like type 2 but smaller nipples/areola')
    , (2, 'Like type 2 but the size of type 1')
    , (2, 'Like type 2 but very large')
    , (2, 'Like type 2 where nipples point more down than forward, but much larger')
    , (2, 'Like type 2, but bigger')
    , (2, 'Like type 2, but bigger. one left nipple faces down')
    , (2, 'Like type 2, but much bigger')
    , (2, 'Like type 2, but much much larger')
    , (2, 'Like type 2, but much, much bigger.')
    , (3, 'Like type 3 but a E cup')
    , (3, 'Like type 3 but a little bigger')
    , (3, 'Like type 3 but a size D')
    , (3, 'Like type 3 but bigger')
    , (3, 'Like type 3 but bigger breast')
    , (3, 'Like type 3 but larger')
    , (3, 'Like type 3 but larger (e cup)')
    , (3, 'Like type 3 but larger breasts.')
    , (3, 'Like type 3 but much bigger')
    , (3, 'Like type 3 but much larger')
    , (3, 'Like type 3 but much much larger')
    , (3, 'Like type 3 but. Bigger')
    , (3, 'Like type 3, but larger')
    , (3, 'Like type 3, but much bigger')
    , (4, 'Like type 4 but a lot bigger (38H)')
    , (4, 'Like type 4 but bigger')
    , (4, 'Like type 4 but bigger and nipples pointing down a little more')
    , (4, 'Like type 4, but bigger')
    , (90, 'Like type a but bigger')
    , (1, 'Like type one but less full')
    , (1, 'Like type one, but size 40DDD')
    , (3, 'Like type three but bigger')
    , (3, 'Like type three but much bigger. And one is significantly larger than the other.')
    , (2, 'Like type two but bigger')
    , (2, 'Like type two but much bigger. (GG)')
    , (2, 'Like type two but much larger')
    , (2, 'Like2, but bigger')
    , (2, 'Look like type 2 but only when breast feeding. Much smaller otherwise. I don''t fill an acup.')
    , (1, 'Looks like type 1 but smaller')
    , (90, 'Lt like Type 1, Rt like type 2')
    , (4, 'Mine are like type 4 but much bigger')
    , (90, 'Mix of 2 and 4')
    , (90, 'Mix of type 1 and 2')
    , (90, 'More like type 1 but assymetrical like type 2')
    , (4, 'Most like Type 4 - large aerolas, but larger breasts than depicted')
    , (90, 'Most like type 1, but with bigger areolas (like type 3''s)')
    , (90, 'Much bigger')
    , (90, 'Much larger')
    , (90, 'My breasts are uneven.  One looks like type 1 - the only one I''ve been successful nursing on and the other looks like type 2 - very low producer, stopped trying to nurse on this side after 6 months.')
    , (90, 'My left looks like type 2 and right looks like type 1')
    , (90, 'My left side looks like Type 1, my right side looks like Type 2')
    , (90, 'One resembles type 1 and the other resembles type 2')
    , (90, 'One type 2, one type 4')
    , (90, 'Post baby mostly like type 1, pre baby more like type 3 but a little biggee')
    , (1, 'Similar to type 1 but my right breast is smaller (nearly a cup size difference from the left)')
    , (2, 'Similar to type 2 but nipples do not point out at all.')
    , (4, 'Similar to type 4 but size G. Best described as pendulous')
    , (90, 'Somewhere between 1 and 2')
    , (90, 'Somewhere between 1 and 2 but a lot bigger')
    , (90, 'Somewhere between 1 and 2.')
    , (90, 'Somewhere in between type 1 and 2 now i have stopped breastfeeding but definitely type 1 while feeding')
    , (90, 'Started like Type 1, look more like Type 2 now.')
    , (1, 'Type 1 FFcup flat nipples')
    , (90, 'Type 1 and type 3')
    , (1, 'Type 1 but bigger')
    , (1, 'Type 1 but bigger and much bigger areola.')
    , (1, 'Type 1 but bigger and my right breast is slightly smaller than the left.')
    , (1, 'Type 1 but bigger and saggy')
    , (1, 'Type 1 but bigger nipples')
    , (1, 'Type 1 but closer together')
    , (1, 'Type 1 but flat nipples')
    , (1, 'Type 1 but larger')
    , (1, 'Type 1 but much bigger')
    , (1, 'Type 1 but much larger')
    , (1, 'Type 1 but much larger & saggier')
    , (1, 'Type 1 but slightly bigger')
    , (1, 'Type 1 but smaller')
    , (1, 'Type 1 but smaller (34C)')
    , (1, 'Type 1 but smaller and a little saggier')
    , (1, 'Type 1 but the left is smaller than the right')
    , (1, 'Type 1 but way bigger')
    , (1, 'Type 1 but with nipples nearer the bottom. I''m a 38DDD')
    , (1, 'Type 1 w larger nipples')
    , (90, 'Type 1 while breast feeding, More like Type 2 when not breast feeding (non-droopy B cup)')
    , (1, 'Type 1 with larger nipples/areolas')
    , (90, 'Type 1 with nipples like type 3')
    , (90, 'Type 1 with size difference like type 2')
    , (1, 'Type 1, but bigger')
    , (1, 'Type 1, but fuller, larger')
    , (1, 'Type 1, but with much larger areolas.')
    , (1, 'Type 1, right side slightly bigger than left, larger than those pictured')
    , (2, 'Type 2 but DD cups')
    , (2, 'Type 2 but biggee')
    , (2, 'Type 2 but bigger')
    , (2, 'Type 2 but bigger I guess.')
    , (2, 'Type 2 but bigger and very uneven. (Like a cup size difference)')
    , (2, 'Type 2 but larger')
    , (2, 'Type 2 but larger.')
    , (2, 'Type 2 but more even')
    , (2, 'Type 2 but much bigger')
    , (2, 'Type 2 but much larger')
    , (2, 'Type 2 size F')
    , (2, 'Type 2 slightly bigger smaller aeriola')
    , (2, 'Type 2, bigger')
    , (2, 'Type 2, but bigger')
    , (2, 'Type 2, but bigger, with larger areolas')
    , (2, 'Type 2, but much bigger')
    , (2, 'Type 2, but much bigger breast and areola')
    , (3, 'Type 3 but MUCH bigger')
    , (3, 'Type 3 but bigger')
    , (3, 'Type 3 but larger')
    , (3, 'Type 3 but larger currently 40F')
    , (3, 'Type 3 but way bigger')
    , (3, 'Type 3 but way larger')
    , (90, 'Type 3 only larger like type 1')
    , (3, 'Type 3, but slightly bigger')
    , (4, 'Type 4 but a lot larger')
    , (4, 'Type 4 but bigger')
    , (4, 'Type 4 but bigger breast')
    , (4, 'Type 4 much bigger')
    , (4, 'Type 4, but bigger')
    , (4, 'Type 4, but larger')
    , (90, 'Type but bigger')
    , (1, 'Type one but bigger')
    , (1, 'Type one but bigger and larger nipple area.')
    , (1, 'Type one but breasts are larger')
    , (1, 'Type one but lower')
    , (1, 'Type one but much bigger.')
    , (1, 'Type one but much larger')
    , (1, 'Type one but nipples point up')
    , (1, 'Type one with bigger nipples')
    , (3, 'Type three but larger')
    , (2, 'Type two but bigger')
    , (2, 'Type two but bit bigger')
    , (2, 'Type two but larger')
    , (1, 'Type1 but smaller...now')
    , (1, 'Uk size 38G, nipples point down. Like 1 but bigger.')
    , (2, 'Very like type 2 but not as widely spaced. Nipples kind of point sideways')
    , (90, 'a cross between 1 and 2')
    , (90, 'a cross between type 1 and type 2')
    , (90, 'between 1 and 2 but bigger.')
    , (90, 'between 1&2')
    , (90, 'between 1and 2 but bigger')
    , (90, 'between 2-3')
    , (90, 'between type 1 & type 2')
    , (90, 'between type 1 and type 3')
    , (90, 'bigger')
    , (90, 'but a little smaller?')
    , (90, 'but bigger')
    , (90, 'but bigger!')
    , (90, 'cross between 1 and 2')
    , (90, 'cross between 1 and 2 and bigger.')
    , (90, 'in between 2 and 3')
    , (90, 'just huge!')
    , (90, 'larger like type 1, but shaped and positioned more like type 2')
    , (1, 'like 1 but a little lower')
    , (1, 'like 1 but bigger')
    , (1, 'like 1 but larger')
    , (1, 'like 1 but much much bigger.')
    , (1, 'like 1,  but very  saggy and very large')
    , (1, 'like 1, but larger and more droopy')
    , (90, 'like 1, but nipples like 2, but huge boobs.')
    , (1, 'like 1, but one is slightly smaller and points a bit to the side')
    , (2, 'like 2 but bigger')
    , (2, 'like 2 but bigger breast and smaller nipples')
    , (2, 'like 2 but larger')
    , (2, 'like 2 but much bigger')
    , (2, 'like 2 but much bigger breast and nipple area')
    , (2, 'like 2 but much larger')
    , (2, 'like 2, about the same size and spacing in between. but with very large areolas and small nipples.')
    , (2, 'like 2, but larger')
    , (3, 'like 3 but bigger')
    , (3, 'like 3 but larger')
    , (3, 'like 3, but bigger')
    , (4, 'like 4 but much larger')
    , (2, 'like Type 2 but bigger')
    , (90, 'like a mix between type 1 and type 2. good shape but more conical than i believe is typical.')
    , (2, 'like two, but bigger')
    , (2, 'like tyoe 2 but bigger')
    , (1, 'like type 1 but a little smaller')
    , (1, 'like type 1 but bigger')
    , (1, 'like type 1 but bigger, saggier')
    , (1, 'like type 1 but fuller, more round- had augmentation  augmen')
    , (1, 'like type 1 but larger')
    , (1, 'like type 1 but less perky')
    , (1, 'like type 1 but much bigger')
    , (1, 'like type 1 but much larger')
    , (1, 'like type 1 but one 2 cup sizes bigger than the other')
    , (1, 'like type 1 but one is a cup and half smaller')
    , (1, 'like type 1 but right side a little smaller')
    , (1, 'like type 1 but smaller')
    , (1, 'like type 1 but with bigger nipples')
    , (1, 'like type 1 but with lower nipples')
    , (1, 'like type 1 but, bigger')
    , (1, 'like type 1 with larger areolas.')
    , (1, 'like type 1, but WAY bigger')
    , (1, 'like type 1, but a bit bigger')
    , (1, 'like type 1, but bigger')
    , (1, 'like type 1, but bigger; one breast is significantly larger than the other')
    , (1, 'like type 1, but much bigger')
    , (1, 'like type 1, but much larger')
    , (1, 'like type 1, but one breast slightly smaller')
    , (1, 'like type 1, larger, more saggy')
    , (2, 'like type 2 bur bigger')
    , (2, 'like type 2 but a bit bigger')
    , (2, 'like type 2 but bigger')
    , (2, 'like type 2 but bigger and with large areolas')
    , (2, 'like type 2 but bigger breasts')
    , (2, 'like type 2 but bigger.')
    , (2, 'like type 2 but larger')
    , (2, 'like type 2 but much bigger')
    , (2, 'like type 2 but much bigger (F)')
    , (2, 'like type 2 but much bigger!')
    , (2, 'like type 2 but much bigger. I am a 34G')
    , (2, 'like type 2 but much larger')
    , (2, 'like type 2 but one is smaller and not much tissue under')
    , (2, 'like type 2 but one much bigger than the other')
    , (2, 'like type 2 but smaller')
    , (2, 'like type 2 but the areolas are MUCH bigger')
    , (2, 'like type 2 onky areola is larger')
    , (2, 'like type 2, but bigger')
    , (2, 'like type 2, but bigger.  An H cup.')
    , (3, 'like type 3 but bigger')
    , (3, 'like type 3 but bigger and more pendulous lol.')
    , (90, 'like type 3 but large like type 1')
    , (3, 'like type 3 but larger')
    , (3, 'like type 3 but larger. my left breast is noticibly larger than my right. very large areola.')
    , (3, 'like type 3 but much bigger')
    , (4, 'like type 4 but a D cup')
    , (4, 'like type 4 but bigger')
    , (4, 'like type 4 but much larger breasts')
    , (4, 'like type 4 but waaaaay bigger')
    , (4, 'like type 4 with wider base')
    , (4, 'like type four, the are VERY saggy and ALOT bigger!  The areolas are alot bigger too!')
    , (1, 'like type one but much much larger')
    , (1, 'like type one but overall bigger with bigger areolas and bigger nipples.')
    , (1, 'like type one only much larger')
    , (3, 'like type three but large and pendulum like')
    , (2, 'like type two but bigger')
    , (2, 'like type two but bigger but with smaller aereola')
    , (2, 'like type two but dd cup')
    , (2, 'like type two, but bigger')
    , (2, 'like you''re 2 but one breast biggerr')
    , (1, 'like1 but bigger')
    , (2, 'look like 2 but larger')
    , (90, 'lop sided, very large and point towards the ground')
    , (90, 'mixture between 1 and 2')
    , (1, 'most like #1 but change appearance after weaning')
    , (1, 'most like type 1, but bigger, and thus saggier!')
    , (3, 'nipples like type 3 but breasts are much larger')
    , (90, 'none')
    , (1, 'none type 1 but uneven,  one larger than the other and much larger aereolas')
    , (90, 'only one is bigger than the other.')
    , (2, 'right boob is noticably bigger than left, both big andmost like type 2 but bigger')
    , (90, 'right one is type one, left is type two')
    , (1, 'shape like type 1, but smaller. 32D pre preg, 36E after childbirth, 34D at present')
    , (2, 'similar to type 2 but a little bigger')
    , (3, 'similar to type 3 but slightly rounder')
    , (90, 'something between types 1 and 2.')
    , (2, 'somewhat like type 2 but bigger')
    , (90, 'somewhere between type 1 and type 2')
    , (90, 'somewhere in between type 2 and type 4')
    , (90, 'the one is simular to type 2 and the other is like type 1 got odd breasts')
    , (2, 'typ2 but bigger')
    , (1, 'type 1 , bigger')
    , (1, 'type 1 but D cups')
    , (1, 'type 1 but a little saggier')
    , (1, 'type 1 but areola larger')
    , (1, 'type 1 but bigger')
    , (1, 'type 1 but bigger areolas')
    , (1, 'type 1 but bigger, and more "looking" down')
    , (1, 'type 1 but bigger, right nipple points more downwards')
    , (1, 'type 1 but bigger. 38E')
    , (1, 'type 1 but larger')
    , (1, 'type 1 but much bigger')
    , (1, 'type 1 but much bigger with larger areolas, nipples do not piont out, but rather point downward.')
    , (1, 'type 1 but much larger and saggy')
    , (1, 'type 1 but much, much bigger')
    , (1, 'type 1 but smaller')
    , (1, 'type 1 but way bigger')
    , (1, 'type 1 with larger flat nipples')
    , (1, 'type 1, but wayyyy bigger !')
    , (1, 'type 1, much bigger')
    , (2, 'type 2  bigger')
    , (2, 'type 2 a bit bigger')
    , (2, 'type 2 bigger')
    , (90, 'type 2 but a little larger and not round like 1')
    , (2, 'type 2 but a lot bigger')
    , (2, 'type 2 but bigger')
    , (2, 'type 2 but bigger breast, aereola and flat nipple')
    , (2, 'type 2 but fuller')
    , (2, 'type 2 but larger')
    , (2, 'type 2 but larger and farther apart')
    , (2, 'type 2 but larger and more droopy')
    , (90, 'type 2 but larger,more full; maybe a combo of types 1 & 2')
    , (2, 'type 2 but little bigger and nipples not as low just a bit higher')
    , (2, 'type 2 but much bigger')
    , (2, 'type 2 but much larger')
    , (2, 'type 2 but much much bigger')
    , (2, 'type 2 but smaller')
    , (2, 'type 2 but the L doesn''t turn out like that pic. the R is smaller than the L')
    , (2, 'type 2 but way bigger')
    , (2, 'type 2 large fuller')
    , (90, 'type 2 prior to children/nursing, type 1 currently (post partum/while nursing')
    , (2, 'type 2, smaller nipples')
    , (3, 'type 3 but bigger')
    , (3, 'type 3 but larger')
    , (4, 'type 4 but bigger')
    , (4, 'type 4 but g cup')
    , (4, 'type 4 but much bigger')
    , (1, 'type one but i''m a 38I')
    , (2, 'type two but bigger')
    , (1, 'type1 but bigger')
    , (90, 'type1 when breastfeeding or pregnant, type 2 otherwise')
    , (1, 'typle 1 but bigger')
    , (90, 'very large nipples like type 4 but large breasts like type 1')
    , (90, 'way bigger f cup with really large nipples');


DROP TABLE IF EXISTS codes.menarche;
CREATE TABLE codes.menarche(Code INTEGER, Description TEXT);
INSERT INTO codes.menarche VALUES
     (12, '12')
   , (13, '13')
   , (11, '11')
   , (14, '14')
   , (NULL, '')
   , (15, '15')
   , (10, '10')
   , (16, '16')
   , (9, '9')
   , (17, '17')
   , (12, '12.5')
   , (8, '8')
   , (13, '13?')
   , (14, '14?')
   , (13, '12 or 13')
   , (12, '12?')
   , (18, '18')
   , (12, '11 or 12')
   , (11, '11.5')
   , (13, '12-13')
   , (11, '10 or 11')
   , (11, '11 years old')
   , (12, '12 years old')
   , (13, '13 years')
   , (12, '13.5')
   , (NULL, '1')
   , (11, '11?')
   , (12, '12 years')
   , (12, '12 years 10 months')
   , (13, '13 I think')
   , (13, '13 years old')
   , (14, '14.5')
   , (13, '7th grade')
   , (9, '9 years old')
   , (10, '10 1/2')
   , (10, '10 years old')
   , (10, '10 yo')
   , (10, '10.5')
   , (12, '11 or 12 years old')
   , (11, '11 years')
   , (11, '11 yrs')
   , (12, '11-12')
   , (12, '11-13')
   , (11, '11.5 yrs')
   , (11, '11.9')
   , (13, '12 (1 month before my 13th birthday).')
   , (12, '12 1/2')
   , (12, '12 and 1/2')
   , (13, '12 or 13, can''t remember exactly')
   , (13, '12 years , 10 mos')
   , (12, '12 yrs')
   , (13, '12 yrs 10mths')
   , (12, '12 yrs and 11 mos')
   , (12, '12, 6th grade')
   , (13, '12, almost 13')
   , (12, '12.5 years')
   , (12, '12.5 years old')
   , (13, '12/13')
   , (13, '13 ?')
   , (13, '13 and a half')
   , (13, '13 best guess')
   , (13, '13ish')
   , (14, '14 years')
   , (15, '14-15 yrs')
   , (14, '14.5 yrs old')
   , (14, '14.75')
   , (15, '15.5')
   , (17, '16 or 17')
   , (16, '16 years')
   , (19, '19')
   , (21, '21')
   , (9, '4th grade. Unsure of age')
   , (11, '5th Grade- 11?')
   , (10, '5th grade')
   , (11, '6 th grade')
   , (8, '8.5')
   , (9, '9 1/2')
   , (NULL, '???')
   , (12, 'Around 12')
   , (13, 'Don''t know, maybe 13')
   , (NULL, 'Don''t remember')
   , (12, 'I can''t remember for sure, but probably around 12.')
   , (11, 'I guess I was 11?')
   , (10, 'I just turned 10')
   , (13, 'I think 13?')
   , (17, 'Never had one until after diagnosed with Polycystic ovarian syndrome-then given birth control pill which gave me a period at 17')
   , (13, 'Not sure.  Maybe 13')
   , (12, 'Somewhere between 11.5 and 12.5')
   , (NULL, 'can''t recall')
   , (12, 'can''t remember for sure, 11-13ish')
   , (NULL, 'don''t know')
   , (14, 'maybe 14?')
   , (14, 'not sure, 14 maybe?  I was on the older side...?')
   , (10, 'ten')
   , (12, '~12');


DROP TABLE IF EXISTS codes.irregular_period;
CREATE TABLE codes.irregular_period(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.irregular_period(Code, raw_Code, Description) VALUES
      (1, 2, 'Irregular period')
    , (0, 1, 'Regular period');


DROP TABLE IF EXISTS codes.breast_change;
CREATE TABLE codes.breast_change(Code INTEGER, Description TEXT);
INSERT INTO codes.breast_change(Code, Description) VALUES
      (0, 'Breasts did not change size during past pregnancy or pregnancies')
    , (1, 'Less than 1 cup size')
    , (2, 'About 1 cup size')
    , (3, 'More than 1 cup size');


DROP TABLE IF EXISTS codes.conception;
CREATE TABLE codes.conception(Code INTEGER, raw_Code, Description TEXT);
INSERT INTO codes.conception(Code, raw_Code, Description)
SELECT Code, Code, Description
FROM raw.HOW_CONCEIVE
WHERE Code <> 0
ORDER BY 1
;

INSERT INTO codes.conception(Code, raw_Code, Description) VALUES
    (90, 0, 'By other means');


DROP TABLE IF EXISTS codes.natural_conception;
CREATE TABLE codes.natural_conception(Code INTEGER, Description TEXT);
INSERT INTO codes.natural_conception VALUES
      (1, 'Conceived naturally after less than a year of trying')
    , (0, 'Not conceived naturally or conceived naturally after more than a year of trying');


DROP TABLE IF EXISTS codes.delivery_mode;
CREATE TABLE codes.delivery_mode(Code INTEGER, Description TEXT);
INSERT INTO codes.delivery_mode(Code, Description) VALUES
      (1, 'Vaginal')
    , (2, 'C-section');


DROP TABLE IF EXISTS codes.baby_gestational_age;
CREATE TABLE codes.baby_gestational_age(Code FLOAT, Description TEXT);
INSERT INTO codes.baby_gestational_age(Description)
SELECT Code
FROM raw.BABY1_Gestation
;

UPDATE codes.baby_gestational_age
SET Code =
    CASE Description
      WHEN 'Less than 28 Weeks' THEN 28.0
      WHEN '28-32 Weeks' THEN (28 + 32 + 0.0)/2
      WHEN '33-36 Weeks' THEN (33 + 36 + 0.0)/2
      WHEN '37-39 Weeks' THEN (37 + 39 + 0.0)/2
      WHEN '40-41 Weeks' THEN (40 + 41 + 0.0)/2
      WHEN '42 Weeks' THEN (42 + 42 + 0.0)/2
      WHEN '43 or More Weeks' THEN 43.0
      ELSE NULL
    END
;


DROP TABLE IF EXISTS codes.baby_healthy;
CREATE TABLE codes.baby_healthy(Code INTEGER, Description TEXT);
INSERT INTO codes.baby_healthy(Code, Description) VALUES
      (1, 'Baby has not been diagnosed with chronic health problems')
    , (0, 'Baby has been diagnosed with chronic health problems');


DROP TABLE IF EXISTS codes.baby_tongue_tie;
CREATE TABLE codes.baby_tongue_tie(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.baby_tongue_tie(Code, raw_Code, Description) VALUES
      (NULL, 4, 'Don''t know')
    , (0, 3, 'No')
    , (1, 2, 'Yes, and it was not clipped')
    , (2, 1, 'Yes, and it was clipped');


DROP TABLE IF EXISTS codes.first_bf;
CREATE TABLE codes.first_bf(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.first_bf(Code, raw_Code, Description)
SELECT Code, Code, Description
FROM raw.FIRST_BF
;

UPDATE codes.first_bf
SET Code = NULL
WHERE raw_Code = 0
;


DROP TABLE IF EXISTS codes.baby_in_bed;
CREATE TABLE codes.baby_in_bed(Code INTEGER, Description TEXT);
INSERT INTO codes.baby_in_bed(Code, Description) VALUES
      (1, 'Baby started night in mother''s bed during first six months of life')
    , (0, 'Baby did not start night in mother''s bed during first six months of life');


DROP TABLE IF EXISTS codes.pacifier;
CREATE TABLE codes.pacifier(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.pacifier(raw_Code, Description)
SELECT Code, Description
FROM raw.PACIFIER
;

UPDATE codes.pacifier
SET Code = raw_Code - 1
;


DROP TABLE IF EXISTS codes.swaddle;
CREATE TABLE codes.swaddle(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.swaddle(raw_Code, Description)
SELECT Code, Description
FROM raw.SWADDLE
;

UPDATE codes.swaddle
SET Code = raw_Code - 1
;


DROP TABLE IF EXISTS codes.baby_formula;
CREATE TABLE codes.baby_formula(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.baby_formula(Code, raw_Code, Description) VALUES
      (1, 1, 'Baby received formula supplementation')
    , (0, 2, 'Baby never received formula supplmentation');


DROP TABLE IF EXISTS codes.solid_food;
CREATE TABLE codes.solid_food(Code INTEGER, Description TEXT);
INSERT INTO codes.solid_food(Code, Description) VALUES
      (1, 'Started baby on solid food before six months')
    , (0, 'Started baby on solid food at or after six months');



DROP TABLE IF EXISTS codes.milk_supply;
CREATE TABLE codes.milk_supply(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.milk_supply(Code, raw_Code, Description) VALUES
      (4, 1, 'More than my baby needed')
    , (3, 2, 'Exactly what my baby needed')
    , (2, 3, 'Slightly less than my baby needed')
    , (1, 4, 'A lot less than my baby needed');


DROP TABLE IF EXISTS codes.low_milk_supply;
CREATE TABLE codes.low_milk_supply(Code INTEGER, Description TEXT);
INSERT INTO codes.low_milk_supply(Code, Description) VALUES
      (1, 'Milk supply slightly or a lot less than baby needed')
    , (0, 'Milk supply exactly what or more than baby needed');





DROP TABLE IF EXISTS codes.bc_NFP;
CREATE TABLE codes.bc_NFP(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_NFP(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Natural Family Planning after birth of child')
    , (0, 2, 'Did not use Natural Family Planning after birth of child');


DROP TABLE IF EXISTS codes.bc_barrier;
CREATE TABLE codes.bc_barrier(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_barrier(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Barrier after birth of child')
    , (0, 2, 'Did not use Barrier after birth of child');


DROP TABLE IF EXISTS codes.bc_copper_IUD;
CREATE TABLE codes.bc_copper_IUD(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_copper_IUD(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Copper IUD after birth of child')
    , (0, 2, 'Did not use Copper IUD after birth of child');


DROP TABLE IF EXISTS codes.bc_hormonal_IUD;
CREATE TABLE codes.bc_hormonal_IUD(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_hormonal_IUD(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Hormonal IUD after birth of child')
    , (0, 2, 'Did not use Hormonal IUD after birth of child');


DROP TABLE IF EXISTS codes.bc_progestin_pill;
CREATE TABLE codes.bc_progestin_pill(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_progestin_pill(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Progestin-only birth control pill after birth of child')
    , (0, 2, 'Did not use Progestin-only birth control pill after birth of child');


DROP TABLE IF EXISTS codes.bc_combination_pill;
CREATE TABLE codes.bc_combination_pill(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_combination_pill(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Combination birth control pill after birth of child')
    , (0, 2, 'Did not use Combination birth control pill after birth of child');


DROP TABLE IF EXISTS codes.bc_patch;
CREATE TABLE codes.bc_patch(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_patch(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Patch after birth of child')
    , (0, 2, 'Did not use Patch after birth of child');


DROP TABLE IF EXISTS codes.bc_implant;
CREATE TABLE codes.bc_implant(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_implant(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Implant after birth of child')
    , (0, 2, 'Did not use Implant after birth of child');


DROP TABLE IF EXISTS codes.bc_shot;
CREATE TABLE codes.bc_shot(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_shot(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Shot after birth of child')
    , (0, 2, 'Did not use Shot after birth of child');


DROP TABLE IF EXISTS codes.bc_ring;
CREATE TABLE codes.bc_ring(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_ring(Code, raw_Code, Description) VALUES
      (1, 1, 'Used Vaginal ring after birth of child')
    , (0, 2, 'Did not use Vaginal ring after birth of child');


DROP TABLE IF EXISTS codes.bc_other;
CREATE TABLE codes.bc_other(Code INTEGER, raw_Code INTEGER, Description TEXT);
INSERT INTO codes.bc_other(Code, raw_Code, Description) VALUES
      (1, 0, 'Used Other birth control after birth of child')
    , (0, 1, 'Did not use Other birth control after birth of child');




------------------------------------------------------------------------
-- Populate the main analysis table
------------------------------------------------------------------------


INSERT INTO survey(
        RespondentId
	, start_date
        , sex
	, age_yc
	, bf_status
	, pumper
	, age_mother
	, race
	, ethnicity
	, education
	, income
	, marital_status
	, height
	, weight
	, metformin
	, BC_pills
	, BC_age
	, heart_surgery
	, chest_injury
	, breast_any_procedure
	, breast_procedures
	, transfusion
	, hemorrhage
	, diabetes_1
	, diabetes_2
	, diabetes_g
	, POS
	, thyroid
	, depression
	, breast_type
	, menarche
	, irregular_period
	, breast_change
	, conception
	, delivery_mode
	, baby_gestational_age
	, baby_healthy
	, baby_tongue_tie
	, first_bf
	, baby_in_bed
	, pacifier
	, swaddle
	, baby_formula
	, solid_food

	, milk_supply
	, bc_NFP
	, bc_barrier
	, bc_copper_IUD
	, bc_hormonal_IUD
	, bc_progestin_pill
	, bc_combination_pill
	, bc_patch
	, bc_implant
	, bc_shot
	, bc_ring
	, bc_other
    )
SELECT s.RespondentID
    , s.StartDate as start_date
    , s.SEX AS sex
    , s.AGE_YC AS age_yc
    , s.BF_STATUS AS bf_status

    , CASE s.LEVEL_BF_6MO
        WHEN 1 THEN 0
	WHEN 2 THEN 1
	WHEN 3 THEN 1
	WHEN 4 THEN 0
	WHEN 5 THEN 1
	ELSE NULL
      END AS pumper

    -- The minimum possible age of mother based on self-reported
    -- year of birth
    , 2013 - yob.year - 1 AS age_mother
    , (SELECT Code FROM codes.race WHERE Description = s.RACE_STRING)
        AS race
    , (SELECT Code FROM codes.ethnicity WHERE raw_Code = s.ETHNIC)
        AS ethnicity
    , s.EDUCATION as education
    , (SELECT Code FROM codes.income WHERE Description = s.INCOME)
        AS income
    , ms.status as marital_status
    , (SELECT Code FROM codes.height WHERE raw_Code = s.MOTHER_HEIGHT)
        AS height
    , CASE
        WHEN s.MOTHER_WEIGHT = '' THEN NULL
	ELSE CAST(s.MOTHER_WEIGHT AS FLOAT)
      END AS weight
    , (SELECT Code FROM codes.metformin WHERE raw_Code = s.METFORMIN)
        AS metformin
    , (SELECT Code FROM codes.BC_pills WHERE raw_Code = s.BC_PILLS)
        AS BC_pills
    , (SELECT Code FROM codes.BC_age WHERE Description = s.BC_PILLS_AGE)
        AS BC_age
    , COALESCE((SELECT Code FROM codes.heart_surgery WHERE raw_Code = s.HEART_SURGERY), 0) AS heart_surgery
    , COALESCE((SELECT Code FROM codes.chest_injury WHERE raw_Code = s.CHEST_INJURY), 0) AS chest_injury
    , CASE
        WHEN bp.breast_procedures IS NOT NULL THEN 1
	ELSE 0
      END AS breast_any_procedure
    , bp.breast_procedures
    , (SELECT Code FROM codes.transfusion WHERE raw_Code = s.TRANSFUSION)
        AS transfusion
    , CASE
        WHEN h.bled_ever = 1 THEN 1
	WHEN h.bled_yc   = 1 THEN 1
	WHEN h.bled_ever = 0 AND h.bled_yc = 0 THEN 0
	ELSE NULL
      END AS hemorrhage
    , c.diabetes_1
    , c.diabetes_2
    , c.diabetes_g
    , c.POS
    , c.thyroid
    , c.depression
    , CASE
        WHEN s.BREAST_PICTURE IN (1, 2, 3, 4) THEN s.BREAST_PICTURE
	WHEN bto.Code IN (1, 2, 3, 4, 90) THEN 90
	WHEN s.BREAST_PICTURE IN (0) THEN 90
	ELSE NULL
      END AS breast_type
    , (SELECT Code FROM codes.menarche WHERE Description = s.AGE_FIRST_MENS)
        AS menarch
    , (SELECT Code FROM codes.irregular_period WHERE raw_Code = s.REG_MENS)
        AS irregular_period
    , CASE
        WHEN s.BREAST_CHANGE_SIZE = 1 THEN 0
	WHEN s.NUMBER_SIZE_CHANGE IN (1, 2, 3) THEN s.NUMBER_SIZE_CHANGE
	ELSE NULL
      END AS breast_change
    , (SELECT Code FROM codes.conception WHERE raw_Code = s.HOW_CONCEIVE)
        AS conception
    , CASE s.HOW_BORN
        WHEN 1 THEN 1
	WHEN 2 THEN 1
	WHEN 3 THEN 2
	WHEN 4 THEN 2
	ELSE NULL
      END AS delivery_mode
    , (SELECT Code FROM codes.baby_gestational_age WHERE Description = s.BABY1_Gestation)
        AS baby_gestational_age
    , CASE
        WHEN s.BABY_HEALTH_YES = 2 THEN 0
	WHEN s.BABY_HEALTH_NO = 1 THEN 1
	ELSE NULL
      END AS baby_healthy
    , (SELECT Code FROM codes.baby_tongue_tie WHERE raw_Code = s.TONGUE_TIE)
        AS baby_tongue_tie
    , (SELECT Code FROM codes.first_bf WHERE raw_Code = s.FIRST_BF)
        AS first_bf
    , CASE s.START_NIGHT_F6MO
        WHEN 1 THEN 1
	WHEN 2 THEN 0
	WHEN 3 THEN 0
	WHEN 0 THEN 0
	ELSE NULL
      END AS baby_in_bed
    , (SELECT Code FROM codes.pacifier WHERE raw_Code = s.PACIFIER)
        AS pacifier
    , (SELECT Code FROM codes.swaddle WHERE raw_Code = s.SWADDLE)
        AS swaddle

    , (SELECT Code FROM codes.baby_formula WHERE raw_CODE = s.FORMULA_EVER)
        AS baby_formula

      -- LIMITATION We don't now how old the child was, so we can't fill
      -- in the missing values when the question was not applicable
    , CASE s.SOLIDS_AGE
        WHEN 1 THEN 1
	WHEN 2 THEN 1
	WHEN 3 THEN 1
	WHEN 4 THEN 0
	WHEN 5 THEN 0
	WHEN 6 THEN 0
	WHEN 7 THEN 0
	WHEN 8 THEN 0
	ELSE NULL
      END AS solid_food
    , (SELECT Code FROM codes.milk_supply WHERE raw_Code = s.GENERAL_SUPPLY)
        AS milk_supply
    , (SELECT Code FROM codes.bc_NFP WHERE raw_Code = s.BC_NFP)
        AS bc_NFP
    , (SELECT Code FROM codes.bc_barrier WHERE raw_Code = s.BC_BAR)
        AS bc_barrier
    , (SELECT Code FROM codes.bc_copper_IUD WHERE raw_Code = s.BC_CIUD)
        AS bc_copper_IUD
    , (SELECT Code FROM codes.bc_hormonal_IUD WHERE raw_Code = s.BC_HIUD)
        AS bc_hormonal_IUD
    , (SELECT Code FROM codes.bc_progestin_pill WHERE raw_Code = s.BC_PBCP)
        AS bc_progestin_pill
    , (SELECT Code FROM codes.bc_combination_pill WHERE raw_Code = s.BC_CBCP)
        AS bc_combination_pill
    , (SELECT Code FROM codes.bc_patch WHERE raw_Code = s.BC_PAT)
        AS bc_patch
    , (SELECT Code FROM codes.bc_implant WHERE raw_Code = s.BC_IMP)
        AS bc_implant
    , (SELECT Code FROM codes.bc_shot WHERE raw_Code = s.BC_SHOT)
        AS bc_shot
    , (SELECT Code FROM codes.bc_ring WHERE raw_Code = s.BC_VR)
        AS bc_ring
    , (SELECT Code FROM codes.bc_other WHERE raw_Code = s.BC1_OTHER)
        AS bc_other

FROM raw.BFSURVEY_ALL AS s
    LEFT JOIN yob
        ON s.BIRTH_YEAR = yob.BIRTH_YEAR
    LEFT JOIN marital AS ms
        ON s.RespondentID = ms.RespondentID
    LEFT JOIN breast_procedures AS bp
        ON s.RespondentID = bp.RespondentID
    LEFT JOIN hemorrhage AS h
        ON s.RespondentID = h.RespondentID
    LEFT JOIN conditions as c
        ON s.RespondentID = c.RespondentID
    LEFT JOIN codes.breast_type_other AS bto
        ON s.BREAST_DESCRIBE = bto.Description
;



-- Derive analysis population
DROP TABLE IF EXISTS codes.AP_reason;

CREATE TABLE codes.AP_reason(Code INTEGER, Description TEXT);
INSERT INTO codes.AP_reason(Code, Description) VALUES
      (0, 'Respondent is eligible')
    , (1, 'Respondent was male')
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
    , bmi = weight/height/height*703
    , natural_conception =
        CASE
      	  WHEN conception = 1 THEN 1
	  WHEN conception IS NOT NULL THEN 0
	  ELSE NULL
	END
    , low_milk_supply =
        CASE
	  WHEN milk_supply <= 2 THEN 1
	  WHEN milk_supply IS NOT NULL THEN 0
	  ELSE NULL
	END
;


DROP TABLE IF EXISTS codes.bmi_category;
CREATE TABLE codes.bmi_category(Code INTEGER, Description TEXT);
INSERT INTO codes.bmi_category VALUES
      (1, 'Underweight')
    , (2, 'Normal weight')
    , (3, 'Overweight')
    , (4, 'Obese')
;

UPDATE survey
SET bmi_category =
    CASE
      WHEN bmi >= 30.0 THEN 4
      WHEN bmi >= 25.0 THEN 3
      WHEN bmi >= 18.5 THEN 2
      WHEN bmi >=  0.0 THEN 1
      ELSE NULL
    END
;




------------------------------------------------------------------------
-- Persist codes for categorical variables
------------------------------------------------------------------------


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


DROP TABLE IF EXISTS codes.education;

CREATE TABLE codes.education AS
SELECT Code, Description
FROM raw.EDUCATION
;


-- Jupyter notebook has trouble with dollar signs
UPDATE codes.income
SET Description = REPLACE(Description, '$', '\$')
;




-- Remove unnecessary tables
DROP TABLE yob;
DROP TABLE hemorrhage;
DROP TABLE conditions;

.save '../data/analysis.sqlite3'

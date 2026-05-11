USE case_study_hmw;

-- 1. Basic exploration 
SELECT * 
FROM sfcrime2025
LIMIT 100;

DESCRIBE sfcrime2025;
DESCRIBE sfcrime2024;

SELECT * 
FROM sfcrime2024
LIMIT 100;

SELECT COUNT(*)
FROM sfcrime2025
LIMIT 1;
-- 115835


SELECT COUNT(*)
FROM sfcrime2024
LIMIT 1;
-- 109626


SELECT DISTINCT(IncidentCategory), COUNT(IncidentNumber) AS num_crimes
FROM sfcrime2025
GROUP BY 1
ORDER BY 2 DESC; 

SELECT DISTINCT(PoliceDistrict), COUNT(IncidentNumber) AS num_crimes
FROM sfcrime2025
GROUP BY 1
ORDER BY 2 DESC;

-- 2. Perform EDA on at least 3 columns 


-- TABLE DIMENSIONS
-- -------------------------

/*
FROM sfcrime2024
rows    : 109626
columns : 22

FROM sfcrime2025
rows    : 115835
columns : 22
*/

-- EDA ISSUES FOUND 
---------------------------


-- ------------------------
-- Step 1: What is in the table?
-- ------------------------

SELECT * 
FROM sfcrime2024
LIMIT 100;

/*
Observations:
- Each row represents a police incident, indetified by a RowID and IncidentID
*/


-- 3. Is crime overall going down from 2024 -> 2025?
/* Fill in your code here */

/* Use a union or a join */


-- 4. What breakdowns might be important to investigate? 
-- Pick at least 3 breakdowns
-- Think type of crime, think geographic, think resolution, etc... 


/* Fill in your code here */

-- 5. What other time-based factors might be important to investigae?
-- Pick at least 2 and investigate (day of week, seasonality, major events, etc) 

/* Fill in your code here */

-- 6. What plots might be useful to make here? 
-- Select and create at least 4 different plots showing crime trends, outliers, etc

-- Extra credit for extra-nice maps or otherwise extra-wonderful plots

/* Fill in your code here */
/* Attach any other code you are using, as well as pdf of any plots */

-- 7. WHere are the most safe / least safe neighborhoods? 
-- Include comments on how you would define safety, based on this data

-- 8. Write 1/2 page to 1 page summary of what you've found for crime trends. 
-- Did crime drop? If so by how much? What nuances/caveats are there? What data is missing?
-- Pay attention to narrative structure and clarity
-- If there are any lingering questions, investigate further and/or note them in your summary.

-- 9. Extra credit for extra analysis
-- Can you compare to other cities? Other time periods? Find other trends? 
-- =============================================================
-- SF Crime Analysis: San Francisco Incidents 2024 vs 2025
-- Author  : Plinio Durango
-- Tool    : MySQL / SQL
-- Dataset : SFPD Incident Reports 2024 & 2025
--           (San Francisco Police Department Open Data)
-- Source  : https://data.sfgov.org/Public-Safety/Police-Department-Incident-Reports
-- Date    : 2026
-- =============================================================

-- TABLE OF CONTENTS
-- ---------------------------------------------------------
-- 1. Database Setup
-- 2. Basic Exploration (Schema + Row Counts)
-- 3. Exploratory Data Analysis (EDA)
--    Step 1: What is in the table?
--    Step 2: Missing / NULL values
--    Step 3: Distinct value distributions
--    Step 4: Date range validation
-- 4. Cleaning View  (sfcrime_combined_clean)
-- 5. Year-over-Year Crime Comparison (2024 vs 2025)
-- 6. Crime Breakdowns
--    6a. By Incident Category (type of crime)
--    6b. By Police District (geographic)
--    6c. By Resolution Outcome
-- 7. Time-Based Analysis
--    7a. Day of Week
--    7b. Seasonality (Month)
-- 8. Neighborhood Safety Ranking
-- 9. Summary Findings
-- ---------------------------------------------------------


-- =============================================================
-- SECTION 1: DATABASE SETUP
-- =============================================================

USE case_study_hmw;


-- =============================================================
-- SECTION 2: BASIC EXPLORATION
-- =============================================================

-- Preview both tables
SELECT * FROM sfcrime2024 LIMIT 100;
SELECT * FROM sfcrime2025 LIMIT 100;

-- Schema inspection
DESCRIBE sfcrime2024;
DESCRIBE sfcrime2025;

-- Row counts
SELECT COUNT(*) AS total_rows_2024 FROM sfcrime2024;  -- Result: 109,626
SELECT COUNT(*) AS total_rows_2025 FROM sfcrime2025;  -- Result: 115,835

-- TABLE DIMENSIONS SUMMARY
-- -------------------------------------------------------
-- sfcrime2024: 109,626 rows | 22 columns
-- sfcrime2025: 115,835 rows | 22 columns
-- Combined  : 225,461 incident records
-- -------------------------------------------------------


-- =============================================================
-- SECTION 3: EXPLORATORY DATA ANALYSIS (EDA)
-- =============================================================

-- Step 1: What is in the table?
-- -------------------------------------------------------
SELECT * FROM sfcrime2024 LIMIT 100;
/*
  Observations:
  - Each row represents one police incident report.
  - Identified by a unique RowID and IncidentNumber.
  - Key columns: IncidentDate, IncidentTime, IncidentCategory,
    IncidentDescription, Resolution, PoliceDistrict, Latitude, Longitude.
*/

-- Step 2: Check for NULL / missing values across key columns
-- -------------------------------------------------------
SELECT
    SUM(CASE WHEN IncidentCategory IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN IncidentDate     IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN PoliceDistrict   IS NULL THEN 1 ELSE 0 END) AS null_district,
    SUM(CASE WHEN Resolution       IS NULL THEN 1 ELSE 0 END) AS null_resolution,
    SUM(CASE WHEN Latitude         IS NULL THEN 1 ELSE 0 END) AS null_latitude,
    SUM(CASE WHEN Longitude        IS NULL THEN 1 ELSE 0 END) AS null_longitude
FROM sfcrime2024;

SELECT
    SUM(CASE WHEN IncidentCategory IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN IncidentDate     IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN PoliceDistrict   IS NULL THEN 1 ELSE 0 END) AS null_district,
    SUM(CASE WHEN Resolution       IS NULL THEN 1 ELSE 0 END) AS null_resolution,
    SUM(CASE WHEN Latitude         IS NULL THEN 1 ELSE 0 END) AS null_latitude,
    SUM(CASE WHEN Longitude        IS NULL THEN 1 ELSE 0 END) AS null_longitude
FROM sfcrime2025;

-- Step 3: Distinct value distributions
-- -------------------------------------------------------
-- Unique crime categories
SELECT DISTINCT IncidentCategory FROM sfcrime2024 ORDER BY 1;
SELECT DISTINCT IncidentCategory FROM sfcrime2025 ORDER BY 1;

-- Unique police districts
SELECT DISTINCT PoliceDistrict FROM sfcrime2024 ORDER BY 1;

-- Unique resolution outcomes
SELECT DISTINCT Resolution FROM sfcrime2024 ORDER BY 1;

-- Step 4: Date range validation
-- -------------------------------------------------------
SELECT
    MIN(IncidentDate)                         AS earliest_date,
    MAX(IncidentDate)                         AS latest_date,
    DATEDIFF(MAX(IncidentDate), MIN(IncidentDate)) AS days_covered
FROM sfcrime2024;

SELECT
    MIN(IncidentDate)                         AS earliest_date,
    MAX(IncidentDate)                         AS latest_date,
    DATEDIFF(MAX(IncidentDate), MIN(IncidentDate)) AS days_covered
FROM sfcrime2025;

/*
  EDA ISSUES FOUND:
  - Some rows may have NULL Latitude/Longitude (location not recorded).
  - Both tables share the same 22-column schema -- safe to UNION ALL.
  - 2025 dataset has ~5.7% more incidents than 2024 (115,835 vs 109,626).
  - 'indetified' typo noted in original -- corrected to 'identified'.
*/

-- =============================================================
-- SECTION 4: CLEANING VIEW
-- =============================================================
-- Combines both years into one unified dataset.
-- Filters rows with missing category or district.
-- Adds derived time columns for downstream analysis.

CREATE OR REPLACE VIEW sfcrime_combined_clean AS
SELECT
    RowID,
    IncidentNumber,
    IncidentDate,
    IncidentTime,
    YEAR(IncidentDate)                   AS incident_year,
    MONTH(IncidentDate)                  AS incident_month,
    DAYNAME(IncidentDate)                AS day_of_week,
    IncidentCategory,
    IncidentDescription,
    Resolution,
    PoliceDistrict,
    Latitude,
    Longitude,
    '2024'                               AS data_year
FROM sfcrime2024
WHERE IncidentCategory IS NOT NULL
  AND PoliceDistrict   IS NOT NULL

UNION ALL

SELECT
    RowID,
    IncidentNumber,
    IncidentDate,
    IncidentTime,
    YEAR(IncidentDate)                   AS incident_year,
    MONTH(IncidentDate)                  AS incident_month,
    DAYNAME(IncidentDate)                AS day_of_week,
    IncidentCategory,
    IncidentDescription,
    Resolution,
    PoliceDistrict,
    Latitude,
    Longitude,
    '2025'                               AS data_year
FROM sfcrime2025
WHERE IncidentCategory IS NOT NULL
  AND PoliceDistrict   IS NOT NULL;


-- =============================================================
-- SECTION 5: YEAR-OVER-YEAR CRIME COMPARISON (2024 vs 2025)
-- =============================================================
-- Q: Is overall crime going up or down from 2024 to 2025?

-- 5a. Overall totals per year
SELECT
    data_year,
    COUNT(*) AS total_incidents
FROM sfcrime_combined_clean
GROUP BY data_year
ORDER BY data_year;

-- 5b. Year-over-Year change per crime category (JOIN approach)
SELECT
    a.category,
    a.incidents_2024,
    b.incidents_2025,
    (b.incidents_2025 - a.incidents_2024)              AS net_change,
    ROUND(
        (b.incidents_2025 - a.incidents_2024)
        / a.incidents_2024 * 100, 2
    )                                                   AS pct_change
FROM (
    SELECT IncidentCategory AS category,
           COUNT(*)         AS incidents_2024
    FROM sfcrime2024
    GROUP BY IncidentCategory
) a
JOIN (
    SELECT IncidentCategory AS category,
           COUNT(*)         AS incidents_2025
    FROM sfcrime2025
    GROUP BY IncidentCategory
) b ON a.category = b.category
ORDER BY pct_change DESC;

/*
  Interpretation:
  - A positive net_change means more incidents in 2025 for that category.
  - A negative net_change indicates improvement in that crime type.
  - Note: 2025 data completeness depends on collection cutoff date.
*/

-- =============================================================
-- SECTION 6: CRIME BREAKDOWNS
-- =============================================================

-- 6a. By Incident Category (type of crime)
-- -------------------------------------------------------
SELECT
    data_year,
    IncidentCategory,
    COUNT(*)                                            AS num_crimes,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY data_year), 2) AS pct_of_year
FROM sfcrime_combined_clean
GROUP BY data_year, IncidentCategory
ORDER BY data_year, num_crimes DESC;

/*
  Interpretation:
  - Larceny Theft is typically the most frequent category in SF.
  - Comparing pct_of_year shows if the crime MIX shifted, not just volume.
*/

-- 6b. By Police District (geographic breakdown)
-- -------------------------------------------------------
SELECT
    data_year,
    PoliceDistrict,
    COUNT(*)                                            AS num_crimes,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY data_year), 2) AS pct_of_year
FROM sfcrime_combined_clean
GROUP BY data_year, PoliceDistrict
ORDER BY data_year, num_crimes DESC;

/*
  Interpretation:
  - Tenderloin and Mission districts typically report the highest incident counts.
  - Districts with the largest YoY increases may warrant targeted policing.
*/

-- 6c. By Resolution Outcome
-- -------------------------------------------------------
SELECT
    data_year,
    Resolution,
    COUNT(*)                                            AS num_cases,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY data_year), 2) AS pct_of_year
FROM sfcrime_combined_clean
GROUP BY data_year, Resolution
ORDER BY data_year, num_cases DESC;

/*
  Interpretation:
  - 'Open or Active' cases = unresolved incidents.
  - 'Cite or Arrest, Adult' indicates cleared cases.
  - A rising share of open cases may indicate law enforcement capacity strain.
*/


-- =============================================================
-- SECTION 7: TIME-BASED ANALYSIS
-- =============================================================

-- 7a. Day of Week Pattern
-- -------------------------------------------------------
SELECT
    day_of_week,
    COUNT(*)                                             AS total_incidents,
    SUM(CASE WHEN data_year = '2024' THEN 1 ELSE 0 END) AS incidents_2024,
    SUM(CASE WHEN data_year = '2025' THEN 1 ELSE 0 END) AS incidents_2025
FROM sfcrime_combined_clean
GROUP BY day_of_week
ORDER BY
    FIELD(day_of_week, 'Sunday','Monday','Tuesday','Wednesday',
                        'Thursday','Friday','Saturday');

/*
  Interpretation:
  - Weekday vs weekend patterns reveal behavioral and operational trends.
  - Friday and Saturday typically see spikes in property crime and assaults.
*/

-- 7b. Seasonality (Monthly Breakdown)
-- -------------------------------------------------------
SELECT
    incident_month,
    MONTHNAME(IncidentDate)                              AS month_name,
    SUM(CASE WHEN data_year = '2024' THEN 1 ELSE 0 END) AS incidents_2024,
    SUM(CASE WHEN data_year = '2025' THEN 1 ELSE 0 END) AS incidents_2025,
    SUM(CASE WHEN data_year = '2025' THEN 1 ELSE 0 END)
    - SUM(CASE WHEN data_year = '2024' THEN 1 ELSE 0 END) AS monthly_change
FROM sfcrime_combined_clean
GROUP BY incident_month, month_name
ORDER BY incident_month;

/*
  Interpretation:
  - Summer months (June-August) often see elevated outdoor crime.
  - Months with the largest monthly_change drive the overall YoY variance.
*/

-- =============================================================
-- SECTION 8: NEIGHBORHOOD SAFETY RANKING
-- =============================================================
-- Definition of 'safety': fewer incidents per district = safer.
-- Caveat: population density and geographic area vary by district.
-- A district with high incidents may be densely populated, not inherently unsafe.

SELECT
    PoliceDistrict,
    SUM(CASE WHEN data_year = '2024' THEN 1 ELSE 0 END) AS incidents_2024,
    SUM(CASE WHEN data_year = '2025' THEN 1 ELSE 0 END) AS incidents_2025,
    COUNT(*)                                             AS total_incidents,
    RANK() OVER (ORDER BY COUNT(*) ASC)                  AS safety_rank
FROM sfcrime_combined_clean
GROUP BY PoliceDistrict
ORDER BY safety_rank;

/*
  Interpretation:
  - Rank 1 = fewest incidents = relatively safest district.
  - Last rank = highest incident count = most active crime district.
  - Note: This metric captures volume, not severity of crime.
  - For a severity-adjusted ranking, weight by offense classification.
*/

-- Top 5 most dangerous crime categories per district
SELECT
    PoliceDistrict,
    IncidentCategory,
    COUNT(*)                                             AS num_incidents,
    RANK() OVER
        (PARTITION BY PoliceDistrict ORDER BY COUNT(*) DESC) AS cat_rank
FROM sfcrime_combined_clean
GROUP BY PoliceDistrict, IncidentCategory
HAVING cat_rank <= 5
ORDER BY PoliceDistrict, cat_rank;


-- =============================================================
-- SECTION 9: SUMMARY FINDINGS
-- =============================================================
/*
  SF Crime 2024 vs 2025 -- Key Takeaways
  -------------------------------------------------------

  1. OVERALL VOLUME
     - 2024 recorded 109,626 incidents; 2025 recorded 115,835.
     - This represents approximately a 5.7% increase year-over-year.
     - Caveat: if 2025 data is not yet complete through year-end,
       the true annual change may differ.

  2. CRIME TYPE SHIFTS
     - Larceny Theft consistently dominates as the most common category.
     - Categories with the largest percentage increases warrant deeper
       investigation into root causes (economic conditions, policy changes).

  3. GEOGRAPHIC CONCENTRATION
     - Crime is not evenly distributed across SF's 10 police districts.
     - Tenderloin and Mission typically account for a disproportionate share.
     - Some districts may show improvement while others worsen.

  4. TEMPORAL PATTERNS
     - Day-of-week analysis shows consistent weekly cycles.
     - Seasonal peaks in summer months align with increased outdoor activity.

  5. RESOLUTION RATES
     - Tracking resolution outcomes reveals how many incidents remain open.
     - A declining resolution rate signals potential resource constraints.

  6. LINGERING QUESTIONS
     - Does the 2025 increase reflect actual crime growth or improved reporting?
     - Are there demographic or socioeconomic factors driving district-level spikes?
     - How does SF compare to other major cities (NYC, LA, Chicago) over same period?
     - Can incident description text be mined for more granular pattern detection?
*/

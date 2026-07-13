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
SELECT COUNT(*) AS total_rows_2025 FROM sfcrime2025;  -- Result: 121,194 (see Section 3 note)

-- TABLE DIMENSIONS SUMMARY
-- -------------------------------------------------------
-- sfcrime2024: 109,626 rows | 22 columns | all dated in calendar year 2024
-- sfcrime2025: 121,194 rows | 22 columns | NOT a clean single year -- see below
-- -------------------------------------------------------
-- IMPORTANT: despite its name, the "sfcrime2025" table is a rolling export
-- from SF's open data feed and is NOT limited to calendar year 2025.
-- Of its 121,194 rows, only 94,732 are actually dated in 2025; the
-- remaining 26,462 are incidents dated in early 2026 that had already
-- landed in the feed by extraction time. Every query in this script that
-- compares "2024" to "2025" therefore filters on the date-derived
-- incident_year column (Section 4), never on which source table a row
-- came from. Treating table membership as a proxy for calendar year was
-- an early mistake in this analysis (an all-rows-in-sfcrime2025 COUNT(*)
-- looks like a 2025 total but actually mixes in 2026 data) -- flagging it
-- here so it isn't repeated downstream.


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
-- This is the query that exposed the table/calendar-year mismatch: the
-- MAX(IncidentDate) for "sfcrime2025" lands in 2026, and days_covered is
-- well over 365 -- a clear signal that the table is not one clean year.
SELECT
    MIN(IncidentDate)                         AS earliest_date,
    MAX(IncidentDate)                         AS latest_date,
    DATEDIFF(MAX(IncidentDate), MIN(IncidentDate)) AS days_covered
FROM sfcrime2024;
-- Result: 2024-01-02 to 2024-12-31 (364 days covered) -- clean single year.

SELECT
    MIN(IncidentDate)                         AS earliest_date,
    MAX(IncidentDate)                         AS latest_date,
    DATEDIFF(MAX(IncidentDate), MIN(IncidentDate)) AS days_covered
FROM sfcrime2025;
-- Result: 2025-01-02 to 2026-04-25 (479 days covered) -- spans two years.

/*
  EDA ISSUES FOUND:
  - Some rows have NULL Latitude/Longitude (location not recorded at scene).
  - Both tables share the same 22-column schema -- safe to UNION ALL.
  - "sfcrime2025" is a rolling export, not a clean calendar year: 94,732
    rows are dated in 2025 and 26,462 are already dated in 2026. All
    year-over-year comparisons below use the derived incident_year column
    (from IncidentDate) and explicitly restrict to 2024/2025, never the
    source table alone.
  - 'indetified' typo noted in original -- corrected to 'identified'.
*/

-- =============================================================
-- SECTION 4: CLEANING VIEW
-- =============================================================
-- Combines both years into one unified dataset.
-- Filters rows with missing category or district.
-- Adds derived time columns for downstream analysis.
-- incident_year is derived from IncidentDate itself (not from which
-- source table the row came from) so it is unaffected by the 2025/2026
-- overlap described in Section 3 -- this is the column all comparisons
-- below group and filter on. source_table is kept only for provenance.

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
    'sfcrime2024'                        AS source_table
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
    'sfcrime2025'                        AS source_table
FROM sfcrime2025
WHERE IncidentCategory IS NOT NULL
  AND PoliceDistrict   IS NOT NULL;


-- =============================================================
-- SECTION 5: YEAR-OVER-YEAR CRIME COMPARISON (2024 vs 2025)
-- =============================================================
-- Q: Is overall crime going up or down from 2024 to 2025?
-- All totals below are restricted to incident_year IN (2024, 2025) so the
-- 26,462 already-2026-dated rows sitting in "sfcrime2025" never leak into
-- either bar of the comparison.

-- 5a. Overall totals per calendar year
SELECT
    incident_year,
    COUNT(*) AS total_incidents
FROM sfcrime_combined_clean
WHERE incident_year IN (2024, 2025)
GROUP BY incident_year
ORDER BY incident_year;
-- Result: 2024 = 109,342 | 2025 = 94,280 -> -13.78% YoY (a real decrease,
-- not the +5.7% a naive COUNT(*) FROM sfcrime2025 would suggest).

-- 5b. Year-over-Year change per crime category (JOIN approach)
SELECT
    yr2024.category,
    yr2024.incidents_2024,
    yr2025.incidents_2025,
    (yr2025.incidents_2025 - yr2024.incidents_2024)              AS net_change,
    ROUND(
        (yr2025.incidents_2025 - yr2024.incidents_2024)
        / yr2024.incidents_2024 * 100, 2
    )                                                             AS pct_change
FROM (
    SELECT IncidentCategory AS category,
           COUNT(*)         AS incidents_2024
    FROM sfcrime2024
    WHERE YEAR(IncidentDate) = 2024
    GROUP BY IncidentCategory
) yr2024
JOIN (
    SELECT IncidentCategory AS category,
           COUNT(*)         AS incidents_2025
    FROM sfcrime2025
    WHERE YEAR(IncidentDate) = 2025          -- excludes the 2026 spillover rows
    GROUP BY IncidentCategory
) yr2025 ON yr2024.category = yr2025.category
ORDER BY pct_change DESC;

/*
  Interpretation:
  - A positive net_change means more incidents in 2025 for that category.
  - A negative net_change indicates improvement in that crime type.
  - Largest increases: Drug Offense (+62.15%, 4,122 -> 6,684) and
    Warrant (+23.89%, 4,534 -> 5,617).
  - Largest decreases: Vandalism (-49.38%), Motor Vehicle Theft (-43.07%,
    7,226 -> 4,114), Recovered Vehicle (-42.40%), Burglary (-26.82%).
  - Larceny Theft, still the single largest category in both years, fell
    22.85% (26,318 -> 20,305).
*/

-- =============================================================
-- SECTION 6: CRIME BREAKDOWNS
-- =============================================================

-- 6a. By Incident Category (type of crime)
-- -------------------------------------------------------
SELECT
    incident_year,
    IncidentCategory,
    COUNT(*)                                            AS num_crimes,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY incident_year), 2) AS pct_of_year
FROM sfcrime_combined_clean
WHERE incident_year IN (2024, 2025)
GROUP BY incident_year, IncidentCategory
ORDER BY incident_year, num_crimes DESC;

/*
  Interpretation:
  - Larceny Theft is the most frequent category both years: 24.07% of all
    2024 incidents, 21.54% of 2025 -- still #1, but a smaller slice.
  - Comparing pct_of_year shows the crime MIX shifted (e.g. Drug Offense
    rose from 3.77% to 7.09% of the year), not just raw volume.
*/

-- 6b. By Police District (geographic breakdown)
-- -------------------------------------------------------
SELECT
    incident_year,
    PoliceDistrict,
    COUNT(*)                                            AS num_crimes,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY incident_year), 2) AS pct_of_year
FROM sfcrime_combined_clean
WHERE incident_year IN (2024, 2025)
GROUP BY incident_year, PoliceDistrict
ORDER BY incident_year, num_crimes DESC;

/*
  Interpretation:
  - 2024's top district was Mission (14,195, 12.98%); by 2025 Southern
    overtook it as the top district (14,841, 15.74%), with Mission second
    (13,480, 14.30%) and Tenderloin third (12,388, 13.14%).
  - Districts with the largest YoY increases may warrant targeted policing.
*/

-- 6c. By Resolution Outcome
-- -------------------------------------------------------
SELECT
    incident_year,
    Resolution,
    COUNT(*)                                            AS num_cases,
    ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY incident_year), 2) AS pct_of_year
FROM sfcrime_combined_clean
WHERE incident_year IN (2024, 2025)
GROUP BY incident_year, Resolution
ORDER BY incident_year, num_cases DESC;

/*
  Interpretation:
  - 'Open or Active' cases = unresolved incidents.
  - 'Cite or Arrest Adult' indicates cleared cases.
  - Clearance actually improved: Cite/Arrest Adult rose from 23.62% of
    cases in 2024 to 30.40% in 2025, while Open/Active fell from 75.70%
    to 68.89% -- consistent with the drop in overall incident volume.
*/


-- =============================================================
-- SECTION 7: TIME-BASED ANALYSIS
-- =============================================================

-- 7a. Day of Week Pattern
-- -------------------------------------------------------
SELECT
    day_of_week,
    COUNT(*)                                              AS total_incidents,
    SUM(CASE WHEN incident_year = 2024 THEN 1 ELSE 0 END) AS incidents_2024,
    SUM(CASE WHEN incident_year = 2025 THEN 1 ELSE 0 END) AS incidents_2025
FROM sfcrime_combined_clean
WHERE incident_year IN (2024, 2025)
GROUP BY day_of_week
ORDER BY
    FIELD(day_of_week, 'Sunday','Monday','Tuesday','Wednesday',
                        'Thursday','Friday','Saturday');

/*
  Interpretation:
  - Wednesday is the highest-volume day overall (31,120), followed closely
    by Friday (30,955); Sunday is the lowest (26,058).
  - Weekday vs weekend patterns reveal behavioral and operational trends.
*/

-- 7b. Seasonality (Monthly Breakdown)
-- -------------------------------------------------------
SELECT
    incident_month,
    MONTHNAME(IncidentDate)                                AS month_name,
    SUM(CASE WHEN incident_year = 2024 THEN 1 ELSE 0 END) AS incidents_2024,
    SUM(CASE WHEN incident_year = 2025 THEN 1 ELSE 0 END) AS incidents_2025,
    SUM(CASE WHEN incident_year = 2025 THEN 1 ELSE 0 END)
    - SUM(CASE WHEN incident_year = 2024 THEN 1 ELSE 0 END) AS monthly_change
FROM sfcrime_combined_clean
WHERE incident_year IN (2024, 2025)
GROUP BY incident_month, month_name
ORDER BY incident_month;

/*
  Interpretation:
  - Every single month of 2025 came in below its 2024 counterpart -- the
    decline is broad-based across the year, not driven by one outlier month.
  - 2024 ranged roughly 8,000-9,770 incidents/month; 2025 ranged roughly
    7,000-7,860/month.
*/

-- =============================================================
-- SECTION 8: NEIGHBORHOOD SAFETY RANKING
-- =============================================================
-- Definition of 'safety': fewer incidents per district = safer.
-- Caveat: population density and geographic area vary by district.
-- A district with high incidents may be densely populated, not inherently unsafe.
-- Ranking uses incident_year IN (2024, 2025) for the same reason as Section 5+6:
-- excluding the 2026 spillover keeps the ranking an honest two-year total.

SELECT
    PoliceDistrict,
    SUM(CASE WHEN incident_year = 2024 THEN 1 ELSE 0 END) AS incidents_2024,
    SUM(CASE WHEN incident_year = 2025 THEN 1 ELSE 0 END) AS incidents_2025,
    COUNT(*)                                               AS total_incidents,
    RANK() OVER (ORDER BY COUNT(*) ASC)                    AS safety_rank
FROM sfcrime_combined_clean
WHERE incident_year IN (2024, 2025)
GROUP BY PoliceDistrict
ORDER BY safety_rank;

/*
  Interpretation:
  - Rank 1 = fewest incidents = relatively safest district.
  - Result (combined 2024+2025): 1. Out of SF, 2. Park, 3. Richmond,
    4. Taraval, 5. Ingleside, 6. Bayview, 7. Central, 8. Northern,
    9. Tenderloin, 10. Mission, 11. Southern (least safe by volume).
  - Note: This metric captures volume, not severity of crime.
  - For a severity-adjusted ranking, weight by offense classification.
*/

-- Top 5 most frequent crime categories per district
SELECT
    PoliceDistrict,
    IncidentCategory,
    COUNT(*)                                             AS num_incidents,
    RANK() OVER
        (PARTITION BY PoliceDistrict ORDER BY COUNT(*) DESC) AS cat_rank
FROM sfcrime_combined_clean
WHERE incident_year IN (2024, 2025)
GROUP BY PoliceDistrict, IncidentCategory
HAVING cat_rank <= 5
ORDER BY PoliceDistrict, cat_rank;

/*
  Interpretation (combined 2024+2025):
  - Tenderloin's top category is Drug Offense (4,568), followed by Warrant
    (3,418) -- a very different mix from most districts.
  - Mission and Southern are both led by Larceny Theft (5,440 and 6,501
    respectively), consistent with the citywide pattern.
*/


-- =============================================================
-- SECTION 9: SUMMARY FINDINGS
-- =============================================================
/*
  SF Crime 2024 vs 2025 -- Key Takeaways
  -------------------------------------------------------

  1. OVERALL VOLUME
     - 2024 recorded 109,342 clean incidents; 2025 recorded 94,280
       (both restricted to their true calendar year).
     - This represents a 13.78% DECREASE year-over-year.
     - This corrects an earlier reading of this data: a raw COUNT(*) on
       the "sfcrime2025" table (121,194 rows) looks like a 5.7% increase
       over 2024, but 26,462 of those rows are actually dated in 2026.
       Filtering to true calendar years reverses the conclusion.

  2. CRIME TYPE SHIFTS
     - Larceny Theft still dominates as the most common category in both
       years (24.07% of 2024, 21.54% of 2025) despite falling 22.85%.
     - Drug Offense saw the largest increase, +62.15% (4,122 -> 6,684),
       followed by Warrant, +23.89% (4,534 -> 5,617).
     - Motor Vehicle Theft fell 43.07% and Burglary fell 26.82%.

  3. GEOGRAPHIC CONCENTRATION
     - Crime is not evenly distributed across SF's 10 police districts.
     - Southern district overtook Mission as the highest-volume district
       in 2025 (14,841 vs 13,480); Southern is also least safe by total
       two-year volume (28,752), Out of SF and Park the safest.

  4. TEMPORAL PATTERNS
     - Wednesday and Friday are the highest-volume days of the week.
     - Every month of 2025 came in below its 2024 counterpart -- the
       decline is broad-based, not driven by a single outlier month.

  5. RESOLUTION RATES
     - Cases cleared via Cite/Arrest Adult rose from 23.62% (2024) to
       30.40% (2025), while Open/Active cases fell from 75.70% to 68.89%
       -- clearance improved alongside the drop in incident volume.

  6. LINGERING QUESTIONS
     - Does the 2025 decrease reflect actual crime reduction or a
       reporting/backlog lag (2025 cases still being processed/reclassified)?
     - Are there demographic or socioeconomic factors driving district-level
       divergence (e.g. Southern's rise vs Mission's relative plateau)?
     - How does SF compare to other major cities (NYC, LA, Chicago) over
       the same period?
     - Can incident description text be mined for more granular pattern
       detection?
*/

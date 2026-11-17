# HealthConnect Rwanda: Healthcare Operations and Performance Analytics

**Programme:** AnalystLab Africa Experience Lab, Week 6
**Track:** Data Analytics
**Author:** Oluwayomi Precious Similoluwa
**Tools:** PostgreSQL, SQL, Power BI, DAX

## Overview

HealthConnect Rwanda needs one trusted view of its patients, appointments, clinical activity, finances, staff and patient experience. This project loads 27 healthcare datasets into PostgreSQL, answers 40 business questions in SQL and presents the results in a six-page interactive Power BI dashboard.

## Headline findings

- Facilities have almost identical staff, beds and equipment, but appointments range from 225 to 290 per facility (a 29% gap).
- Of 9.31 billion billed, 8.39 billion was collected (90.1%). About 920 million is outstanding and half of insurance claims are pending.
- Average patient satisfaction is 2.99 out of 5, with poor and excellent ratings about equally common.
- About 27% of patients are over 65 and 74.6% have a chronic condition.
- Data quality limits the analysis: only 8% of bills, diagnoses and feedback link to an appointment, and there is no admission, laboratory, prescription or referral data.

## Repository structure

```
Week6_DataAnalytics_HealthConnect_OluwayomiPrecious/
├── Data/            original datasets (unchanged)
├── Database/        healthconnect_rwanda.backup, load_healthconnect.py
├── SQL/             healthconnect_queries.sql
├── Dashboard/       HealthConnect_Analytics.pbix, Executive_Dashboard.pdf
├── Report/          Business_Insights_Report (PDF or Word)
├── Presentation/    Executive_Presentation (PPT or PDF)
├── Validation/      KPI_Validation_Sheet.csv
├── Images/          dashboard and data model screenshots
└── README.md
```

## How to reproduce

**1. Create the database.** Install PostgreSQL and pgAdmin, then create a database called `healthconnect_rwanda`.

**2. Load the data (either way).**
- *Restore the backup:* right-click the database in pgAdmin, choose **Restore**, select `Database/healthconnect_rwanda.backup`, format **Custom or tar**. (Needs PostgreSQL 16 or newer.)
- *Or run the loader:* edit the password and folder at the top of `Database/load_healthconnect.py`, then run `python load_healthconnect.py`.

**3. Run the SQL.** Open `SQL/healthconnect_queries.sql` in the pgAdmin Query Tool. First run sections **A4 to A7** (they create the clean views), then run any of the 40 queries (Q1 to Q40) by selecting it and pressing F5.

**4. Open the dashboard.** Open `Dashboard/HealthConnect_Analytics.pbix` in Power BI Desktop, and point the PostgreSQL connection at `localhost` and `healthconnect_rwanda` if prompted.

## Dashboard pages

| Page | Contents |
|---|---|
| Executive | KPI cards, appointment and revenue trends, revenue by facility, visit types |
| Patient Analytics | Gender, age pyramid, province and district drill-down, chronic conditions, insurance |
| Clinical Analytics | Diagnoses, severity, diagnosis-by-severity matrix, weekday and visit type |
| Financial | Revenue trend with forecast, revenue by department and facility, claims, payment methods, key influencers |
| Operational | Staff by role, appointments per bed and per staff member, equipment, facility and department comparison |
| Patient Experience | Ratings, feedback, poor and excellent trends, hospital and department ranking |

## Data model

A single filter path: Patients, Appointments, Departments, Facilities, plus Billing (with Payments and Claims), Feedback, Diagnoses, Rooms and Beds, Equipment, a combined Staff table and a Date table. 41 DAX measures cover patients, appointments, clinical, staff, finance and experience, including month-on-month growth and year-to-date revenue.

## Validation and testing

Dashboard figures were compared with independent SQL results (`Validation/KPI_Validation_Sheet.csv`, 36 tests). Two facility tests failed at first because an appointment's recorded facility conflicts with the facility that owns its department in 95% of records. The SQL views were changed to use the department's facility, matching the Power BI model, and the retest passed.

## Assumptions and data limitations

- **Missing data:** no admissions, laboratory tests, prescriptions, referrals or cancellations. Admission rate, length of stay, readmission, referral rate, top medications and test volumes are therefore not reported.
- **Proxies:** bed utilisation is shown as appointments per bed (every bed is recorded as Available). Revenue by service uses visit type and department. Equipment availability cannot be measured.
- **Facilities** have IDs only (HF001 to HF020), with no names, province or ownership, so regional investment cannot be assessed directly.
- **Linked data:** facility, department and monthly splits cover about 8% of bills, diagnoses and feedback. Totals use all rows, and unlinked rows appear as (Blank).
- **Facility attribution:** the department's facility is used throughout.
- **Currency:** not stated in the data; Rwandan francs assumed.
- **Data quality:** nearly all patients share ten phone numbers; about 90% of bills marked Paid are not fully paid.
- **Forecast:** based on one year of data and illustrative only.

## Power BI feature status

Done: KPI cards, slicers, matrix tables, DAX measures, dynamic titles, navigation buttons, hierarchy, key influencers, forecasting.
Not completed: decomposition tree. (Update this list to match your final file for tooltips, conditional formatting, drill-through, bookmarks and map.)

## Recommendations (summary)

Allocate staff by demand; add capacity at the busiest facilities; run a collection drive on outstanding bills; clear the claims backlog; review low-scoring departments and facilities; start older-adult and chronic care programmes; fix facility and appointment links in the source data; record admissions, laboratory tests, prescriptions and referrals; add facility names and provinces; review the dashboard monthly. Full detail is in the report.

---
*AnalystLab Africa Experience Lab. #AnalystLabAfrica*


# HealthConnect Rwanda: Weeks 7 and 8 (Testing, Refinement and Final Package)

**Programme:** AnalystLab Africa Experience Lab
**Track:** Data Analytics
**Author:** Oluwayomi Precious Similoluwa
**Builds on:** Week 6 (database, SQL and six-page Power BI dashboard)

## Week 7: Analytics Testing and Refinement

The Week 6 outputs were tested for accuracy, consistency and usefulness.

- **KPI and filter validation:** 36 checks compared Power BI values with independent SQL results (`Validation/KPI_Validation_Sheet.csv`). 34 matched at first; 2 failed and passed after a fix.
- **Issue found and fixed:** an appointment's recorded facility matches the facility that owns its department in only 5.1% of records. SQL used the recorded facility and Power BI used the department's. The SQL views were redefined to use the department's facility, and the retest matched (HF004: 290 appointments).
- **Dashboard refinements (before and after):** unlinked (Blank) bars removed from revenue charts; months sorted by calendar order; rates shown as percentages; revenue cards shown in billions; an uninformative chart replaced with appointments per staff member; a confusing slicer replaced.
- **Segment testing:** 12 statistical tests (`Validation/week7_segment_tests.py`, results in `Validation/segment_test_results.csv`) showed that differences between facilities, departments, months and satisfaction scores are within random variation. Rankings are therefore treated as descriptive only, and earlier recommendations based on them were withdrawn.

Report: *HealthConnect Analytics Testing and Refinement Report (Week 7)*.

## Week 8: Final Analytics and Decision Support Package

- Week 7 to Week 8 transition note and final integration readiness table.
- Final KPIs, validated findings, insights, ten prioritised recommendations and limitations.
- Executive presentation: `HealthConnect_Week8_Presentation.pptx` (14 slides).

Report: *HealthConnect Final Analytics and Decision Support Package (Week 8)*.

## Main conclusions

1. About 920 million (9.9%) of billing is uncollected, and about half of insurance claims are pending.
2. The population is older and chronically ill (27% over 65; 74.6% with a chronic condition).
3. Satisfaction averages 2.99 out of 5 with no significant difference by facility, department or province.
4. Staffing, beds and equipment are identical across facilities, and appointment differences are not beyond chance.
5. Missed appointments cannot be measured: the data has no attendance, cancellation or no-show field. Recording it is the first recommendation.

## Limitations

- No attendance, cancellation, admission, laboratory, prescription or referral data.
- Splits by facility, department and month use only about 8% of records that link to an appointment.
- Facilities are IDs only; the department's facility is used for facility analysis.
- The forecast is illustrative; the decomposition tree was not completed.
- No cross-track testing has been carried out; findings are ready to share with other tracks.

## Suggested repository additions

```
Week7_Week8/
├── Reports/       Week 7 report, Week 8 package (PDF or Word)
├── Presentation/  HealthConnect_Week8_Presentation.pptx
├── Validation/    KPI_Validation_Sheet.csv, week7_segment_tests.py, segment_test_results.csv
├── SQL/           healthconnect_queries.sql (updated), fix_views.sql
└── README.md
```

*AnalystLab Africa Experience Lab. #AnalystLabAfrica*

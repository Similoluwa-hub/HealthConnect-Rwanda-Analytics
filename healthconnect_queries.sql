-- =====================================================================
-- A4. Clean view: patients with location hierarchy and age group
CREATE OR REPLACE VIEW v_patient AS
SELECT p.patientid, p.firstname, p.lastname, p.gender, p.dateofbirth, p.age,
       p.bloodgroup, p.insuranceid, p.phone, p.status,
       COALESCE(p.chroniccondition, 'None') AS chronic_condition,
       (p.chroniccondition IS NOT NULL)      AS has_chronic,
       CASE WHEN p.age < 18 THEN '0-17' WHEN p.age < 35 THEN '18-34'
            WHEN p.age < 50 THEN '35-49' WHEN p.age < 65 THEN '50-64' ELSE '65+' END AS age_group,
       v.villagename, s.sectorname, d.districtname, pr.provincename
FROM patients p
JOIN villages v   ON v.villageid  = p.villageid
JOIN sectors s    ON s.sectorid   = v.sectorid
JOIN districts d  ON d.districtid = s.districtid
JOIN provinces pr ON pr.provinceid = d.provinceid;

-- A5. Clean view: appointments with department, doctor and patient province
-- (facility = the facility that owns the department; drops the old views first)
DROP VIEW IF EXISTS v_billing_linked;
DROP VIEW IF EXISTS v_appointment;
CREATE VIEW v_appointment AS
SELECT a.appointmentid, a.patientid, a.doctorid, dep.facilityid AS facilityid,
       a.facilityid AS recorded_facilityid, a.departmentid,
       a.date AS appt_date, to_char(a.date, 'YYYY-MM') AS appt_month,
       a.visittype, dep.departmentname,
       doc.firstname || ' ' || doc.lastname AS doctor_name,
       pv.provincename
FROM appointments a
JOIN departments dep ON dep.departmentid = a.departmentid
LEFT JOIN doctors doc ON doc.staffid = a.doctorid
LEFT JOIN v_patient pv ON pv.patientid = a.patientid;

-- A6. Clean view: billing with amount paid and outstanding (all 60,000 bills)
CREATE OR REPLACE VIEW v_billing AS
SELECT b.billingid, b.appointmentid, b.amount, b.status AS bill_status,
       COALESCE(p.paid, 0) AS paid,
       b.amount - COALESCE(p.paid, 0) AS outstanding
FROM billing b
LEFT JOIN (SELECT billingid, SUM(amountpaid) AS paid FROM payments GROUP BY billingid) p
       ON p.billingid = b.billingid;

-- A7. Clean view: billing that links to an appointment (5,000 rows)
CREATE OR REPLACE VIEW v_billing_linked AS
SELECT vb.*, va.facilityid, va.departmentid, va.departmentname, va.visittype,
       va.appt_month, va.provincename
FROM v_billing vb
JOIN v_appointment va ON va.appointmentid = vb.appointmentid;

--Q1. Retrieve all registered patients
SELECT patientid, firstname, lastname, gender, age, bloodgroup, insuranceid,
       chronic_condition, provincename
FROM v_patient
ORDER BY patientid;

-- Q2. Count patients by gender
SELECT gender, COUNT(*) AS patients,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM patients GROUP BY gender ORDER BY patients DESC;

-- Q3. Count patients by province
SELECT provincename, COUNT(*) AS patients
FROM v_patient GROUP BY provincename ORDER BY patients DESC;

-- Q4. Patients above 65 years
SELECT patientid, firstname, lastname, gender, age, provincename
FROM v_patient WHERE age > 65 ORDER BY age DESC, patientid;

-- Q5. Patients with chronic diseases (count by condition)
SELECT chronic_condition, COUNT(*) AS patients
FROM v_patient WHERE has_chronic
GROUP BY chronic_condition ORDER BY patients DESC;

-- Q6. Patients covered by insurance (every patient has an insurance ID)
SELECT COUNT(*) FILTER (WHERE insuranceid IS NOT NULL) AS insured_patients,
       COUNT(*) AS total_patients,
       ROUND(100.0 * COUNT(*) FILTER (WHERE insuranceid IS NOT NULL) / COUNT(*), 1) AS coverage_pct
FROM patients;


-- Q7. Count patients by blood group
SELECT bloodgroup, COUNT(*) AS patients FROM patients
GROUP BY bloodgroup ORDER BY patients DESC;

-- Q8. Youngest and oldest patients
(SELECT 'Youngest' AS category, patientid, firstname, lastname, age, dateofbirth
   FROM patients ORDER BY dateofbirth DESC, patientid LIMIT 5)
UNION ALL
(SELECT 'Oldest', patientid, firstname, lastname, age, dateofbirth
   FROM patients ORDER BY dateofbirth ASC, patientid LIMIT 5);

-- Q9. Duplicate phone numbers (phones shared by more than one patient)
SELECT phone, COUNT(*) AS patients_sharing
FROM patients GROUP BY phone HAVING COUNT(*) > 1
ORDER BY patients_sharing DESC LIMIT 20;

-- Q10. Average patient age
SELECT ROUND(AVG(age), 1) AS average_age, MIN(age) AS youngest, MAX(age) AS oldest FROM patients;

-- Q11. Appointments by month
SELECT appt_month, COUNT(*) AS appointments
FROM v_appointment GROUP BY appt_month ORDER BY appt_month;


-- Q12. Busiest hospitals (facilities)
SELECT facilityid, COUNT(*) AS appointments
FROM appointments GROUP BY facilityid ORDER BY appointments DESC;

-- Q13. Busiest departments
SELECT departmentname, COUNT(*) AS appointments
FROM v_appointment GROUP BY departmentname ORDER BY appointments DESC;

-- Q14. Doctors with the highest workload (top 10)
SELECT doctorid, doctor_name, COUNT(*) AS appointments
FROM v_appointment GROUP BY doctorid, doctor_name
ORDER BY appointments DESC, doctorid LIMIT 10;

-- Q15. Referral patterns (PROXY: no referral table; patients seen at more than one facility)
SELECT facilities_visited, COUNT(*) AS patients
FROM (SELECT patientid, COUNT(DISTINCT facilityid) AS facilities_visited
      FROM appointments GROUP BY patientid) t
GROUP BY facilities_visited ORDER BY facilities_visited;

-- Q16. Emergency appointments (overall and by facility)
SELECT facilityid,
       COUNT(*) FILTER (WHERE visittype = 'Emergency') AS emergency,
       COUNT(*) AS total,
       ROUND(100.0 * COUNT(*) FILTER (WHERE visittype = 'Emergency') / COUNT(*), 1) AS emergency_pct
FROM appointments GROUP BY facilityid ORDER BY emergency DESC;

-- Q17. Average appointments per doctor
SELECT (SELECT COUNT(*) FROM appointments) AS appointments,
       (SELECT COUNT(*) FROM doctors) AS doctors,
       ROUND((SELECT COUNT(*) FROM appointments)::numeric / (SELECT COUNT(*) FROM doctors), 2) AS avg_per_doctor;

-- Q18. Appointments by province (province of the patient's home village)
SELECT provincename, COUNT(*) AS appointments
FROM v_appointment GROUP BY provincename ORDER BY appointments DESC;

-- Q19. Facilities with the highest patient volume (unique patients)
SELECT facilityid, COUNT(DISTINCT patientid) AS unique_patients, COUNT(*) AS appointments
FROM appointments GROUP BY facilityid ORDER BY unique_patients DESC;

-- Q20. Peak consultation periods (dates only, no time of day in the data)
SELECT to_char(appt_date, 'Dy') AS weekday, EXTRACT(ISODOW FROM appt_date) AS day_no,
       COUNT(*) AS consultations
FROM v_appointment WHERE visittype = 'Consultation'
GROUP BY 1, 2 ORDER BY consultations DESC;

-- Q21. Top diagnoses (only 5 diagnosis types exist in the data)
SELECT diagnosis, COUNT(*) AS cases,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM diagnoses GROUP BY diagnosis ORDER BY cases DESC LIMIT 20;

-- Q22. Most requested laboratory tests: DATA GAP, no lab test table.
--      PROXY: laboratory scientists available per facility
SELECT facilityid, COUNT(*) AS lab_scientists
FROM lab_scientists GROUP BY facilityid ORDER BY lab_scientists DESC;

-- Q23. Most prescribed medications: DATA GAP, no prescriptions table.
--      PROXY: pharmacists available per facility
SELECT facilityid, COUNT(*) AS pharmacists
FROM pharmacists GROUP BY facilityid ORDER BY pharmacists DESC;

-- Q24. Average admission duration: DATA GAP, no admissions table.
--      PROXY: bed inventory and status per facility
SELECT rm.facilityid, COUNT(*) AS beds,
       COUNT(*) FILTER (WHERE b.status = 'Available') AS available_beds
FROM beds b JOIN rooms rm ON rm.roomid = b.roomid
GROUP BY rm.facilityid ORDER BY rm.facilityid;

-- Q25. Disease severity distribution
SELECT severity, COUNT(*) AS cases,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM diagnoses GROUP BY severity ORDER BY cases DESC;

-- Q26. Laboratory test utilisation (PROXY: appointments per lab scientist by facility)
SELECT a.facilityid, a.appointments, COALESCE(l.lab_scientists, 0) AS lab_scientists,
       ROUND(a.appointments::numeric / NULLIF(l.lab_scientists, 0), 1) AS appointments_per_scientist
FROM (SELECT facilityid, COUNT(*) AS appointments FROM appointments GROUP BY facilityid) a
LEFT JOIN (SELECT facilityid, COUNT(*) AS lab_scientists FROM lab_scientists GROUP BY facilityid) l
       ON l.facilityid = a.facilityid
ORDER BY appointments_per_scientist DESC NULLS LAST;

-- Q27. Prescription trends: DATA GAP. PROXY: monthly appointment demand
SELECT appt_month, COUNT(*) AS appointments
FROM v_appointment GROUP BY appt_month ORDER BY appt_month;

-- Q28. Referral destinations (PROXY: facility a patient visits after a different facility)
SELECT from_facility, to_facility, COUNT(*) AS transfers
FROM (SELECT facilityid AS to_facility,
             LAG(facilityid) OVER (PARTITION BY patientid ORDER BY date, appointmentid) AS from_facility
      FROM appointments) t
WHERE from_facility IS NOT NULL AND from_facility <> to_facility
GROUP BY from_facility, to_facility ORDER BY transfers DESC LIMIT 15;

-- Q29. Admission rate by diagnosis: DATA GAP. PROXY: share of severe cases per diagnosis
SELECT diagnosis, COUNT(*) AS cases,
       COUNT(*) FILTER (WHERE severity = 'Severe') AS severe_cases,
       ROUND(100.0 * COUNT(*) FILTER (WHERE severity = 'Severe') / COUNT(*), 1) AS severe_pct
FROM diagnoses GROUP BY diagnosis ORDER BY severe_pct DESC;


-- Q30. Clinical workload by department
SELECT departmentname, COUNT(*) AS appointments, COUNT(DISTINCT doctorid) AS doctors_involved,
       ROUND(COUNT(*)::numeric / COUNT(DISTINCT doctorid), 1) AS appointments_per_doctor
FROM v_appointment GROUP BY departmentname ORDER BY appointments DESC;

-- Q31. Revenue by facility (billed and collected, linked bills)
SELECT facilityid, COUNT(*) AS bills, SUM(amount) AS billed, SUM(paid) AS collected
FROM v_billing_linked GROUP BY facilityid ORDER BY billed DESC;

-- Q32. Revenue by department
SELECT departmentname, COUNT(*) AS bills, SUM(amount) AS billed, SUM(paid) AS collected
FROM v_billing_linked GROUP BY departmentname ORDER BY billed DESC;

-- Q33. Revenue by service (PROXY: visit type, as no service ID is recorded on bills)
SELECT visittype AS service_type, COUNT(*) AS bills, SUM(amount) AS billed, SUM(paid) AS collected
FROM v_billing_linked GROUP BY visittype ORDER BY billed DESC;

-- Q34. Insurance claims by provider (all claims)
SELECT provider, COUNT(*) AS claims, SUM(claimamount) AS claimed,
       COUNT(*) FILTER (WHERE status = 'Approved') AS approved,
       ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'Approved') / COUNT(*), 1) AS approval_rate_pct
FROM insurance_claims GROUP BY provider ORDER BY claimed DESC;

-- Q35. Outstanding payments (all bills)
SELECT bill_status, COUNT(*) AS bills, SUM(amount) AS billed, SUM(paid) AS paid,
       SUM(GREATEST(outstanding, 0)) AS outstanding
FROM v_billing GROUP BY bill_status ORDER BY outstanding DESC;

-- Q36. Average billing amount
SELECT ROUND(AVG(amount), 0) AS average_bill, MIN(amount) AS smallest, MAX(amount) AS largest,
       ROUND(AVG(amount) FILTER (WHERE status = 'Paid'), 0) AS avg_paid_bill
FROM billing;

-- Q37a. Monthly revenue trend (linked bills, by appointment month)
SELECT appt_month, COUNT(*) AS bills, SUM(amount) AS billed, SUM(paid) AS collected
FROM v_billing_linked GROUP BY appt_month ORDER BY appt_month;

-- Q37b. Monthly revenue per the revenue summary table
SELECT month, revenue, appointments FROM revenue_summary ORDER BY month;

-- Q38. Payment methods (all payments)
SELECT method, COUNT(*) AS payments, SUM(amountpaid) AS amount_paid,
       ROUND(100.0 * SUM(amountpaid) / SUM(SUM(amountpaid)) OVER (), 1) AS share_pct
FROM payments GROUP BY method ORDER BY amount_paid DESC;

-- Q39. Top revenue-generating hospitals (top 10, linked bills)
SELECT facilityid, SUM(amount) AS billed
FROM v_billing_linked GROUP BY facilityid ORDER BY billed DESC LIMIT 10;

-- Q40. Financial performance ranking (collection rate, linked bills)
SELECT facilityid, SUM(amount) AS billed, SUM(paid) AS collected,
       ROUND(100.0 * SUM(paid) / SUM(amount), 1) AS collection_rate_pct,
       RANK() OVER (ORDER BY SUM(paid) / SUM(amount) DESC) AS performance_rank
FROM v_billing_linked GROUP BY facilityid ORDER BY performance_rank;

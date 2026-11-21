-- =====================================================================
-- INFOMAN1 Midterm Practical Assessment: Task 6
-- Schema Evolution & Cross-Week Synthesis
-- Database: eventhub_midterm
--
-- Run AFTER task3_dml_operations.sql (the tables must contain data).
-- Not idempotent: re-running the ALTER fails because the column exists.
-- Run with --force because step 3 deliberately violates the CHECK.
-- =====================================================================

USE eventhub_midterm;

-- ---------------------------------------------------------------------
-- 1. Schema evolution: add venue_status with DEFAULT and CHECK
-- Existing rows are backfilled with 'ACTIVE'.
-- ---------------------------------------------------------------------
ALTER TABLE venue
    ADD COLUMN venue_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    ADD CONSTRAINT chk_venue_status
        CHECK (venue_status IN ('ACTIVE', 'RENOVATION', 'INACTIVE'));

SELECT venue_code, venue_name, venue_status
FROM venue
ORDER BY venue_code;

-- ---------------------------------------------------------------------
-- 2. Targeted update by primary key
-- ---------------------------------------------------------------------
UPDATE venue
SET venue_status = 'RENOVATION'
WHERE venue_code = 'V-PARK';

SELECT venue_code, venue_name, venue_status
FROM venue
ORDER BY venue_code;

-- ---------------------------------------------------------------------
-- 3. Constraint test (expected ERROR 3819)
-- ---------------------------------------------------------------------
UPDATE venue
SET venue_status = 'CLOSED'
WHERE venue_code = 'V-METRO';

-- ---------------------------------------------------------------------
-- 4. Integrated synthesis report
-- Active venues only; grouped by venue; aggregate filter; ordered.
-- ---------------------------------------------------------------------
SELECT v.venue_name,
       v.venue_city,
       COUNT(*)                              AS total_bookings,
       SUM(s.tickets_booked)                 AS total_attendees,
       ROUND(AVG(s.ticket_price), 2)         AS avg_ticket_price,
       SUM(s.tickets_booked * s.ticket_price) AS total_revenue
FROM venue AS v
JOIN booking AS b ON b.venue_code = v.venue_code
JOIN session AS s ON s.booking_id = b.booking_id
WHERE v.venue_status = 'ACTIVE'
GROUP BY v.venue_code, v.venue_name, v.venue_city
HAVING AVG(s.ticket_price) > 300.00
ORDER BY total_revenue DESC;

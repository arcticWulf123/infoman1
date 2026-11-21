-- =====================================================================
-- INFOMAN1 Midterm Practical Assessment: Task 3
-- Data Migration & Safe DML Operations
-- Database: eventhub_midterm
--
-- Run this AFTER task2_schema_ddl.sql has created empty tables.
-- The script is not idempotent: re-running it will hit duplicate keys.
-- Run with --force because the final INSERT deliberately fails the CHECK.
-- =====================================================================

USE eventhub_midterm;

-- ---------------------------------------------------------------------
-- 1. MIGRATION FROM event_booking_flat
-- SELECT DISTINCT collapses the repeated groups into one row per entity.
-- ---------------------------------------------------------------------

-- 1.1 Organizers (4 rows)
INSERT INTO organizer (organizer_id, organizer_name, organizer_email)
SELECT DISTINCT organizer_id, organizer_name, organizer_email
FROM event_booking_flat;

-- 1.2 Venues (3 rows)
INSERT INTO venue (venue_code, venue_name, venue_city, venue_capacity)
SELECT DISTINCT venue_code, venue_name, venue_city, venue_capacity
FROM event_booking_flat;

-- 1.3 Bookings (6 rows)
INSERT INTO booking (booking_id, booking_date, event_title, organizer_id, venue_code)
SELECT DISTINCT booking_id, booking_date, event_title, organizer_id, venue_code
FROM event_booking_flat;

-- 1.4 Sessions (7 rows)
INSERT INTO session (booking_id, session_code, ticket_category, ticket_price, tickets_booked)
SELECT DISTINCT booking_id, session_code, ticket_category, ticket_price, tickets_booked
FROM event_booking_flat;

-- 1.5 Helper table for splitting the comma list (max 2 speakers per row)
DROP TEMPORARY TABLE IF EXISTS digits;
CREATE TEMPORARY TABLE digits (n INT PRIMARY KEY);
INSERT INTO digits VALUES (1), (2), (3), (4), (5);

-- 1.6 Speakers (7 rows), one atomic name per row
-- TRIM removes the space after each comma in the original speaker_list.
INSERT IGNORE INTO speaker (speaker_name)
SELECT DISTINCT TRIM(
           SUBSTRING_INDEX(SUBSTRING_INDEX(f.speaker_list, ',', d.n), ',', -1)
       ) AS speaker_name
FROM event_booking_flat AS f
JOIN digits AS d
  ON d.n <= 1 + (LENGTH(f.speaker_list) - LENGTH(REPLACE(f.speaker_list, ',', '')))
WHERE f.speaker_list IS NOT NULL
  AND f.speaker_list <> '';

-- 1.7 SessionSpeaker junction (11 rows)
-- Speakers have surrogate IDs, so join by the split name to recover them.
INSERT IGNORE INTO sessionspeaker (booking_id, session_code, speaker_id)
SELECT DISTINCT
       f.booking_id,
       f.session_code,
       sp.speaker_id
FROM event_booking_flat AS f
JOIN digits AS d
  ON d.n <= 1 + (LENGTH(f.speaker_list) - LENGTH(REPLACE(f.speaker_list, ',', '')))
JOIN speaker AS sp
  ON sp.speaker_name = TRIM(
         SUBSTRING_INDEX(SUBSTRING_INDEX(f.speaker_list, ',', d.n), ',', -1)
     )
WHERE f.speaker_list IS NOT NULL
  AND f.speaker_list <> '';

-- ---------------------------------------------------------------------
-- 2. RECONCILIATION (must run before the price update)
-- Expected: 4 / 3 / 6 / 7 / 7 / 11 rows; 31 tickets and 14800.00 revenue.
-- ---------------------------------------------------------------------
SELECT 'organizer' AS table_name, COUNT(*) AS rows_inserted FROM organizer
UNION ALL SELECT 'venue',          COUNT(*) FROM venue
UNION ALL SELECT 'booking',        COUNT(*) FROM booking
UNION ALL SELECT 'session',        COUNT(*) FROM session
UNION ALL SELECT 'speaker',        COUNT(*) FROM speaker
UNION ALL SELECT 'sessionspeaker', COUNT(*) FROM sessionspeaker;

SELECT
    (SELECT SUM(tickets_booked) FROM session)                AS normalized_tickets,
    (SELECT SUM(tickets_booked) FROM event_booking_flat)     AS flat_tickets,
    (SELECT SUM(tickets_booked * ticket_price) FROM session) AS normalized_revenue,
    (SELECT SUM(tickets_booked * ticket_price) FROM event_booking_flat) AS flat_revenue;

-- ---------------------------------------------------------------------
-- 3. NEW VENUE
-- ---------------------------------------------------------------------
INSERT INTO venue (venue_code, venue_name, venue_city, venue_capacity)
VALUES ('V-CAMPUS', 'University Amphitheater', 'Quezon City', 500);

-- ---------------------------------------------------------------------
-- 4. SAFE CHANGE LOOP: 10% price increase where price > 400.00
-- ---------------------------------------------------------------------
-- Step 1: preview the target rows
SELECT booking_id, session_code, ticket_category, ticket_price,
       ROUND(ticket_price * 1.10, 2) AS new_price
FROM session
WHERE ticket_price > 400.00
ORDER BY booking_id, session_code;

-- Step 2: confirm the target count (expected 4)
SELECT COUNT(*) AS target_rows
FROM session
WHERE ticket_price > 400.00;

-- Step 3: execute the update
UPDATE session
SET ticket_price = ROUND(ticket_price * 1.10, 2)
WHERE ticket_price > 400.00;

-- Step 4: verify the new prices
SELECT booking_id, session_code, ticket_category, ticket_price
FROM session
ORDER BY ticket_price DESC;

-- ---------------------------------------------------------------------
-- 5. SAFE CHANGE LOOP: DELETE V-TEMP
-- ---------------------------------------------------------------------
INSERT INTO venue (venue_code, venue_name, venue_city, venue_capacity)
VALUES ('V-TEMP', 'Temporary Venue', 'Manila', 50);

-- Step 1: preview the target row
SELECT * FROM venue WHERE venue_code = 'V-TEMP';

-- Step 2: confirm the target count (expected 1)
SELECT COUNT(*) AS target_rows FROM venue WHERE venue_code = 'V-TEMP';

-- Step 3: execute the delete by primary key
DELETE FROM venue WHERE venue_code = 'V-TEMP';

-- Step 4: verify the row is gone (expected 0)
SELECT COUNT(*) AS remaining FROM venue WHERE venue_code = 'V-TEMP';

-- ---------------------------------------------------------------------
-- 6. CONSTRAINT PROTECTION TEST (expected ERROR 3819)
-- booking_id 101 exists, so only the CHECK constraint can reject this.
-- ---------------------------------------------------------------------
INSERT INTO session (booking_id, session_code, ticket_category, ticket_price, tickets_booked)
VALUES (101, 'SESS-CHK', 'Standard', -100.00, 0);

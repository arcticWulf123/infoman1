-- =====================================================================
-- INFOMAN1 Midterm Practical Assessment: Task 5
-- Multi-Table Joins & Outer Join Diagnostics
-- Database: eventhub_midterm
-- =====================================================================

USE eventhub_midterm;

-- ---------------------------------------------------------------------
-- 1. Lossless multi-table INNER JOIN
-- Rebuilds the flat booking view from four normalized tables.
-- Expect 7 rows: one per (booking_id, session_code) in the flat table.
-- ---------------------------------------------------------------------
SELECT b.event_title,
       o.organizer_name,
       v.venue_name,
       s.ticket_category,
       s.tickets_booked,
       (s.tickets_booked * s.ticket_price) AS total_price
FROM booking AS b
JOIN organizer AS o ON o.organizer_id = b.organizer_id
JOIN venue AS v     ON v.venue_code   = b.venue_code
JOIN session AS s   ON s.booking_id   = b.booking_id
ORDER BY b.booking_id, s.session_code;

-- ---------------------------------------------------------------------
-- 2. Unbooked venues: preserve every venue, then keep only NULL matches.
-- Expect V-CAMPUS.
-- ---------------------------------------------------------------------
SELECT v.venue_code,
       v.venue_name,
       v.venue_city,
       v.venue_capacity
FROM venue AS v
LEFT JOIN booking AS b ON b.venue_code = v.venue_code
WHERE b.booking_id IS NULL
ORDER BY v.venue_code;

-- ---------------------------------------------------------------------
-- 3. The "silent inner join" trap
-- ---------------------------------------------------------------------

-- Version A (flawed): the VIP filter in WHERE removes the NULL-extended
-- rows, so unbooked venues disappear even though the join is LEFT.
SELECT v.venue_code,
       v.venue_name,
       b.booking_id,
       s.ticket_category
FROM venue AS v
LEFT JOIN booking AS b ON b.venue_code = v.venue_code
LEFT JOIN session AS s ON s.booking_id = b.booking_id
WHERE s.ticket_category = 'VIP'
ORDER BY v.venue_code, b.booking_id;

-- Version B (correct): the VIP filter lives in the ON clause, so every
-- venue is preserved and non-matching sessions appear as NULL.
SELECT v.venue_code,
       v.venue_name,
       b.booking_id,
       s.ticket_category
FROM venue AS v
LEFT JOIN booking AS b ON b.venue_code = v.venue_code
LEFT JOIN session AS s ON s.booking_id = b.booking_id
                       AND s.ticket_category = 'VIP'
ORDER BY v.venue_code, b.booking_id, s.session_code;

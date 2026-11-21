-- =====================================================================
-- INFOMAN1 Midterm Practical Assessment: Task 4
-- Filtering, Functions & Aggregate Analytics
-- Database: eventhub_midterm
--
-- Prices reflect the Task 3 10% increase: 550, 1320, 1650, 660, 350, 350, 250.
-- =====================================================================

USE eventhub_midterm;

-- ---------------------------------------------------------------------
-- Query 1: Compound logical filtering with explicit precedence
-- Bookings from 2025-04-10 to 2025-04-20 that are either VIP
-- or priced above 500.00. Parentheses force the OR to evaluate first.
-- ---------------------------------------------------------------------
SELECT b.booking_id,
       b.event_title,
       b.booking_date,
       s.session_code,
       s.ticket_category,
       s.ticket_price
FROM booking AS b
JOIN session AS s ON s.booking_id = b.booking_id
WHERE b.booking_date BETWEEN '2025-04-10' AND '2025-04-20'
  AND (s.ticket_category = 'VIP' OR s.ticket_price > 500.00)
ORDER BY b.booking_date, s.session_code;

-- ---------------------------------------------------------------------
-- Query 2: Scalar string and date functions
-- Contact card plus days remaining until 2025-05-01.
-- ---------------------------------------------------------------------
SELECT o.organizer_name,
       CONCAT(o.organizer_name, ' <', o.organizer_email, '>') AS contact_card,
       b.booking_id,
       b.event_title,
       b.booking_date,
       DATEDIFF('2025-05-01', b.booking_date) AS days_elapsed
FROM organizer AS o
JOIN booking AS b ON b.organizer_id = o.organizer_id
ORDER BY b.booking_date;

-- ---------------------------------------------------------------------
-- Query 3: Pattern matching with wildcards
-- Cities ending in "City" or beginning with "M".
-- ---------------------------------------------------------------------
SELECT venue_code,
       venue_name,
       venue_city,
       venue_capacity
FROM venue
WHERE (venue_city LIKE '%City' OR venue_city LIKE 'M%')
ORDER BY venue_city, venue_name;

-- ---------------------------------------------------------------------
-- Query 4: GROUP BY with a HAVING filter on the aggregate
-- Categories with at least 5 tickets sold.
-- ---------------------------------------------------------------------
SELECT ticket_category,
       SUM(tickets_booked)                AS total_tickets,
       SUM(tickets_booked * ticket_price) AS gross_revenue
FROM session
GROUP BY ticket_category
HAVING SUM(tickets_booked) >= 5
ORDER BY gross_revenue DESC;

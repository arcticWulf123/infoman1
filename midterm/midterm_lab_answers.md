# INFOMAN1 — Midterm Practical Assessment: Answer Document

**Name:** Jade Roland Eduard C Pinon
**Student ID:** 2511036  
**Repository URL:** <https://github.com/arcticWulf123/infoman1>  
**Date Submitted:** ________________________________________

---

## Task 1: Normalization Audit & 3NF Decomposition

### Approach

I connected to `eventhub_midterm` and inspected the table with `DESCRIBE` and `SELECT`, then compared repeated groups to see which values are stored redundantly.

```sql
USE eventhub_midterm;
DESCRIBE event_booking_flat;
SELECT * FROM event_booking_flat ORDER BY booking_id, session_code;
```

The grain of the table is **one booking line**: one session of one event booking, for one ticket category, with a comma-separated list of speakers. `booking_id` repeats (101 appears in rows 1–2), so it is not a key by itself. A `session_code` is only unique within its booking, so the table uses the composite key **(booking_id, session_code)**.

Decomposition order: fix the multi-valued `speaker_list` (1NF) → remove attributes that depend on only part of the composite key (2NF) → remove attributes that depend on other non-key attributes (3NF).

### 1. Data Anomalies in `event_booking_flat`

- **Update Anomaly:** The venue *Metro Tech Auditorium* has `venue_capacity = 300` stored three times (rows 1, 2, and 4). If the auditorium is renovated, all three rows must change; if row 4 is missed, the same venue reports two different capacities. The same problem exists for `organizer_email`: *Green Earth Initiative*'s `contact@greenearth.org` is stored in rows 3 and 5, so an email change must be applied twice.

- **Insertion Anomaly:** A new venue such as `V-CAMPUS` cannot be recorded until a booking exists for it, because `booking_id`, `session_code`, `booking_date`, `organizer_id`, `event_title`, and `venue_code` are all `NOT NULL`. Storing the venue alone would require inventing a fake booking, session, organizer, and event. Likewise, a new speaker (e.g. "Dr. Villanueva") cannot be registered in a speaker pool, because speakers exist only inside `speaker_list` on a booking row.

- **Deletion Anomaly:** Deleting booking **103** (row 4) also destroys unrelated facts: *Innovate Campus Lab* (its only booking), the only record of speaker *Ms. Lim*, and the *AI & Cloud Infrastructure* event. Deleting rows 3 and 5 would erase *Bayview Convention Hall* (capacity 150, Manila) even though no venue was intentionally removed.

### 2. Functional Dependencies

```text
booking_id                 -> booking_date, organizer_id, event_title, venue_code
organizer_id               -> organizer_name, organizer_email
venue_code                 -> venue_name, venue_city, venue_capacity
(booking_id, session_code) -> ticket_category, ticket_price, tickets_booked, speaker_list
```

### 3. Normalization Progression

- **First Normal Form (1NF)** — Only `speaker_list` violates 1NF: it holds a comma-separated list instead of atomic values. Splitting it into one speaker per row expands row 1 into two rows:

  ```text
  (101, SESS-A1, ..., 'Dr. Perez')
  (101, SESS-A1, ..., 'Engr. Cruz')
  ```

  Each attribute is now atomic, but the key must grow to **(booking_id, session_code, speaker_name)** to stay unique. Rather than keep speaker names as a key, speakers are modelled as their own entity and connected to sessions through the junction table `SessionSpeaker`, which resolves the many-to-many relationship (`Dr. Perez` teaches sessions in bookings 101 and 103; session `SESS-D2` has two speakers).

- **Second Normal Form (2NF)** — The key is still composite, so I remove attributes that depend on only part of it. `booking_id` alone determines `booking_date`, `event_title`, `organizer_id`, `organizer_name`, `organizer_email`, `venue_code`, `venue_name`, `venue_city`, and `venue_capacity` — all partial dependencies. `session_code` alone determines nothing consistently, so it contributes no partial dependency. What remains fully dependent on the whole key is `ticket_category`, `ticket_price`, `tickets_booked`, and the speaker assignment. This produces `Booking`, `Session`, and `SessionSpeaker`.

- **Third Normal Form (3NF)** — Two transitive chains remain in `Booking`: `booking_id → organizer_id → organizer_name, organizer_email`, and `booking_id → venue_code → venue_name, venue_city, venue_capacity`. Organizer and venue data are moved into `Organizer` and `Venue`, leaving only the foreign keys `organizer_id` and `venue_code` in `Booking`. No non-key column now determines another non-key column.

### 4. Final Relational Schema Notation

```text
Organizer(<u>organizer_id</u>, organizer_name, organizer_email)

Venue(<u>venue_code</u>, venue_name, venue_city, venue_capacity)

Booking(<u>booking_id</u>, booking_date, event_title,
        organizer_id [FK -> Organizer], venue_code [FK -> Venue])

Session(<u>booking_id [FK -> Booking], session_code</u>,
        ticket_category, ticket_price, tickets_booked)

Speaker(<u>speaker_id</u>, speaker_name)

SessionSpeaker(<u>booking_id [FK -> Session], session_code [FK -> Session],
               speaker_id [FK -> Speaker]</u>)
```

Design note: `Session` keeps the natural composite key `(booking_id, session_code)` instead of adding a surrogate `session_id`. This mirrors the original primary key and keeps the 2NF reasoning visible, at the cost of a three-column key and composite foreign keys in `SessionSpeaker`.

### Evidence

| Row(s) | Data | Demonstrates |
| --- | --- | --- |
| 1, 2, 4 | `V-METRO` / `Metro Tech Auditorium` / `Quezon City` / `300` repeated | Update anomaly; `venue_code → venue_*` |
| 3, 5 | `organizer_id = 2`, `contact@greenearth.org` repeated | Update anomaly; `organizer_id → organizer_*` |
| 4 | Last record of organizer 3 and speaker `Ms. Lim` | Deletion anomaly |
| 3, 5 | Only rows for `V-BAY` | Deleting them loses the venue |
| — | New venue/speaker has no place to go (`NOT NULL` booking columns) | Insertion anomaly |
| 1, 4 | `Dr. Perez` in two different bookings | M:N between sessions and speakers |
| 1 vs 2 | Same booking, different ticket category and price | Ticket data depends on `(booking_id, session_code)` |

### Reflection

Why does the many-to-many relationship between sessions and speakers require a junction table instead of another column?

A session can have several speakers (*Health Informatics 2025* has `Dr. Aquino`; *Telemedicine Implementation* has `Dr. Aquino, Engr. Tan`) and one speaker can appear in several sessions (`Dr. Perez` is in bookings 101 and 103). That is many-to-many, which a single column cannot represent: one `speaker_id` column would allow only one speaker per session, and adding `speaker2`, `speaker3`, … would create a repeating group (a 1NF violation), impose an arbitrary limit, and leave NULLs for sessions with fewer speakers. `SessionSpeaker` stores one row per session–speaker pair, so any number of speakers fits, each pairing is recorded once, and speaker details live in exactly one place in `Speaker`.

---

## Task 2: DDL Implementation with Constraints

### Approach

The DDL follows the six-table 3NF schema from Task 1 and creates tables parent-first, so every foreign key already has a target when it is declared. `event_booking_flat` is deliberately **not** dropped, because Task 3 migrates its rows into these tables.

Data type choices:

- `INT` for `organizer_id`, `booking_id`, `speaker_id`, `venue_capacity`, `tickets_booked` — all whole numbers.
- `VARCHAR` with a width matched to the seed data: `venue_code`/`session_code` `VARCHAR(20)` (codes like `V-METRO`, `SESS-A1`), names `VARCHAR(100)`, `event_title` `VARCHAR(150)`, `ticket_category` `VARCHAR(50)`.
- `DATE` for `booking_date` (no time component needed) and `TIMESTAMP` for `booked_at` (a moment in time, and the only column that can take `CURRENT_TIMESTAMP` as a default).
- `DECIMAL(8,2)` for `ticket_price` — exact money arithmetic, two decimal places, no floating-point rounding.

One extension to the Task 1 schema: `Session.booked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP`. Task 1 had no timestamp or status column, and Task 2 requires a `DEFAULT` value, so the booking timestamp is attached to the session that owns `tickets_booked`.

Constraint choices:

- **PRIMARY KEY:** natural keys from the seed data (`organizer_id`, `venue_code`, `booking_id`), the composite `(booking_id, session_code)` on `Session`, and the surrogate `speaker_id` (the seed only provides speaker names).
- **FOREIGN KEY:** `Booking` → `Organizer`, `Venue` with `ON DELETE RESTRICT` (a venue or organizer with bookings must not vanish); `Session` → `Booking` and `SessionSpeaker` → `Session`, `Speaker` with `ON DELETE CASCADE` (those child rows cannot exist without their parent).
- **NOT NULL:** on all names, dates, codes, amounts, and `tickets_booked`.
- **UNIQUE:** `organizer_email` (no two organizers share an email) and `speaker_name` (so Task 3 can look a speaker up by name without creating duplicates).
- **DEFAULT:** `booked_at DEFAULT CURRENT_TIMESTAMP` and `tickets_booked DEFAULT 0`.
- **CHECK:** `venue_capacity > 0`, `ticket_price >= 0.00`, and `tickets_booked >= 0`. These are enforced from MySQL 8.0.16 onward (this server is 9.7), and Task 3 demonstrates the rejection with an invalid insert.

### Code / Query Used

Full script saved as `task2_schema_ddl.sql`:

```sql
CREATE DATABASE IF NOT EXISTS eventhub_midterm;
USE eventhub_midterm;

-- Drop child tables first so foreign keys do not block the drop
DROP TABLE IF EXISTS SessionSpeaker;
DROP TABLE IF EXISTS Speaker;
DROP TABLE IF EXISTS `Session`;
DROP TABLE IF EXISTS Booking;
DROP TABLE IF EXISTS Venue;
DROP TABLE IF EXISTS Organizer;

CREATE TABLE Organizer (
    organizer_id    INT          PRIMARY KEY,
    organizer_name  VARCHAR(100) NOT NULL,
    organizer_email VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE Venue (
    venue_code     VARCHAR(20)  PRIMARY KEY,
    venue_name     VARCHAR(100) NOT NULL,
    venue_city     VARCHAR(50)  NOT NULL,
    venue_capacity INT          NOT NULL,
    CONSTRAINT chk_venue_capacity CHECK (venue_capacity > 0)
);

CREATE TABLE Booking (
    booking_id   INT          PRIMARY KEY,
    booking_date DATE         NOT NULL,
    event_title  VARCHAR(150) NOT NULL,
    organizer_id INT          NOT NULL,
    venue_code   VARCHAR(20)  NOT NULL,
    CONSTRAINT fk_booking_organizer FOREIGN KEY (organizer_id)
        REFERENCES Organizer(organizer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_booking_venue FOREIGN KEY (venue_code)
        REFERENCES Venue(venue_code) ON DELETE RESTRICT
);

CREATE TABLE `Session` (
    booking_id      INT          NOT NULL,
    session_code    VARCHAR(20)  NOT NULL,
    ticket_category VARCHAR(50)  NOT NULL,
    ticket_price    DECIMAL(8,2) NOT NULL,
    tickets_booked  INT          NOT NULL DEFAULT 0,
    booked_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (booking_id, session_code),
    CONSTRAINT chk_ticket_price   CHECK (ticket_price >= 0.00),
    CONSTRAINT chk_tickets_booked CHECK (tickets_booked >= 0),
    CONSTRAINT fk_session_booking FOREIGN KEY (booking_id)
        REFERENCES Booking(booking_id) ON DELETE CASCADE
);

CREATE TABLE Speaker (
    speaker_id   INT          AUTO_INCREMENT PRIMARY KEY,
    speaker_name VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE SessionSpeaker (
    booking_id   INT         NOT NULL,
    session_code VARCHAR(20) NOT NULL,
    speaker_id   INT         NOT NULL,
    PRIMARY KEY (booking_id, session_code, speaker_id),
    CONSTRAINT fk_ss_session FOREIGN KEY (booking_id, session_code)
        REFERENCES `Session`(booking_id, session_code) ON DELETE CASCADE,
    CONSTRAINT fk_ss_speaker FOREIGN KEY (speaker_id)
        REFERENCES Speaker(speaker_id) ON DELETE CASCADE
);
```

### Evidence: Table Verification (SHOW TABLES / DESCRIBE)

`DESCRIBE` reports columns, keys, and defaults but does **not** show `CHECK` or foreign-key names, so `SHOW CREATE TABLE` is included for those.

```sql
USE eventhub_midterm;
SHOW TABLES;
DESCRIBE Organizer;
DESCRIBE Venue;
DESCRIBE Booking;
DESCRIBE `Session`;
DESCRIBE Speaker;
DESCRIBE SessionSpeaker;
SHOW CREATE TABLE Venue;
SHOW CREATE TABLE `Session`;
SHOW CREATE TABLE SessionSpeaker;
```

Output (the `SHOW CREATE TABLE` results were captured with `-E` / vertical formatting so the long definitions stay readable):

```text
SHOW TABLES
+----------------------------+
| Tables_in_eventhub_midterm |
+----------------------------+
| booking                    |
| event_booking_flat         |
| organizer                  |
| session                    |
| sessionspeaker             |
| speaker                    |
| venue                      |
+----------------------------+

DESCRIBE Organizer
+-----------------+--------------+------+-----+---------+-------+
| Field           | Type         | Null | Key | Default | Extra |
+-----------------+--------------+------+-----+---------+-------+
| organizer_id    | int          | NO   | PRI | NULL    |       |
| organizer_name  | varchar(100) | NO   |     | NULL    |       |
| organizer_email | varchar(100) | NO   | UNI | NULL    |       |
+-----------------+--------------+------+-----+---------+-------+

DESCRIBE Venue
+----------------+--------------+------+-----+---------+-------+
| Field          | Type         | Null | Key | Default | Extra |
+----------------+--------------+------+-----+---------+-------+
| venue_code     | varchar(20)  | NO   | PRI | NULL    |       |
| venue_name     | varchar(100) | NO   |     | NULL    |       |
| venue_city     | varchar(50)  | NO   |     | NULL    |       |
| venue_capacity | int          | NO   |     | NULL    |       |
+----------------+--------------+------+-----+---------+-------+

DESCRIBE Booking
+--------------+--------------+------+-----+---------+-------+
| Field        | Type         | Null | Key | Default | Extra |
+--------------+--------------+------+-----+---------+-------+
| booking_id   | int          | NO   | PRI | NULL    |       |
| booking_date | date         | NO   |     | NULL    |       |
| event_title  | varchar(150) | NO   |     | NULL    |       |
| organizer_id | int          | NO   | MUL | NULL    |       |
| venue_code   | varchar(20)  | NO   | MUL | NULL    |       |
+--------------+--------------+------+-----+---------+-------+

DESCRIBE Session
+-----------------+--------------+------+-----+-------------------+-------------------+
| Field           | Type         | Null | Key | Default           | Extra             |
+-----------------+--------------+------+-----+-------------------+-------------------+
| booking_id      | int          | NO   | PRI | NULL              |                   |
| session_code    | varchar(20)  | NO   | PRI | NULL              |                   |
| ticket_category | varchar(50)  | NO   |     | NULL              |                   |
| ticket_price    | decimal(8,2) | NO   |     | NULL              |                   |
| tickets_booked  | int          | NO   |     | 0                 |                   |
| booked_at       | timestamp    | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED |
+-----------------+--------------+------+-----+-------------------+-------------------+

DESCRIBE Speaker
+--------------+--------------+------+-----+---------+----------------+
| Field        | Type         | Null | Key | Default | Extra          |
+--------------+--------------+------+-----+---------+----------------+
| speaker_id   | int          | NO   | PRI | NULL    | auto_increment |
| speaker_name | varchar(100) | NO   | UNI | NULL    |                |
+--------------+--------------+------+-----+---------+----------------+

DESCRIBE SessionSpeaker
+--------------+-------------+------+-----+---------+-------+
| Field        | Type        | Null | Key | Default | Extra |
+--------------+-------------+------+-----+---------+-------+
| booking_id   | int         | NO   | PRI | NULL    |       |
| session_code | varchar(20) | NO   | PRI | NULL    |       |
| speaker_id   | int         | NO   | PRI | NULL    |       |
+--------------+-------------+------+-----+---------+-------+

SHOW CREATE TABLE Venue
*************************** 1. row ***************************
       Table: Venue
Create Table: CREATE TABLE `venue` (
  `venue_code` varchar(20) NOT NULL,
  `venue_name` varchar(100) NOT NULL,
  `venue_city` varchar(50) NOT NULL,
  `venue_capacity` int NOT NULL,
  PRIMARY KEY (`venue_code`),
  CONSTRAINT `chk_venue_capacity` CHECK ((`venue_capacity` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci

SHOW CREATE TABLE Session
*************************** 1. row ***************************
       Table: Session
Create Table: CREATE TABLE `session` (
  `booking_id` int NOT NULL,
  `session_code` varchar(20) NOT NULL,
  `ticket_category` varchar(50) NOT NULL,
  `ticket_price` decimal(8,2) NOT NULL,
  `tickets_booked` int NOT NULL DEFAULT '0',
  `booked_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`booking_id`,`session_code`),
  CONSTRAINT `fk_session_booking` FOREIGN KEY (`booking_id`) REFERENCES `booking` (`booking_id`) ON DELETE CASCADE,
  CONSTRAINT `chk_ticket_price` CHECK ((`ticket_price` >= 0.00)),
  CONSTRAINT `chk_tickets_booked` CHECK ((`tickets_booked` >= 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci

SHOW CREATE TABLE SessionSpeaker
*************************** 1. row ***************************
       Table: SessionSpeaker
Create Table: CREATE TABLE `sessionspeaker` (
  `booking_id` int NOT NULL,
  `session_code` varchar(20) NOT NULL,
  `speaker_id` int NOT NULL,
  PRIMARY KEY (`booking_id`,`session_code`,`speaker_id`),
  KEY `fk_ss_speaker` (`speaker_id`),
  CONSTRAINT `fk_ss_session` FOREIGN KEY (`booking_id`, `session_code`) REFERENCES `session` (`booking_id`, `session_code`) ON DELETE CASCADE,
  CONSTRAINT `fk_ss_speaker` FOREIGN KEY (`speaker_id`) REFERENCES `speaker` (`speaker_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
```

The six normalized tables were created successfully and `event_booking_flat` is still present for Task 3. `DESCRIBE` confirms the columns, primary keys, `UNI` constraints, and both defaults; `SHOW CREATE TABLE` confirms the foreign keys and the three `CHECK` constraints, which `DESCRIBE` does not display.

### Reflection

Which table in your schema needed a composite primary key, and why?

`SessionSpeaker` needs the composite primary key `(booking_id, session_code, speaker_id)`. It is the junction table for a many-to-many relationship: one speaker teaches several sessions and one session has several speakers. No single column is unique — the same `speaker_id` repeats across sessions and the same session repeats across speakers — so only the full triple identifies one row, and the primary key is what prevents the same speaker from being attached to the same session twice. `Session` also carries a composite key, `(booking_id, session_code)`, because a session code is only unique within its booking.

---

## Task 3: Data Migration & Safe DML Operations

### Approach

The migration is set-based rather than hand-typed: `INSERT INTO ... SELECT DISTINCT` from `event_booking_flat` collapses each repeated group into one entity row, so the 7 flat rows become 4 organizers, 3 venues, 6 bookings, and 7 sessions. `DISTINCT` is what removes the redundant copies that caused the update anomaly in Task 1.

`speaker_list` cannot be inserted directly because it is a comma-separated string. A temporary `digits` table (values 1–5) generates one row per position in the list. The expression

```sql
SUBSTRING_INDEX(SUBSTRING_INDEX(speaker_list, ',', d.n), ',', -1)
```

extracts the *n*-th name, and `TRIM()` removes the space after each comma (`' Engr. Cruz'` → `'Engr. Cruz'`). The number of names is found by counting commas: `LENGTH(list) - LENGTH(REPLACE(list, ',', '')) + 1`. That produces one atomic speaker per row; `INSERT IGNORE` skips repeats such as `Dr. Perez`, which appears in two bookings and is blocked by `UNIQUE(speaker_name)`. The junction table is populated by joining the split names back to `Speaker` to recover the surrogate `speaker_id`.

A reconciliation query runs **before** any price change to prove nothing was lost: the normalized `session` table and the flat table must both report 31 tickets and 14,800.00 gross revenue. The new `V-CAMPUS` row is added after reconciliation. `booked_at` takes its `DEFAULT CURRENT_TIMESTAMP` because the flat table contains no booking timestamp.

Both DML operations follow the 4-step Safe Change Loop: preview the exact rows, confirm the count, execute the targeted statement, then verify. The script ends with an intentionally invalid insert to prove the `CHECK` constraint rejects a negative price.

### Code / Query Used

Full script saved as `task3_dml_operations.sql`. Migration and new-venue statements:

```sql
USE eventhub_midterm;

-- Organizers (4 rows)
INSERT INTO organizer (organizer_id, organizer_name, organizer_email)
SELECT DISTINCT organizer_id, organizer_name, organizer_email
FROM event_booking_flat;

-- Venues (3 rows)
INSERT INTO venue (venue_code, venue_name, venue_city, venue_capacity)
SELECT DISTINCT venue_code, venue_name, venue_city, venue_capacity
FROM event_booking_flat;

-- Bookings (6 rows)
INSERT INTO booking (booking_id, booking_date, event_title, organizer_id, venue_code)
SELECT DISTINCT booking_id, booking_date, event_title, organizer_id, venue_code
FROM event_booking_flat;

-- Sessions (7 rows)
INSERT INTO session (booking_id, session_code, ticket_category, ticket_price, tickets_booked)
SELECT DISTINCT booking_id, session_code, ticket_category, ticket_price, tickets_booked
FROM event_booking_flat;

-- Helper table for splitting the comma list
DROP TEMPORARY TABLE IF EXISTS digits;
CREATE TEMPORARY TABLE digits (n INT PRIMARY KEY);
INSERT INTO digits VALUES (1), (2), (3), (4), (5);

-- Speakers (7 rows), one atomic name per row
INSERT IGNORE INTO speaker (speaker_name)
SELECT DISTINCT TRIM(
           SUBSTRING_INDEX(SUBSTRING_INDEX(f.speaker_list, ',', d.n), ',', -1)
       ) AS speaker_name
FROM event_booking_flat AS f
JOIN digits AS d
  ON d.n <= 1 + (LENGTH(f.speaker_list) - LENGTH(REPLACE(f.speaker_list, ',', '')))
WHERE f.speaker_list IS NOT NULL
  AND f.speaker_list <> '';

-- SessionSpeaker junction (11 rows)
INSERT IGNORE INTO sessionspeaker (booking_id, session_code, speaker_id)
SELECT DISTINCT f.booking_id, f.session_code, sp.speaker_id
FROM event_booking_flat AS f
JOIN digits AS d
  ON d.n <= 1 + (LENGTH(f.speaker_list) - LENGTH(REPLACE(f.speaker_list, ',', '')))
JOIN speaker AS sp
  ON sp.speaker_name = TRIM(
         SUBSTRING_INDEX(SUBSTRING_INDEX(f.speaker_list, ',', d.n), ',', -1)
     )
WHERE f.speaker_list IS NOT NULL
  AND f.speaker_list <> '';

-- Reconciliation (before the price update)
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

-- New venue
INSERT INTO venue (venue_code, venue_name, venue_city, venue_capacity)
VALUES ('V-CAMPUS', 'University Amphitheater', 'Quezon City', 500);
```

Reconciliation output, captured before the price update:

```text
table_name      rows_inserted
organizer       4
venue           3
booking         6
session         7
speaker         7
sessionspeaker  11

normalized_tickets  flat_tickets  normalized_revenue  flat_revenue
31                  31            14800.00            14800.00
```

Both sides agree on 31 tickets and 14,800.00, so the migration is lossless.

### Safe Change Loop: 10% Ticket Price Increase

- **Step 1 (Preview Rows):**

  ```sql
  SELECT booking_id, session_code, ticket_category, ticket_price,
         ROUND(ticket_price * 1.10, 2) AS new_price
  FROM session
  WHERE ticket_price > 400.00
  ORDER BY booking_id, session_code;
  ```

  Preview: 4 rows — 500.00 → 550.00, 1200.00 → 1320.00, 1500.00 → 1650.00, 600.00 → 660.00. The 350.00 and 250.00 tickets are untouched because the condition is strictly `> 400.00`.

- **Step 2 (Confirm Target Count):**

  ```sql
  SELECT COUNT(*) AS target_rows
  FROM session
  WHERE ticket_price > 400.00;
  ```

  Target count: **4**.

- **Step 3 (Execute UPDATE):**

  ```sql
  UPDATE session
  SET ticket_price = ROUND(ticket_price * 1.10, 2)
  WHERE ticket_price > 400.00;
  ```

- **Step 4 (Verify Changes):**

  ```sql
  SELECT booking_id, session_code, ticket_category, ticket_price
  FROM session
  ORDER BY ticket_price DESC;
  ```

  Verification: the four raised prices now read 660.00, 1320.00, 550.00, and 1650.00; revenue moves from 14,800.00 to 15,750.00. The script is applied only once — a second run would compound the increase because the new prices are still above 400.00.

### Safe Change Loop: DELETE of `V-TEMP`

The temporary venue is inserted first, then removed by its primary key:

```sql
INSERT INTO venue (venue_code, venue_name, venue_city, venue_capacity)
VALUES ('V-TEMP', 'Temporary Venue', 'Manila', 50);
```

- **Step 1 (Preview Rows):**

  ```sql
  SELECT * FROM venue WHERE venue_code = 'V-TEMP';
  ```

  One row: `V-TEMP | Temporary Venue | Manila | 50`.

- **Step 2 (Confirm Target Count):**

  ```sql
  SELECT COUNT(*) AS target_rows FROM venue WHERE venue_code = 'V-TEMP';
  ```

  Target count: **1**.

- **Step 3 (Execute DELETE):**

  ```sql
  DELETE FROM venue WHERE venue_code = 'V-TEMP';
  ```

- **Step 4 (Verify Changes):**

  ```sql
  SELECT COUNT(*) AS remaining FROM venue WHERE venue_code = 'V-TEMP';
  ```

  Verification: **0** rows remain. `V-CAMPUS` is still present, so Task 5 can still use it as the unbooked venue.

### Evidence: Constraint Protection Verification

- **Invalid SQL Statement:**

  ```sql
  INSERT INTO session (booking_id, session_code, ticket_category, ticket_price, tickets_booked)
  VALUES (101, 'SESS-CHK', 'Standard', -100.00, 0);
  ```

  `booking_id = 101` is an existing booking, so the foreign key passes and only the `CHECK` can reject the row.

- **MySQL Error Message Received:**

  ```
  ERROR 3819 (HY000) at line 142: Check constraint 'chk_ticket_price' is violated.
  ```

### Reflection

Why is the `DELETE` targeted by primary key rather than by venue name?

`venue_code` is the primary key, so it identifies exactly one row and cannot change accidentally. A venue name is descriptive text: it is not unique, it can be duplicated or misspelled, and it might be renamed later. `DELETE FROM venue WHERE venue_name = 'Temporary Venue'` could delete several rows or none at all, and the only warning would be the affected-row count. Filtering by the primary key also makes the preview and the count meaningful — if Step 1 shows one row and Step 2 returns 1, the DELETE is guaranteed to remove exactly what was inspected.

---

## Task 4: Filtering, Functions & Aggregate Analytics

### Approach
<!-- Explain how you chose filters, wildcards, and grouping columns -->

### Query 1: Compound Logical Filtering with Precedence

**SQL Query:**

```sql
```

**Output:**

```
```

### Query 2: Scalar String & Date Functions

**SQL Query:**

```sql
```

**Output:**

```
```

### Query 3: Pattern Matching with LIKE Wildcards

**SQL Query:**

```sql
```

**Output:**

```
```

### Query 4: GROUP BY and HAVING Summary

**SQL Query:**

```sql
```

**Output:**

```
```

### Reflection

Why does Query 4 filter with `HAVING` instead of `WHERE`?

---

## Task 5: Multi-Table Joins & Outer Join Diagnostics

### Approach
<!-- Explain which tables you joined, in what order, and which keys you joined on -->

### 1. Multi-Table INNER JOIN

**SQL Query:**

```sql
```

**Output:**

```
```

### 2. Finding Unbooked Venues (LEFT JOIN ... IS NULL)

**SQL Query:**

```sql
```

**Output:**

```
```

### 3. The "Silent Inner Join" Trap Comparison

- **Version A (Flawed WHERE filter):**

  ```sql
  ```

  *Result / Behavior:*
  
- **Version B (Correct ON condition):**

  ```sql
  ```

  *Result / Behavior:*
  
- **Technical Explanation:**
  <!-- Why does moving the filter from ON to WHERE strip preserved NULL rows in an outer join? -->
  
### Reflection

Why is `= NULL` the wrong way to find unbooked venues, and what is the correct test?

---

## Task 6: Schema Evolution & Cross-Week Synthesis

### Approach
<!-- Explain how you added venue_status and why you chose the CHECK values -->

### 1. ALTER TABLE Statement & Status Constraint

```sql
```

### 2. Targeted Primary-Key UPDATE

```sql
```

### 3. Constraint Test (invalid status)

- **Invalid SQL Statement:**

  ```sql
  ```

- **MySQL Error Message Received:**

  ```
  ```

### 4. Integrated Synthesis Report Query

**SQL Query:**

```sql
```

**Output:**

```
```

### Reflection

Why does adding `NOT NULL DEFAULT 'ACTIVE'` succeed on a table that already holds rows?

---

## Task 7: Self-Review & Reflection

### Self-Audit Checklist

- [ ] All three anomalies (update, insert, delete) clearly explained with examples
- [ ] Schema systematically normalized from flat table $\rightarrow$ 1NF $\rightarrow$ 2NF $\rightarrow$ 3NF
- [ ] Speakers modeled with a junction table
- [ ] All primary keys underlined and foreign keys marked in schema notation
- [ ] DDL created with `NOT NULL`, `UNIQUE`, `DEFAULT`, and `CHECK` constraints
- [ ] 4-step Safe Change Loop followed for the `UPDATE` and the `DELETE`
- [ ] Invalid insert correctly triggered and documented MySQL constraint error
- [ ] Query 1 properly uses parentheses for `AND` / `OR` operator precedence
- [ ] Query 4 properly uses `HAVING` instead of `WHERE` for aggregate filter
- [ ] Outer join missing-record query uses `IS NULL` check
- [ ] Silent inner join trap clearly explained with both query variations
- [ ] `ALTER TABLE` successfully executed and invalid status rejected
- [ ] Integrated synthesis report combines joins, aggregation, grouping, and ordering

### Concluding Reflection

1. What was the most significant challenge when decomposing the unnormalized flat table into 3NF, and how did separating entities improve data integrity?

2. What are the practical performance tradeoffs between keeping a single flat table versus querying multiple normalized tables using `JOIN`s in a high-traffic production environment?

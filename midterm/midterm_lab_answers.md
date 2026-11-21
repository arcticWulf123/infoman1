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
<!-- Explain how you moved data from event_booking_flat into your 3NF tables without data loss, including how speaker names were split -->

### Code / Query Used
<!-- Paste or summarize your migration INSERT statements and the V-CAMPUS insert (full script is in task3_dml_operations.sql) -->

```sql
```

### Safe Change Loop: 10% Ticket Price Increase
<!-- Document each of the 4 steps of the Safe Change Loop -->

- **Step 1 (Preview Rows):**

  ```sql
  ```

- **Step 2 (Confirm Target Count):**
  
- **Step 3 (Execute UPDATE):**

  ```sql
  ```

- **Step 4 (Verify Changes):**

  ```sql
  ```

### Safe Change Loop: DELETE of `V-TEMP`

- **Step 1 (Preview Rows):**

  ```sql
  ```

- **Step 2 (Confirm Target Count):**
  
- **Step 3 (Execute DELETE):**

  ```sql
  ```

- **Step 4 (Verify Changes):**

  ```sql
  ```

### Evidence: Constraint Protection Verification
<!-- Show the query attempting to insert invalid data (negative ticket price) and the MySQL error response -->

- **Invalid SQL Statement:**

  ```sql
  ```

- **MySQL Error Message Received:**

  ```
  ```

### Reflection

Why is the `DELETE` targeted by primary key rather than by venue name?

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

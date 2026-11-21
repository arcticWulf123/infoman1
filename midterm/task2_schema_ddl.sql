-- =====================================================================
-- INFOMAN1 Midterm Practical Assessment: Task 2
-- DDL Implementation with Constraints
-- Database: eventhub_midterm
-- Schema: 3NF decomposition from Task 1
--
-- NOTE: event_booking_flat is intentionally NOT dropped here.
--       Task 3 migrates its data into these normalized tables.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS eventhub_midterm;
USE eventhub_midterm;

-- Drop child tables first so foreign keys do not block the drop
DROP TABLE IF EXISTS SessionSpeaker;
DROP TABLE IF EXISTS Speaker;
DROP TABLE IF EXISTS `Session`;
DROP TABLE IF EXISTS Booking;
DROP TABLE IF EXISTS Venue;
DROP TABLE IF EXISTS Organizer;

-- ---------------------------------------------------------------------
-- Parent tables
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Booking depends on Organizer and Venue
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Session: composite key inherited from the flat table
-- booked_at is the DEFAULT-guarded booking timestamp
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- Speaker: surrogate key, name is the natural key
-- ---------------------------------------------------------------------
CREATE TABLE Speaker (
    speaker_id   INT          AUTO_INCREMENT PRIMARY KEY,
    speaker_name VARCHAR(100) NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- Junction table for the many-to-many sessions <-> speakers relationship
-- ---------------------------------------------------------------------
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

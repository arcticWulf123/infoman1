CREATE DATABASE infoman1_vetclinic;

CREATE TABLE
    Owner (
        owner_id INT PRIMARY KEY,
        full_name CHAR(50) NOT NULL,
        phone_number VARCHAR(10) NOT NULL
    );

CREATE TABLE
    Pet (
        pet_id INT PRIMARY KEY,
        name CHAR(50),
        species CHAR(50),
        age INT
    );

CREATE TABLE
    Veterinarian (
        veterinarian_id INT PRIMARY KEY,
        full_name CHAR(50) NOT NULL,
        specialization CHAR(50) NOT NULL
    );

CREATE TABLE
    Appointment (
        appointment_id INT PRIMARY KEY,
        appointment_date DATE,
        reason_for_visit TEXT NOT NULL
    );

CREATE TABLE
    Vaccination_Record (
        FOREIGN KEY (pet_id) REFERENCES Pet (pet_id) vaccine_name CHAR(50) NOT NULL,
        vaccination_date DATE NOT NULL
    );
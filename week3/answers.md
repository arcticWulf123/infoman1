# INFOMAN1 — Week 3 Lab Answers

## Task 1 — Classify Attributes and Identify Weak Entities
Pet owner Full Name - Composite
Pet owner Phone Number - Multivalued
Pet age - Derived
Pet species - Multivalued


Vaccination record should be a weak entity. It depends on a Pet to exist, the record has no meaning without the pet that recieved it. It cannot be uniquely identified because vaccine_name and vaccination_date can be shared by many pets. It also uses a partial key, its own attributes and the pet ID.



## Task 2 — Specify Participation Constraints
Owner - Pet: Owner || ----------- 0< Pet
Pet - Appointment: Pet || ---------- 0< Appointment
Veterinarian - Appointment: Veterinarian || ------------ 0< Appointment
Pet - Vaccination: Pet || ----------0< Vaccination


## Task 3 — Build the Logical ERD
_ERD here_

## Task 4 — Translate to Relational Schema Notation
_Answer here_


## Task 5 — Key Justification & Schema Validation
_Answer here_

## Self-Check

- [ ] All tasks committed with individual, meaningful commit messages
- [ ] All files placed inside `week3/`
- [ ] This file completed `answers.md`
- [ ] Repository link pasted into Moodle (no files uploaded)

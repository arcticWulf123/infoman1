A veterinary clinic requires a database system to track pet owners, pets, veterinarians, appointments, and vaccinations. 

A pet owner, identified by an owner ID, full name (consisting of first name and last name), and phone number, is not required to have any pets on file at a given time, but every pet must belong to exactly one owner. 

A pet has a pet ID, name, species, and age. Every appointment record tracks an appointment ID, appointment date, and reason for visit, and it must specify exactly one veterinarian and exactly one pet—an appointment cannot exist without.

 A veterinarian, identified by a vet ID, full name, and specialization, can conduct multiple appointments over time or none at all. 

In addition, the clinic tracks each pet's vaccination history, consisting of a vaccine name and vaccination date; a pet may have zero, one, or several vaccination records, and each vaccination record only makes sense in relation to the specific pet it belongs to, meaning it cannot be uniquely identified or looked up on it 


Task 1 — Classify Attributes and Identify Weak Entities

Using the scenario, identify which attributes are composite, multivalued, or derived. Determine whether "vaccination record" should be modeled as a weak entity, and justify your answer using standard ERD principles.

Task 2 — Specify Cardinality & Participation

For each relationship in the scenario (Owner–Pet, Pet–Appointment, Veterinarian–Appointment, Pet–Vaccination Record), determine the Crow's Foot symbols on both sides: the outer symbol for cardinality (one or many) and the inner symbol for participation (optional or mandatory), based on the business rules stated in the scenario.

Task 3 — Build the Logical ERD

Produce a logical ERD in draw.io that resolves: the weak entity (partial key + parent entity key), any many-to-many relationships (via a junction entity), and any composite/multivalued attributes identified in Task 1. Draw every relationship using Crow's Foot notation, displaying both cardinality (outer) and participation (inner) symbols at each end to match your Task 2 answers. Export the diagram as a .png file.

Task 4 — Translate to Relational Schema Notation

Write out the complete relational schema for every table implied by your logical ERD. Format your tables using the structure below, ensuring all attribute names use snake_case with primary keys underlined and foreign keys clearly labeled:

Example Schema Format:

TableName(``primary_key_id``, attribute_one, attribute_two, ..., foreign_key_id*) *Note: foreign_key_id references parent_table_name(primary_key_id)*

Task 5 — Key Justification & Schema Validation

For at least two tables in your schema, explain whether you chose a natural key or a surrogate key as the primary key and justify your choices. Next, review the full scenario line by line to confirm in writing that every stated requirement is represented in your final schema.
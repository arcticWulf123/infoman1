USE infoman1_normalization;

SELECT * FROM student_enrollment WHERE dept_id = 'D01';
SELECT * FROM student_enrollment WHERE course_id = 'IT103';
SELECT * FROM student_enrollment WHERE course_id = 'IT102';


alter table student_enrollment drop column enrolled_courses;
ALTER TABLE student_enrollment ADD PRIMARY KEY (student_id, course_id);
SELECT * FROM student_enrollment ORDER BY student_id, course_id;


CREATE TABLE student (
  student_id   INT PRIMARY KEY,
  student_name VARCHAR(100) NOT NULL
);
CREATE TABLE course (
  course_id       VARCHAR(10) PRIMARY KEY,
  course_title    VARCHAR(100) NOT NULL,
  dept_id         VARCHAR(10) NOT NULL,
  department_name VARCHAR(100) NOT NULL
);
CREATE TABLE enrollment (
  student_id INT NOT NULL,
  course_id  VARCHAR(10) NOT NULL,
  grade      DECIMAL(4,2),
  PRIMARY KEY (student_id, course_id),
  FOREIGN KEY (student_id) REFERENCES student(student_id),
  FOREIGN KEY (course_id) REFERENCES course(course_id)
);


INSERT INTO student (student_id, student_name)
SELECT DISTINCT student_id, student_name
FROM student_enrollment;

INSERT INTO course (course_id, course_title, dept_id, department_name)
SELECT DISTINCT course_id, course_title, dept_id, department_name
FROM student_enrollment;

INSERT INTO enrollment (student_id, course_id, grade)
SELECT student_id, course_id, grade
FROM student_enrollment;

SELECT
  s.student_id,
  s.student_name,
  c.course_id,
  c.course_title,
  c.dept_id,
  c.department_name,
  e.grade
FROM enrollment AS e
INNER JOIN student AS s ON s.student_id = e.student_id
INNER JOIN course AS c ON c.course_id = e.course_id
ORDER BY s.student_id, c.course_id;


CREATE TABLE departments (dept_id VARCHAR(10) PRIMARY KEY,department_name VARCHAR(100) NOT NULL);
INSERT INTO departments (dept_id, department_name) SELECT DISTINCT dept_id, department_name FROM course;
ALTER TABLE course ADD CONSTRAINT fk_course_department FOREIGN KEY (dept_id) REFERENCES departments(dept_id);
ALTER TABLE course DROP COLUMN department_name;

SELECT
  s.student_name,
  c.course_title,
  d.department_name,
  e.grade
FROM enrollment AS e
INNER JOIN student AS s
  ON s.student_id = e.student_id
INNER JOIN course AS c
  ON c.course_id = e.course_id
INNER JOIN departments AS d
  ON d.dept_id = c.dept_id
ORDER BY s.student_id, c.course_id;

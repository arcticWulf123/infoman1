SELECT student_name, program, order_id, order_date
FROM students
INNER JOIN orders ON students.student_id = orders.student_id
ORDER BY orders.order_id;


SELECT student_name, program, order_id, order_date
FROM students
LEFT JOIN orders ON students.student_id = orders.student_id
WHERE orders.order_id IS NULL;

SELECT student_name, program, order_id, order_date
FROM students
INNER JOIN orders ON students.student_id = orders.student_id
ORDER BY orders.order_id;


SELECT students.student_name,
       students.program,
       orders.order_id,
       menu_items.item_name,
       order_items.quantity,
       menu_items.price,
       (order_items.quantity * menu_items.price) AS line_total
FROM students
INNER JOIN orders ON students.student_id = orders.student_id
INNER JOIN order_items ON orders.order_id = order_items.order_id
INNER JOIN menu_items ON order_items.menu_id = menu_items.menu_id;


SELECT students.student_name,
       menu_items.item_name,
       (order_items.quantity * menu_items.price) AS line_total
FROM students
INNER JOIN orders ON students.student_id = orders.student_id
INNER JOIN order_items ON orders.order_id = order_items.order_id
INNER JOIN menu_items ON order_items.menu_id = menu_items.menu_id
WHERE orders.order_date >= '2026-08-01'
ORDER BY orders.order_date DESC;

SELECT students.student_name,
       menu_items.item_name,
       (order_items.quantity * menu_items.price) AS line_total
FROM students
LEFT JOIN orders ON students.student_id = orders.student_id
LEFT JOIN order_items ON orders.order_id = order_items.order_id
LEFT JOIN menu_items ON order_items.menu_id = menu_items.menu_id
WHERE orders.order_date >= '2026-08-01'
ORDER BY orders.order_date DESC;

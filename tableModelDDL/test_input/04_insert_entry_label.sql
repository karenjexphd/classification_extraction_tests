\echo Insert into entry_label for table 0

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id) 
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id 
and cv.cell_address='L3T3R3B3'and cv.table_id=0 and label_value in ('i','a','c','g');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id) 
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id 
and cv.cell_address='L4T3R4B3'and cv.table_id=0 and label_value in ('i','a','d','g');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id) 
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id 
and cv.cell_address='L5T3R5B3'and cv.table_id=0 and label_value in ('i','b','e','g');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id) 
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id 
and cv.cell_address='L6T3R6B3'and cv.table_id=0 and label_value in ('i','b','f','g');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id)
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id
and cv.cell_address='L3T4R3B4'and cv.table_id=0 and label_value in ('j','a','c','g');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id)
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id
and cv.cell_address='L4T4R4B4'and cv.table_id=0 and label_value in ('j', 'a', 'd', 'g');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id)
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id
and cv.cell_address='L5T4R5B4'and cv.table_id=0 and label_value in ('j', 'b', 'e', 'g');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id)
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id
and cv.cell_address='L6T4R6B4'and cv.table_id=0 and label_value in ('j', 'b', 'f', 'g');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id)
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id
and cv.cell_address='L3T5R3B5'and cv.table_id=0 and label_value in ('k', 'a', 'c', 'h');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id)
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id
and cv.cell_address='L4T5R4B5'and cv.table_id=0 and label_value in ('k', 'a', 'd', 'h');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id)
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id
and cv.cell_address='L5T5R5B5'and cv.table_id=0 and label_value in ('k', 'b', 'e', 'h');

INSERT INTO table_model.entry_label (entry_cell_id, label_cell_id)
SELECT cv.cell_id, l.label_cell_id from tabby_cell_view cv, tabby_label_view l where l.table_id = cv.table_id
and cv.cell_address='L6T5R6B5'and cv.table_id=0 and label_value in ('k', 'b', 'f', 'h');

\echo Insert into entry_label for table 1

\echo Insert into entry_label for table 2


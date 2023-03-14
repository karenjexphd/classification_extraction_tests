\echo Insert into category 

INSERT INTO category
(category_name)
VALUES
('GROUP1'),
('GROUP2'),
('GROUP3'),
('GROUP4'),
('GROUP5');

\echo Insert into label for table 0

INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP2', null from tabby_cell_view where cell_address='L3T1R4B1'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP2', null from tabby_cell_view where cell_address='L5T1R6B1'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP3', null from tabby_cell_view where cell_address='L3T2R3B2'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP3', null from tabby_cell_view where cell_address='L4T2R4B2'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP3', null from tabby_cell_view where cell_address='L5T2R5B2'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP3', null from tabby_cell_view where cell_address='L6T2R6B2'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP4', null from tabby_cell_view where cell_address='L1T3R1B4'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP1', null from tabby_cell_view where cell_address='L2T3R2B3'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP1', null from tabby_cell_view where cell_address='L2T4R2B4'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP4', null from tabby_cell_view where cell_address='L1T5R1B5'and table_id=0;
INSERT INTO label (label_cell_id, category_name, parent_label_cell_id) SELECT cell_id, 'GROUP1', null from tabby_cell_view where cell_address='L2T5R2B5'and table_id=0;

\echo Insert into label for table 1

\echo Insert into label for table 2


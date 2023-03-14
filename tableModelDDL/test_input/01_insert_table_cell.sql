\c table_model
set search_path=table_model;

\echo Insert test tables into source_table

INSERT INTO table_model.source_table
(table_id, table_start, table_end)
VALUES
(0, 'A1', 'H7'),
(1, 'A9', 'H15'),
(2, 'A17', 'H23');

\echo 1nsert into table_cell for table 0

INSERT INTO table_model.table_cell 
(
table_id,
cell_content, 
left_col, 
top_row, 
right_col, 
bottom_row, 
cell_datatype,
cell_annotation)
VALUES
(0,'',1,1,2,2,'BLANK', null),
(0,'a',3,1,4,1,'STRING', 'head'),
(0,'b',5,1,6,1,'STRING', 'head'),
(0,'c',3,2,3,2,'STRING', 'head'),
(0,'d',4,2,4,2,'STRING', 'head'),
(0,'e',5,2,5,2,'STRING', 'head'),
(0,'f',6,2,6,2,'STRING', 'head'),
(0,'g',1,3,1,4,'STRING', 'stub'),
(0,'i',2,3,2,3,'STRING', 'stub'),
(0,'1',3,3,3,3,'NUMERIC', 'body'),
(0,'2',4,3,4,3,'NUMERIC', 'body'),
(0,'3',5,3,5,3,'NUMERIC', 'body'),
(0,'',6,3,6,3,'BLANK', 'body'),
(0,'j',2,4,2,4,'STRING', 'stub'),
(0,'5',3,4,3,4,'NUMERIC', 'body'),
(0,'',4,4,4,4,'BLANK', 'body'),
(0,'7',5,4,5,4,'NUMERIC', 'body'),
(0,'8',6,4,6,4,'NUMERIC', 'body'),
(0,'h',1,5,1,5,'STRING', 'stub'),
(0,'k',2,5,2,5,'STRING', 'stub'),
(0,'9',3,5,3,5,'NUMERIC', 'body'),
(0,'10',4,5,4,5,'NUMERIC', 'body'),
(0,'11',5,5,5,5,'NUMERIC', 'body'),
(0,'12',6,5,6,5,'NUMERIC', 'body');

\echo insert into table_cell for table 1

INSERT INTO table_model.table_cell
(
table_id,
cell_content,
left_col,
top_row,
right_col,
bottom_row,
cell_datatype,
cell_annotation)
VALUES
(1,'',1,1,2,2,'BLANK', null),
(1,'a',3,1,4,1,'STRING', 'head'),
(1,'b',5,1,6,1,'STRING', 'head'),
(1,'c',3,2,3,2,'STRING', 'head'),
(1,'d',4,2,4,2,'STRING', 'head'),
(1,'e',5,2,5,2,'STRING', 'head'),
(1,'f',6,2,6,2,'STRING', 'head'),
(1,'g',1,3,1,4,'STRING', 'stub'),
(1,'i',2,3,2,3,'STRING', 'stub'),
(1,'1',3,3,3,3,'NUMERIC', 'body'),
(1,'2',4,3,4,3,'NUMERIC', 'body'),
(1,'3',5,3,5,3,'NUMERIC', 'body'),
(1,'4',6,3,6,3,'NUMERIC', 'body'),
(1,'j',2,4,2,4,'STRING', 'stub'),
(1,'5',3,4,3,4,'NUMERIC', 'body'),
(1,'5',4,4,4,4,'NUMERIC', 'body'),
(1,'7',5,4,5,4,'NUMERIC', 'body'),
(1,'8',6,4,6,4,'NUMERIC', 'body'),
(1,'h',1,5,1,5,'STRING', 'stub'),
(1,'k',2,5,2,5,'STRING', 'stub'),
(1,'9',3,5,3,5,'NUMERIC', 'body'),
(1,'10',4,5,4,5,'NUMERIC', 'body'),
(1,'11',5,5,5,5,'NUMERIC', 'body'),
(1,'12',6,5,6,5,'NUMERIC', 'body');

\echo insert into table_cell for table 2

INSERT INTO table_model.table_cell
(
table_id,
cell_content,
left_col,
top_row,
right_col,
bottom_row,
cell_datatype,
cell_annotation)
VALUES
(2,'',1,1,2,2,'BLANK', null),
(2,'a',3,1,3,1,'STRING', 'head'),
(2,'a',4,1,4,1,'STRING', 'head'),
(2,'b',5,1,5,1,'STRING', 'head'),
(2,'b',6,1,6,1,'STRING', 'head'),
(2,'c',3,2,3,2,'STRING', 'head'),
(2,'d',4,2,4,2,'STRING', 'head'),
(2,'e',5,2,5,2,'STRING', 'head'),
(2,'f',6,2,6,2,'STRING', 'head'),
(2,'g',1,3,1,3,'STRING', 'stub'),
(2,'i',2,3,2,3,'STRING', 'stub'),
(2,'1',3,3,3,3,'NUMERIC', 'body'),
(2,'2',4,3,4,3,'NUMERIC', 'body'),
(2,'3',5,3,5,3,'NUMERIC', 'body'),
(2,'4',6,3,6,3,'NUMERIC', 'body'),
(2,'g',1,4,1,4,'STRING', 'stub'),
(2,'j',2,4,2,4,'STRING', 'stub'),
(2,'5',3,4,3,4,'NUMERIC', 'body'),
(2,'5',4,4,4,4,'NUMERIC', 'body'),
(2,'7',5,4,5,4,'NUMERIC', 'body'),
(2,'8',6,4,6,4,'NUMERIC', 'body'),
(2,'h',1,5,1,5,'STRING', 'stub'),
(2,'k',2,5,2,5,'STRING', 'stub'),
(2,'9',3,5,3,5,'NUMERIC', 'body'),
(2,'10',4,5,4,5,'NUMERIC', 'body'),
(2,'11',5,5,5,5,'NUMERIC', 'body'),
(2,'12',6,5,6,5,'NUMERIC', 'body');


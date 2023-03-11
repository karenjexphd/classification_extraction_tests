\c table_model
set search_path=table_model;


INSERT INTO table_model.source_table
(table_id)
VALUES
(0),
(1),
(2);

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


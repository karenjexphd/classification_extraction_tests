\echo Create "temp" tables in table_model schema - used during processing of input file


\echo Create table entry_temp

CREATE TABLE IF NOT EXISTS table_model.entry_temp 
(table_id integer,
 entry_value text, 
 entry_datatype text,
 entry_provenance text, 
 entry_provenance_col integer, 
 entry_provenance_row integer, 
 entry_labels text);

ALTER TABLE table_model.entry_temp OWNER TO table_model;

\echo Create table label_temp

CREATE TABLE IF NOT EXISTS table_model.label_temp 
(table_id integer,
 label_value text, 
 label_provenance text, 
 label_provenance_col integer,
 label_provenance_row integer,
 label_parent text,
 label_category text);

ALTER TABLE table_model.label_temp OWNER TO table_model;

\echo Create table entry_label_temp

CREATE TABLE IF NOT EXISTS table_model.entry_label_temp 
(table_id integer,
 entry_provenance text,
 label_provenance text);

ALTER TABLE table_model.entry_label_temp OWNER TO table_model;

\echo Create table cell_temp

CREATE TABLE IF NOT EXISTS table_model.cell_temp 
(table_id integer,
 cell_provenance text,
 cell_provenance_col integer,
 cell_provenance_row integer,
 cell_classification text);

ALTER TABLE table_model.cell_temp OWNER TO table_model;

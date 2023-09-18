-- Create indexes on tables in table_model schema to improve view performance

\echo Indexes on table source_table 

-- DROP INDEX source_table_table_name;

CREATE INDEX source_table_table_name 
ON source_table (((((source_table.file_name || '_'::text) || (source_table.sheet_number)::text) || '_'::text) || (source_table.table_number)::text));

-- DROP INDEX source_table_table_is_gt;

CREATE INDEX source_table_table_is_gt 
ON source_table (table_is_gt);

-- DROP INDEX source_table_table_method;

CREATE INDEX source_table_table_method
ON source_table (table_method);

\echo Indexes on table table_cell

-- DROP INDEX table_cell_table_id;

CREATE INDEX table_cell_table_id
ON table_cell(table_id);

\echo Indexes on table category

\echo Indexes on table label

-- DROP INDEX label_cell_id;

CREATE INDEX label_cell_id 
ON table_model.label(label_cell_id);

\echo Indexes on table entry

\echo Indexes on table entry_label

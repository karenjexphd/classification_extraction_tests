\echo Create FK constraints on table_model tables

\echo Create constraints on source_table

ALTER TABLE table_model.source_table
ADD CONSTRAINT uk_source_table UNIQUE (file_name, sheet_number, table_number); 

\echo Create constraints on table_cell

ALTER TABLE table_model.table_cell
ADD CONSTRAINT fk_source_table FOREIGN KEY (table_id)
REFERENCES table_model.source_table(table_id);

\echo Create constraints on entry

ALTER TABLE table_model.entry
ADD CONSTRAINT fk_table_cell FOREIGN KEY (entry_cell_id)
REFERENCES table_model.table_cell(cell_id);

\echo Create constraints on label

ALTER TABLE table_model.label
ADD CONSTRAINT fk_category FOREIGN KEY (category_name)
REFERENCES table_model.category(category_name);

ALTER TABLE table_model.label
ADD CONSTRAINT fk_table_cell FOREIGN KEY (label_cell_id)
REFERENCES table_model.table_cell(cell_id);

ALTER TABLE table_model.label
ADD CONSTRAINT fk_parent_label FOREIGN KEY (parent_label_cell_id)
REFERENCES table_model.label(label_cell_id);

COMMENT ON CONSTRAINT fk_parent_label ON table_model.label IS 'defines parent of a label in a hierarchy';

\echo Create constraints on entry_label

ALTER TABLE table_model.entry_label
ADD CONSTRAINT fk_entry FOREIGN KEY (entry_cell_id)
REFERENCES table_model.entry(entry_cell_id);

ALTER TABLE table_model.entry_label
ADD CONSTRAINT fk_label FOREIGN KEY (label_cell_id)
REFERENCES table_model.label(label_cell_id);



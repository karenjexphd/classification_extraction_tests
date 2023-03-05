\echo Create FK constraints on table_model tables

\echo Create constraints on table_category

ALTER TABLE table_model.table_category
ADD CONSTRAINT fk_logical_table FOREIGN KEY (table_id)
REFERENCES table_model.logical_table(table_id);

ALTER TABLE table_model.table_category
ADD CONSTRAINT fk_category FOREIGN KEY (category_name)
REFERENCES table_model.category(category_name);

\echo Create constraints on entry

ALTER TABLE table_model.entry
ADD CONSTRAINT fk_cell FOREIGN KEY (entry_provenance)
REFERENCES table_model.cell(cell_id);

ALTER TABLE table_model.entry
ADD CONSTRAINT fk_logical_table FOREIGN KEY (table_id)
REFERENCES table_model.logical_table(table_id);

\echo Create constraints on label

ALTER TABLE table_model.label
ADD CONSTRAINT fk_table_category FOREIGN KEY (table_id, category_name)
REFERENCES table_model.table_category(table_id, category_name);

ALTER TABLE table_model.label
ADD CONSTRAINT fk_cell FOREIGN KEY (label_provenance)
REFERENCES table_model.cell(cell_id);

ALTER TABLE table_model.label
ADD CONSTRAINT fk_parent_label FOREIGN KEY (parent_label_value,parent_label_provenance)
REFERENCES table_model.label(label_value,label_provenance);

COMMENT ON CONSTRAINT fk_parent_label ON table_model.label IS 'defines parent of a label in a hierarchy';

\echo Create constraints on entry_label

ALTER TABLE table_model.entry_label
ADD CONSTRAINT fk_entry FOREIGN KEY (entry_value, entry_provenance)
REFERENCES table_model.entry(entry_value, entry_provenance);

ALTER TABLE table_model.entry_label
ADD CONSTRAINT fk_label FOREIGN KEY (label_value, label_provenance)
REFERENCES table_model.label(label_value, label_provenance);



\echo Create table_model objects in table_model schema, owned by table_model role

\echo Create table source_table 

CREATE TABLE IF NOT EXISTS table_model.source_table
(
  table_id integer,
  table_start text,
  table_end text,
  PRIMARY KEY (table_id)
);

ALTER TABLE table_model.source_table OWNER TO table_model;

COMMENT ON TABLE table_model.source_table IS 'Collection of cells that has been identified as a table';
COMMENT ON COLUMN table_model.source_table.table_start IS 'position of cell directly above and to left of table. Position (0,0) within table';
COMMENT ON COLUMN table_model.source_table.table_end IS 'position of cell directly below and to right of table';

\echo Create table table_cell

CREATE TABLE IF NOT EXISTS table_model.table_cell
(
  cell_id integer generated always as identity,
  table_id integer NOT NULL,
  left_col integer NOT NULL,
  top_row integer NOT NULL,
  right_col integer NOT NULL,
  bottom_row integer NOT NULL,
  cell_content text,
  cell_datatype text,
  cell_annotation text,
  PRIMARY KEY (cell_id)
);

ALTER TABLE table_model.table_cell OWNER TO table_model;

COMMENT ON TABLE table_model.table_cell IS 'Rectangular collection of cells in the source table';

COMMENT ON COLUMN table_model.table_cell.cell_id IS 'Surrogate key to identify cell';
COMMENT ON COLUMN table_model.table_cell.left_col IS 'position within table of leftmost column of cell';
COMMENT ON COLUMN table_model.table_cell.top_row IS 'position within table of topmost row of cell';
COMMENT ON COLUMN table_model.table_cell.right_col IS 'position within table of rightmost column of cell';
COMMENT ON COLUMN table_model.table_cell.bottom_row IS 'position within table of last row of cell';
COMMENT ON COLUMN table_model.table_cell.cell_content IS 'textual contents of cell';
COMMENT ON COLUMN table_model.table_cell.cell_datatype IS 'datatype of contents if cell_content not null';
COMMENT ON COLUMN table_model.table_cell.cell_annotation IS 'type of contents: null, head, stub or body';

\echo Create table category

CREATE TABLE IF NOT EXISTS table_model.category
(
  category_name text,
  category_uri text,
  PRIMARY KEY (category_name)
);

ALTER TABLE table_model.category OWNER TO table_model;

COMMENT ON TABLE table_model.category IS 'A column heading in the canonical table';
COMMENT ON COLUMN table_model.category.category_uri IS 'uniform resource identifier representing this category in an external vocabulary';

\echo Create table label

CREATE TABLE IF NOT EXISTS table_model.label
(
  label_cell_id integer,
  category_name text,
  parent_label_cell_id integer,
  PRIMARY KEY (label_cell_id)
);

ALTER TABLE table_model.label OWNER TO table_model;

COMMENT ON TABLE table_model.label IS 'A key that addresses one or more data values (entries)';
COMMENT ON COLUMN table_model.label.parent_label_cell_id IS 'parent of this label in label hierarchy';

\echo Create table entry

CREATE TABLE IF NOT EXISTS table_model.entry
(
  entry_cell_id integer,
  PRIMARY KEY (entry_cell_id)
);

ALTER TABLE table_model.entry OWNER TO table_model;

COMMENT ON TABLE table_model.entry IS 'A data value of a table. A row in the canonical table';

\echo Create table entry_label

CREATE TABLE IF NOT EXISTS table_model.entry_label (
  entry_cell_id integer,
  label_cell_id integer,
  PRIMARY KEY (entry_cell_id, label_cell_id)
);

ALTER TABLE table_model.entry_label OWNER TO table_model;

COMMENT ON TABLE table_model.entry_label IS 'A label that is associated with a data entry';
COMMENT ON COLUMN table_model.entry_label.label_cell_id IS 'Each entry can be associated with only one label in each category';
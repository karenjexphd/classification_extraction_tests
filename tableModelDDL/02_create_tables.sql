\echo Create table_model objects in table_model schema, owned by table_model role

\echo Create table cell

CREATE TABLE IF NOT EXISTS table_model.table_model.cell
(
  cell_id text,
  left_col text,
  top_row integer,
  right_col text,
  bottom_row integer,
  cell_content text,
  cell_annotation text,
  PRIMARY KEY (cell_id)
);

COMMENT ON TABLE table_model.cell IS 'Rectangular collection of cells in the source table. Two cells cannot overlap. Not all cell attributes are modelled';
COMMENT ON COLUMN table_model.cell.left_col IS 'cl in TabbyXL notation: left column boundary of cell';
COMMENT ON COLUMN table_model.cell.top_row IS 'rt in TabbyXL notation: top row boundary of cell';
COMMENT ON COLUMN table_model.cell.right_col IS 'cr in TabbyXL notation: right column boundary of cell';
COMMENT ON COLUMN table_model.cell.bottom_row IS 'rb in TabbyXL notation: bottom row boundary of cell';
COMMENT ON COLUMN table_model.cell.cell_content IS 'text in TabbyXL notation: textual contents of cell';
COMMENT ON COLUMN table_model.cell.cell_annotation IS 'mark in TabbyXL notation: annotation contained in cell, eg $START or $END';

\echo Create table logical_table

CREATE TABLE IF NOT EXISTS table_model.logical_table
(
  table_id integer,
  PRIMARY KEY (table_id)
);

COMMENT ON TABLE table_model.logical_table IS 'Collection of entries and labels that is identified as a table';

\echo Create table category

CREATE TABLE IF NOT EXISTS table_model.category
(
  category_name text,
  category_uri text,
  PRIMARY KEY (category_name)
);

COMMENT ON TABLE table_model.category IS 'Models a category of labels, e.g. ColumnHeading or RowHeading1. Become the row headings of the canonical table';
COMMENT ON COLUMN table_model.category.category_uri IS 'uniform resource identifier representing this category in an external vocabulary';

\echo Create table table_category

CREATE TABLE IF NOT EXISTS table_model.table_category 
(
  table_id integer,
  category_name text,
  PRIMARY KEY (table_id, category_name)
);

\echo Create table label

CREATE TABLE IF NOT EXISTS table_model.label
(
  label_value text,
  label_provenance text,
  table_id integer,
  category_name text,
  parent_label_value text,
  parent_label_provenance text,
  PRIMARY KEY (label_value, label_provenance)
);

COMMENT ON TABLE table_model.label IS 'a key that addresses one or more data values/entries';
COMMENT ON COLUMN table_model.label.label_value IS 'value from cell.cell_contents';
COMMENT ON COLUMN table_model.label.label_provenance IS 'cell.cell_id that denotes the origin of the label';

\echo Create table entry

CREATE TABLE IF NOT EXISTS table_model.entry
(
  entry_value text,
  entry_provenance text,
  table_id integer,
  PRIMARY KEY (entry_value, entry_provenance)
);

COMMENT ON TABLE table_model.entry IS 'a data value of a table. Represents a line in the canonical representation of the table';
COMMENT ON COLUMN table_model.entry.entry_value IS 'value from cell.cell_contents';
COMMENT ON COLUMN table_model.entry.entry_provenance IS 'cell.cell_id that denotes the origin of the entry';

\echo Create table entry_label

CREATE TABLE IF NOT EXISTS table_model.entry_label (
  entry_value text,
  entry_provenance text,
  label_value text,
  label_provenance text,
  PRIMARY KEY (entry_value, entry_provenance, label_value, label_provenance)
);

COMMENT ON TABLE table_model.entry_label IS 'a label that is associated with a data entry. Each entry can be associated with only one label in each category';


-- Create views to represent the canonnical form for each of the methods
-- NB: These views should not currently be required

-- 1. CREATE VIEWS SPECIFIC TO TABBYXL CANONICAL FORM

\echo Create view tabby_cell_view
\echo Uses table_start to convert cell addresses to physical location in input file

DROP VIEW IF EXISTS tabby_cell_view CASCADE;
CREATE VIEW tabby_cell_view AS
SELECT 
  st.table_id,
  tc.cell_id, 
  'L'||tc.left_col||'T'||tc.top_row||'R'||tc.right_col||'B'||tc.bottom_row as cell_address, 
  chr(ascii(st.table_start_col) + tc.left_col)||(st.table_start_row + tc.top_row) AS cell_provenance,
  cell_content,
  cell_annotation 
FROM table_cell tc 
JOIN source_table st
ON   tc.table_id = st.table_id;

ALTER VIEW tabby_cell_view OWNER TO table_model;

\echo Create view tabby_entry_view

DROP VIEW IF EXISTS tabby_entry_view;
CREATE VIEW tabby_entry_view AS
SELECT
  cv.table_id,
  cv.cell_id,
  cv.cell_content as entry,
  cv.cell_provenance as provenance
FROM entry e
JOIN tabby_cell_view cv
ON   e.entry_cell_id = cv.cell_id;

ALTER VIEW tabby_entry_view OWNER TO table_model;

\echo Create view tabby_label_view

DROP VIEW IF EXISTS tabby_label_view;
CREATE VIEW tabby_label_view AS
SELECT cv.table_id,
    cv.cell_id AS label_cell_id,
    cv.cell_content AS label_value,
    CASE 
      WHEN parent_cell.cell_content IS NOT NULL 
      THEN (parent_cell.cell_content || ' | '::text) || cv.cell_content
      ELSE cv.cell_content
    END AS label_display_value,
    cv.cell_provenance AS label_provenance,
    l.category_name AS category,
    parent_cell.cell_id AS parent_label_cell_id,
    parent_cell.cell_content AS parent_label_value,
    parent_cell.cell_provenance AS parent_label_provenance
   FROM label l
     JOIN tabby_cell_view cv ON l.label_cell_id = cv.cell_id
     LEFT JOIN tabby_cell_view parent_cell ON l.parent_label_cell_id = parent_cell.cell_id;

ALTER VIEW tabby_label_view OWNER TO table_model;

\echo Create view tabby_entry_label_view

-- Based on entry_label, with additional information from table_cell

-- WHAT HAPPENED TO THE ENTRIES IN CATEGORY ColumnHeading ??
-- FIX THIS !!

DROP VIEW IF EXISTS tabby_entry_label_view;
CREATE VIEW tabby_entry_label_view AS
SELECT
  entry_cell.table_id,
  entry_cell.cell_id as entry_cell_id,
  entry_cell.cell_content as entry_value,
  entry_cell.cell_provenance as entry_provenance,
  label_cell.cell_id as label_cell_id,
  label_cell.cell_content as label_value,
  label_cell.cell_provenance as label_provenance,
  tlv.label_display_value,
  tlv.category
FROM entry_label el
JOIN tabby_cell_view entry_cell
ON   el.entry_cell_id = entry_cell.cell_id
JOIN tabby_label_view tlv            
ON   el.label_cell_id = tlv.label_cell_id 
JOIN tabby_cell_view label_cell
ON   el.label_cell_id = label_cell.cell_id;

ALTER VIEW tabby_entry_label_view OWNER TO table_model;

-- 2. CREATE VIEWS SPECIFIC TO PYTHEAS CANONICAL FORM

\echo Create pytheas_canonical_table_view

CREATE OR REPLACE VIEW pytheas_canonical_table_view
AS
SELECT st.table_id, st.file_name, st.table_number, tc.top_row AS table_row, st.table_start_row+tc.top_row AS row_provenance, tc.cell_annotation
FROM source_table st 
JOIN table_cell tc 
ON st.table_id = tc.table_id
ORDER BY cell_annotation DESC;

ALTER VIEW pytheas_canonical_table_view OWNER TO table_model;

-- 3. CREATE VIEWS SPECIFIC TO HYPOPARSR CANONICAL FORM

-- TO DO: REPLACE table_row WITH ID OF ROW IN DATAFRAME (ie DELETE max(top_row) WHERE cell_annotation='HEADING')
CREATE OR REPLACE VIEW hypoparsr_canonical_table_view
AS
SELECT st.table_id, 
       st.file_name, 
       st.table_number, 
       col_headings.cell_content AS column_heading,
       tc.top_row AS table_row,
       tc.cell_content 
FROM  source_table st 
JOIN  table_cell tc 
      ON st.table_id = tc.table_id
JOIN  table_cell col_headings 
      ON tc.table_id = col_headings.table_id
      AND tc.left_col = col_headings.left_col
WHERE tc.cell_annotation='DATA'
AND   col_headings.cell_annotation='HEADING'
ORDER BY 1, 2, 3, 5, 4;

ALTER VIEW hypoparsr_canonical_table_view OWNER TO table_model;
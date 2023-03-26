
\echo Create view table_start_view

DROP VIEW IF EXISTS table_start_view CASCADE;
CREATE VIEW table_start_view AS
SELECT
  table_id,
  table_start,
  regexp_replace(table_start,'[0-9]','','g') as start_col,
  cast(regexp_replace(table_start,'[a-zA-Z]','','g') as INTEGER) as start_row
  FROM source_table;

ALTER VIEW table_start_view OWNER TO table_model;


\echo Create view tabby_cell_view
\echo Uses table_start to convert cell addresses to physical location in input file

DROP VIEW IF EXISTS tabby_cell_view CASCADE;
CREATE VIEW tabby_cell_view AS
WITH table_start AS (
  SELECT
  st.table_id,
  ascii(regexp_replace(st.table_start,'[0-9]','','g')) as start_col,
  cast(regexp_replace(st.table_start,'[a-zA-Z]','','g') as INTEGER) as start_row
  FROM source_table st)
SELECT 
  ts.table_id,
  tc.cell_id, 
  'L'||tc.left_col||'T'||tc.top_row||'R'||tc.right_col||'B'||tc.bottom_row 
    as cell_address, 
  chr(ts.start_col + tc.left_col)||(ts.start_row + tc.top_row) AS cell_provenance,
  cell_content,
  cell_annotation 
FROM table_cell tc 
JOIN table_start ts
ON   tc.table_id = ts.table_id;

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
SELECT
 cv.table_id,
 cv.cell_id as label_cell_id,
 cv.cell_content as label_value,
 cv.cell_provenance as label_provenance,
 l.category_name as category,
 parent_cell.cell_id as parent_label_cell_id,
 parent_cell.cell_content as parent_label_value,
 parent_cell.cell_provenance as parent_label_provenance
FROM label l
JOIN tabby_cell_view cv
ON   l.label_cell_id = cv.cell_id
LEFT JOIN tabby_cell_view parent_cell
ON   l.parent_label_cell_id = parent_cell.cell_id;

ALTER VIEW tabby_label_view OWNER TO table_model;


\echo Create view tabby_entry_label_view

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
  l.category_name as category
FROM entry_label el
JOIN tabby_cell_view entry_cell
ON   el.entry_cell_id = entry_cell.cell_id
JOIN label l
ON   el.label_cell_id = l.label_cell_id 
JOIN tabby_cell_view label_cell
ON   el.label_cell_id = label_cell.cell_id;

ALTER VIEW tabby_entry_label_view OWNER TO table_model;


CREATE OR REPLACE PROCEDURE create_canonical_table_view (in_table_id NUMERIC)
AS $$
DECLARE rec RECORD;
DECLARE str text;
BEGIN
str := '"Entry Value" text,';
   -- looping to get column heading string
   FOR rec IN SELECT DISTINCT category
        FROM tabby_entry_label_view
        WHERE table_id=in_table_id
        ORDER BY category
    LOOP
    str :=  str || '"' || rec.category || '" text' ||',';
    END LOOP;
    str:= substring(str, 0, length(str));

    EXECUTE 'CREATE EXTENSION IF NOT EXISTS tablefunc;
    DROP VIEW IF EXISTS canonical_table_view;
    CREATE VIEW canonical_table_view AS
    SELECT *
    FROM crosstab(''SELECT entry_value, category, label_value FROM tabby_entry_label_view WHERE table_id='|| in_table_id ||' ORDER BY 1'',
                  ''SELECT DISTINCT category FROM tabby_entry_label_view WHERE table_id='|| in_table_id ||' ORDER BY 1'')
         AS final_result ('|| str ||')';
    ALTER VIEW canonical_table_view OWNER TO table_model;
END;
$$ LANGUAGE plpgsql;

ALTER PROCEDURE create_canonical_table_view OWNER TO table_model;


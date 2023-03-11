DROP VIEW cell;
CREATE VIEW cell AS
WITH table_start AS (
  SELECT
  st.table_id,
  ascii(regexp_replace(st.table_start,'[0-9]','','g')) as start_col,
  cast(regexp_replace(st.table_start,'[a-zA-Z]','','g') as INTEGER) as start_row
  FROM source_table st)
SELECT 
  tc.cell_id, 
  'L'||tc.left_col||'T'||tc.top_row||'R'||tc.right_col||'B'||tc.bottom_row 
    as cell_address, 
  chr(ts.start_col + tc.left_col)||(ts.start_row + tc.top_row) AS cell_provenance,
  cell_content 
FROM table_cell tc 
JOIN table_start ts
ON   tc.table_id = ts.table_id;

ALTER VIEW cell OWNER TO table_model;


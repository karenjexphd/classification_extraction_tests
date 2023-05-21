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

-- 4. CREATE VIEWS TO SUPPORT EVALUATION

-- 4.1 CREATE VIEW TO IDENTIFY ASSOCIATED OUTPUT TABLE FOR EACH GROUND TRUTH TABLE

\echo Create tables_to_compare view

-- returns one row per table and per method containing
-- ground truth table_id and associated output table_id 

CREATE OR REPLACE VIEW tables_to_compare AS
WITH 
    gt_tables AS (
      SELECT 
        table_id, 
        file_name||'_'||sheet_number||'_'||table_number AS table_name 
      FROM source_table 
      WHERE table_is_gt),
    output_tables AS (
      SELECT 
        table_id, 
        table_method,
        file_name||'_'||sheet_number||'_'||table_number AS table_name 
      FROM source_table 
    WHERE NOT table_is_gt)
SELECT 
  gt_tables.table_id AS gt_table_id,
  output_tables.table_id AS output_table_id,
  gt_tables.table_name,
  output_tables.table_method 
FROM gt_tables
  LEFT JOIN output_tables -- RETURN ALL GT TABLES WHETHER OR NOT AN OUTPUT TABLE EXISTS
    ON gt_tables.table_name = output_tables.table_name
ORDER BY table_method, gt_table_id;

ALTER VIEW tables_to_compare OWNER TO table_model;

-- 4.2 CREATE VIEWS THAT RETURN THE 'SET OF INSTANCES'
--     S for ground truth
--     R for extracted tables
--     views are based on tables_to_compare view

\echo Create gt_label_set view
-- for each table, return the "set of labels" from the ground truth

CREATE OR REPLACE VIEW gt_label_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  table_cell.left_col, 
  table_cell.top_row, 
  label.category_name, 
  table_cell.cell_content AS label
FROM source_table 
  JOIN table_cell
    ON source_table.table_id = table_cell.table_id
  JOIN label
    ON label.label_cell_id = table_cell.cell_id
WHERE source_table.table_is_gt;

ALTER VIEW gt_label_set OWNER TO table_model;

\echo Create output_label_set view
-- for each method, and for each table, return the extracted "set of labels"

CREATE OR REPLACE VIEW output_label_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  source_table.table_method,
  table_cell.left_col, 
  table_cell.top_row, 
  label.category_name, 
  table_cell.cell_content AS label
FROM source_table 
  JOIN table_cell
    ON source_table.table_id = table_cell.table_id
  JOIN label
    ON label.label_cell_id = table_cell.cell_id
WHERE NOT source_table.table_is_gt;

ALTER VIEW output_label_set OWNER TO table_model;

\echo Create gt_entry_set view
-- for each table, return the "set of entries" from the ground truth

CREATE OR REPLACE VIEW gt_entry_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  table_cell.left_col, 
  table_cell.top_row, 
  table_cell.cell_content AS entry 
FROM source_table
  JOIN table_cell
    ON source_table.table_id = table_cell.table_id
  JOIN entry
    ON entry.entry_cell_id = table_cell.cell_id
WHERE source_table.table_is_gt;

ALTER VIEW gt_entry_set OWNER TO table_model;

\echo Create output_entry_set view
-- for each method, and for each table, return the extracted "set of entries"

CREATE OR REPLACE VIEW output_entry_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  source_table.table_method,
  table_cell.left_col, 
  table_cell.top_row, 
  table_cell.cell_content AS entry 
FROM source_table
  JOIN table_cell
    ON source_table.table_id = table_cell.table_id
  JOIN entry
    ON entry.entry_cell_id = table_cell.cell_id
WHERE NOT source_table.table_is_gt;

ALTER VIEW output_entry_set OWNER TO table_model;

\echo Create gt_entry_label_set view
-- for each table, return the "set of entry-label pairs" from the ground truth

CREATE OR REPLACE VIEW gt_entry_label_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  entry_table_cell.left_col, 
  entry_table_cell.top_row, 
  entry_table_cell.cell_content AS entry, 
  label_table_cell.cell_content AS label
FROM source_table
  JOIN table_cell entry_table_cell
    ON source_table.table_id = entry_table_cell.table_id
  JOIN table_cell label_table_cell
    ON source_table.table_id = label_table_cell.table_id
  JOIN entry_label
    ON entry_label.entry_cell_id = entry_table_cell.cell_id
    AND entry_label.label_cell_id = label_table_cell.cell_id
WHERE source_table.table_is_gt;

ALTER VIEW gt_entry_label_set OWNER TO table_model;

\echo Create output_entry_label_set view
-- for each method, and for each table, return the extracted "set of entry-label pairs"

CREATE OR REPLACE VIEW output_entry_label_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  source_table.table_method,
  entry_table_cell.left_col, 
  entry_table_cell.top_row, 
  entry_table_cell.cell_content AS entry, 
  label_table_cell.cell_content AS label
FROM source_table
  JOIN table_cell entry_table_cell
    ON source_table.table_id = entry_table_cell.table_id
  JOIN table_cell label_table_cell
    ON source_table.table_id = label_table_cell.table_id
  JOIN entry_label
    ON entry_label.entry_cell_id = entry_table_cell.cell_id
    AND entry_label.label_cell_id = label_table_cell.cell_id
WHERE NOT source_table.table_is_gt;

ALTER VIEW output_entry_label_set OWNER TO table_model;

\echo Create gt_label_label_set view
-- for each table, return the "set of label-label pairs" from the ground truth

CREATE OR REPLACE VIEW gt_label_label_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  label_table_cell.left_col, 
  label_table_cell.top_row, 
  label_table_cell.cell_content AS label, 
  parent_label_table_cell.cell_content as parent_label
FROM source_table
  JOIN table_cell label_table_cell
    ON source_table.table_id = label_table_cell.table_id
  JOIN table_cell parent_label_table_cell
    ON source_table.table_id = parent_label_table_cell.table_id
  JOIN label
    ON label.label_cell_id = label_table_cell.cell_id
    AND label.parent_label_cell_id = parent_label_table_cell.cell_id
WHERE source_table.table_is_gt;

ALTER VIEW gt_label_label_set OWNER TO table_model;

\echo Create output_label_label_set view
-- for each method, and for each table, return the extracted "set of label-label pairs"

CREATE OR REPLACE VIEW output_label_label_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  source_table.table_method,
  label_table_cell.left_col, 
  label_table_cell.top_row, 
  label_table_cell.cell_content AS label, 
  parent_label_table_cell.cell_content AS parent_label
FROM source_table
  JOIN table_cell label_table_cell
    ON source_table.table_id = label_table_cell.table_id
  JOIN table_cell parent_label_table_cell 
    ON source_table.table_id = parent_label_table_cell.table_id
  JOIN label
    ON label.label_cell_id = label_table_cell.cell_id
    AND label.parent_label_cell_id = parent_label_table_cell.cell_id
WHERE NOT source_table.table_is_gt;

ALTER VIEW output_label_label_set OWNER TO table_model;


-- 4.3 CREATE VIEWS THAT RETURN THE CONFUSION MATRIX
--     S for ground truth
--     R for extracted tables
--     views are based on the gt_<instance>_set and output_<instance>_set views

\echo Create entry_confusion view
-- Confusion matrix for the set of entries per table and per model

CREATE OR REPLACE VIEW entry_confusion AS
WITH data (
  method_name, 
  table_name,
  output_table_name,
  gt_entry_count, 
  output_entry_count,
  true_positive_count, 
  false_positive_count, 
  false_negative_count) 
AS (
  SELECT DISTINCT
    tables_to_compare.table_method,
    gt_entry_set.table_name,
    output_entry_set.table_name,
    /* total number of items in the ground truth set */
    count(*)
      filter( where gt_entry_set.table_name is not null)
      over (partition by tables_to_compare.table_name, tables_to_compare.table_method) as gt_entry_count,
    /* total number of items in the extracted set */
    count(*)
      filter(where output_entry_set.table_name is not null)
      over (partition by output_entry_set.table_name, output_entry_set.table_method) as output_entry_count,
    /* intersection - true positives */
    count(*)
      filter(where output_entry_set.table_name is not null and gt_entry_set.table_name is not null)
      over (partition by tables_to_compare.table_name, output_entry_set.table_method) as true_positive_count,
    /* false positives */
    count(*)
      filter(where output_entry_set.table_name is not null and gt_entry_set.table_name is null)
      over (partition by output_entry_set.table_name, output_entry_set.table_method) as false_positive_count,
    /* false negatives */
    count(*)
      FILTER(WHERE gt_entry_set.table_name IS NOT NULL AND output_entry_set.table_name IS NULL)
      OVER (PARTITION BY tables_to_compare.table_name, tables_to_compare.table_method) AS false_negative_count
  FROM gt_entry_set
    /* Natural join will join on table_name and remove the duplicated column table_name */
    NATURAL JOIN tables_to_compare
    /* We now need the extracted values */ 
    FULL OUTER JOIN output_entry_set
      ON gt_entry_set.table_name = output_entry_set.table_name
        AND gt_entry_set.entry = output_entry_set.entry
        AND gt_entry_set.left_col = output_entry_set.left_col
        AND gt_entry_set.top_row = output_entry_set.top_row
        AND tables_to_compare.table_method = output_entry_set.table_method                          
  ORDER BY tables_to_compare.table_method, gt_entry_set.table_name
)
SELECT *
FROM data
WHERE output_table_name IS NOT NULL
  AND table_name IS NOT NULL;

ALTER VIEW entry_confusion OWNER TO table_model;

\echo Create label_confusion view
-- Confusion matrix for the set of labels per table and per model

CREATE OR REPLACE VIEW label_confusion AS
WITH data (
  method_name, 
  table_name,
  output_table_name,
  gt_label_count, 
  output_label_count,
  true_positive_count, 
  false_positive_count, 
  false_negative_count) 
AS (
  SELECT DISTINCT
    tables_to_compare.table_method,
    gt_label_set.table_name,
    output_label_set.table_name,
    /* total number of items in the ground truth set */
    count(*)
      filter( where gt_label_set.table_name is not null)
      over (partition by tables_to_compare.table_name, tables_to_compare.table_method) as gt_label_count,
    /* total number of items in the extracted set */
    count(*)
      filter(where output_label_set.table_name is not null)
      over (partition by output_label_set.table_name, output_label_set.table_method) as output_label_count,
    /* intersection - true positives */
    count(*)
      filter(where output_label_set.table_name is not null and gt_label_set.table_name is not null)
      over (partition by tables_to_compare.table_name, output_label_set.table_method) as true_positive_count,
    /* false positives */
    count(*)
      filter(where output_label_set.table_name is not null and gt_label_set.table_name is null)
      over (partition by output_label_set.table_name, output_label_set.table_method) as false_positive_count,
    /* false negatives */
    count(*)
      FILTER(WHERE gt_label_set.table_name IS NOT NULL AND output_label_set.table_name IS NULL)
      OVER (PARTITION BY tables_to_compare.table_name, tables_to_compare.table_method) AS false_negative_count
  FROM gt_label_set
    /* Natural join will join on table_name and remove the duplicated column table_name */
    NATURAL JOIN tables_to_compare
    /* We now need the extracted values */ 
    FULL OUTER JOIN output_label_set
      ON gt_label_set.table_name = output_label_set.table_name
        AND gt_label_set.label = output_label_set.label
        AND gt_label_set.left_col = output_label_set.left_col
        AND gt_label_set.top_row = output_label_set.top_row
        AND gt_label_set.category_name = output_label_set.category_name
        AND tables_to_compare.table_method = output_label_set.table_method                          
  ORDER BY tables_to_compare.table_method, gt_label_set.table_name
)
SELECT *
FROM data
WHERE output_table_name IS NOT NULL
  AND table_name IS NOT NULL;

ALTER VIEW label_confusion OWNER TO table_model;

\echo Create entry_label_confusion view
-- Confusion matrix for the set of entry-label pairs per table and per model

CREATE OR REPLACE VIEW entry_label_confusion AS
WITH gtelc AS
(select table_name, count(*) AS gt_entry_label_count
FROM gt_entry_label_set
GROUP BY table_name),
oelc AS
(select table_name, table_method, count(*) AS output_entry_label_count
FROM output_entry_label_set
GROUP BY table_name, table_method),
eltp AS
(SELECT oel.table_name, oel.table_method, count(*) AS entry_label_true_pos
FROM gt_entry_label_set gtel
JOIN output_entry_label_set oel
ON gtel.table_name=oel.table_name
AND gtel.left_col=oel.left_col
AND gtel.top_row=oel.top_row
AND gtel.label=oel.label
--AND gtel.category_name=oel.category_name
group by oel.table_name, oel.table_method)
SELECT t2c.table_name,
       t2c.table_method as method_name,
       COALESCE(gtelc.gt_entry_label_count,0) AS gt_total_entry_labels,
       COALESCE(oelc.output_entry_label_count,0) AS output_total_entry_labels,
       COALESCE(oelc.output_entry_label_count,0)-COALESCE(eltp.entry_label_true_pos,0) AS entry_label_false_pos,
       COALESCE(gtelc.gt_entry_label_count,0)-COALESCE(eltp.entry_label_true_pos,0) AS entry_label_false_neg,
       COALESCE(eltp.entry_label_true_pos,0) AS entry_label_true_pos
FROM tables_to_compare t2c	-- driving table for list of table_names
LEFT JOIN gtelc ON t2c.table_name=gtelc.table_name
LEFT JOIN oelc ON t2c.table_name=oelc.table_name AND t2c.table_method=oelc.table_method
LEFT JOIN eltp ON t2c.table_name=eltp.table_name AND t2c.table_method=eltp.table_method
ORDER BY table_name, method_name;

ALTER VIEW entry_label_confusion OWNER TO table_model;

\echo Create label_label_confusion view
-- Confusion matrix for the set of label-label pairs per table and per model

CREATE OR REPLACE VIEW label_label_confusion AS
WITH gtllc AS
(select table_name, count(*) AS gt_label_label_count
FROM gt_label_label_set
GROUP BY table_name),
ollc AS
(select table_name, table_method, count(*) AS output_label_label_count
FROM output_entry_label_set
GROUP BY table_name, table_method),
lltp AS
(SELECT oll.table_name, oll.table_method, count(*) AS label_label_true_pos
FROM gt_label_label_set gtll
JOIN output_label_label_set oll
ON gtll.table_name=oll.table_name
AND gtll.left_col=oll.left_col
AND gtll.top_row=oll.top_row
AND gtll.label=oll.label
--AND gtll.category_name=oll.category_name
group by oll.table_name, oll.table_method)
SELECT t2c.table_name,
       t2c.table_method as method_name,
       COALESCE(gtllc.gt_label_label_count,0) AS gt_total_label_labels,
       COALESCE(ollc.output_label_label_count,0) AS output_total_label_labels,
       COALESCE(ollc.output_label_label_count,0)-COALESCE(lltp.label_label_true_pos,0) AS label_label_false_pos,
       COALESCE(gtllc.gt_label_label_count,0)-COALESCE(lltp.label_label_true_pos,0) AS label_label_false_neg,
       COALESCE(lltp.label_label_true_pos,0) AS label_label_true_pos
FROM tables_to_compare t2c	-- driving table for list of table_names
LEFT JOIN gtllc ON t2c.table_name=gtllc.table_name
LEFT JOIN ollc ON t2c.table_name=ollc.table_name AND t2c.table_method=ollc.table_method
LEFT JOIN lltp ON t2c.table_name=lltp.table_name AND t2c.table_method=lltp.table_method
ORDER BY table_name, method_name;

ALTER VIEW label_label_confusion OWNER TO table_model;

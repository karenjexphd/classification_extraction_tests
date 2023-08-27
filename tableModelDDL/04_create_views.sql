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

-- 4.0 CREATE FUNCTION TO IDENTIFY MATCH BETWEEN TWO NUMERIC OR TEXT VALUES

\echo Create function is_reconcilable()


CREATE OR REPLACE FUNCTION is_reconcilable(val1 text, val2 text) RETURNS boolean
    IMMUTABLE
    RETURNS NULL ON NULL INPUT
    AS
    $BODY$
    BEGIN
      -- compare as numeric if the following rules are obeyed (note, these could be improved):
      --   1. may or may not start with a minus sign
      --   2. remaining string contains repetitions of: one or more characters 0-9 followed by 0 or one comma, full stop or space
      -- in this case, strip the comma, full stop and space characters via regexp_replace(val1,'[,. ]','',gi)
      --  and trim any trailing zeros via rtrim(string,'0')
      -- then compare the resulting values 
      -- this could of course result in false positives - 6430 would match 643 - but it is unlikely that we would compare two such numbers in the tests
      IF val1 SIMILAR TO '-?([0-9]+[,. ]?)+' THEN
        RETURN rtrim(regexp_replace(val1,'[,. ]','','gi'),'0') = rtrim(regexp_replace(val2,'[,. ]','','gi'),'0');
      ELSE
      -- otherwise compare as text with the following conditions:
      --  1. perform case-insensitive comparison
      --  2. ignore leading spaces
        RETURN lower(ltrim(val1)) = lower(ltrim(val2));
      END IF;
    END;    
    $BODY$
    LANGUAGE plpgsql;

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


-- definitive list of tables and methods to be compared
-- one row per table and per method

-- THERE MUST BE A BETTER WAY TO DO THIS !

CREATE OR REPLACE VIEW table_method_list AS
    WITH 
      table_names AS (SELECT DISTINCT file_name||'_'||sheet_number||'_'||table_number AS table_name FROM source_table),
      table_methods AS (SELECT DISTINCT table_method FROM source_table)
    SELECT
      table_names.table_name,
      table_methods.table_method
    FROM
      table_names CROSS JOIN table_methods;

ALTER VIEW table_method_list OWNER TO table_model;

-- 4.3 CREATE VIEWS THAT RETURN THE CONFUSION MATRIX
--     S for ground truth
--     R for extracted tables
--     views are based on the gt_<instance>_set and output_<instance>_set views


-- ENTRY_CONFUSION - views to display confusion matrix for set of entries

\echo Create entry_confusion view (and the views that are used to build it)

-- One row per table and per method being compared
-- Count is zero if no entries exist for given table
CREATE OR REPLACE VIEW gt_entry_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) FILTER( WHERE gt_entry_set.table_name is not null) AS gt_entries
  FROM table_method_list   -- use table_method_list as driving table
    LEFT JOIN gt_entry_set -- ensures one row per table and per method
      ON table_method_list.table_name = gt_entry_set.table_name
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW gt_entry_counts OWNER TO table_model;

-- One row per table and per method being compared. 
-- Count is zero if no entries exist for given table nd method
CREATE OR REPLACE VIEW output_entry_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) FILTER( WHERE output_entry_set.table_name is not null) AS output_entries
  FROM table_method_list       -- use table_method_list as driving table
    FULL JOIN output_entry_set -- ensures one row per table and per method
      ON  table_method_list.table_name = output_entry_set.table_name
      AND table_method_list.table_method = output_entry_set.table_method
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW output_entry_counts OWNER TO table_model;

-- Intersection of ground truth and output per table and per method

CREATE OR REPLACE VIEW entry_true_positives AS
  SELECT
    table_method_list.table_name, 
    table_method_list.table_method, 
    -- NB MAY WANT TO ADD MATCH ON left_col AND top_row
    count(*) 
      FILTER (
        -- WHERE output_entry_set.entry = gt_entry_set.entry
        WHERE is_reconcilable(output_entry_set.entry,gt_entry_set.entry)
        AND output_entry_set.left_col = gt_entry_set.left_col
        AND output_entry_set.top_row = gt_entry_set.top_row) 
      AS entry_true_pos
  FROM table_method_list
    FULL JOIN output_entry_set
      ON table_method_list.table_name = output_entry_set.table_name
      AND table_method_list.table_method = output_entry_set.table_method
    FULL JOIN gt_entry_set 
      ON table_method_list.table_name = gt_entry_set.table_name
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW entry_true_positives OWNER TO table_model;

CREATE OR REPLACE VIEW entry_confusion AS
WITH data AS (
SELECT 
  table_method_list.table_method,
  table_method_list.table_name,
  gt_entry_counts.gt_entries,
  output_entry_counts.output_entries,
  entry_true_positives.entry_true_pos AS e_true_pos,
  output_entry_counts.output_entries - entry_true_positives.entry_true_pos AS e_false_pos,
  gt_entry_counts.gt_entries - entry_true_positives.entry_true_pos AS e_false_neg,
  CASE 
    -- Avoid divide by zero error if no output_entries
    WHEN output_entry_counts.output_entries=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (entry_true_positives.entry_true_pos::numeric/output_entry_counts.output_entries)::numeric(4,3)
  END AS e_precision,
  CASE 
    -- Avoid divide by zero error if no gt_entries
    WHEN gt_entry_counts.gt_entries=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (entry_true_positives.entry_true_pos::numeric/gt_entry_counts.gt_entries)::numeric(4,3)
  END AS e_recall
FROM table_method_list
  JOIN output_entry_counts
    ON table_method_list.table_name = output_entry_counts.table_name
    AND table_method_list.table_method = output_entry_counts.table_method
  JOIN gt_entry_counts
    ON table_method_list.table_name = gt_entry_counts.table_name
    AND table_method_list.table_method = gt_entry_counts.table_method
  JOIN entry_true_positives
    ON table_method_list.table_name = entry_true_positives.table_name
    AND table_method_list.table_method = entry_true_positives.table_method
ORDER BY table_method_list.table_method, table_method_list.table_name)
SELECT 
  -- Select all rows from subquery and calculate f-measure based on precision and recall
  *,
  CASE 
    -- Avoid divide by zero error if no output_entry_labels
    WHEN e_precision+e_recall=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (2*e_precision*e_recall/(e_precision+e_recall))::numeric(4,3)
  END AS e_f_measure
FROM data;

ALTER VIEW entry_confusion OWNER TO table_model;

-- LABEL_CONFUSION - views to display confusion matrix for set of labels

\echo Create label_confusion view (and the views that are used to build it)

-- One row per table and per method being compared
-- Count is zero if no labels exist for given table
CREATE OR REPLACE VIEW gt_label_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) FILTER( WHERE gt_label_set.table_name is not null) AS gt_labels
  FROM table_method_list   -- use table_method_list as driving table
    LEFT JOIN gt_label_set -- ensures one row per table and per method
      ON table_method_list.table_name = gt_label_set.table_name
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW gt_label_counts OWNER TO table_model;

-- One row per table and per method being compared. 
-- Count is zero if no labels exist for given tbale nd method
CREATE OR REPLACE VIEW output_label_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) FILTER( WHERE output_label_set.table_name is not null) AS output_labels
  FROM table_method_list       -- use table_method_list as driving table
    LEFT JOIN output_label_set -- ensures one row per table and per method
      ON table_method_list.table_name = output_label_set.table_name
      AND table_method_list.table_method = output_label_set.table_method
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW output_label_counts OWNER TO table_model;

-- Intersection of ground truth and output per table and per method
CREATE OR REPLACE VIEW label_true_positives AS
  SELECT
    table_method_list.table_name, 
    table_method_list.table_method, 
    count(*) 
      FILTER (
        -- WHERE output_label_set.label = gt_label_set.label
        WHERE is_reconcilable(output_label_set.label,gt_label_set.label)
        AND output_label_set.left_col = gt_label_set.left_col
        AND output_label_set.top_row = gt_label_set.top_row)  
      AS label_true_pos
  FROM table_method_list
    FULL JOIN output_label_set
      ON table_method_list.table_name = output_label_set.table_name
      AND table_method_list.table_method = output_label_set.table_method
    FULL JOIN gt_label_set 
      ON table_method_list.table_name = gt_label_set.table_name
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW label_true_positives OWNER TO table_model;

CREATE OR REPLACE VIEW label_confusion AS
WITH data AS (
SELECT 
  table_method_list.table_method,
  table_method_list.table_name,
  gt_label_counts.gt_labels,
  output_label_counts.output_labels,
  label_true_positives.label_true_pos AS l_true_pos,
  output_label_counts.output_labels - label_true_positives.label_true_pos AS l_false_pos,
  gt_label_counts.gt_labels - label_true_positives.label_true_pos AS l_false_neg,
  CASE 
    -- Avoid divide by zero error if no output_labels
    WHEN output_label_counts.output_labels=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (label_true_positives.label_true_pos::numeric/output_label_counts.output_labels)::numeric(4,3)
  END AS l_precision,
  CASE 
    -- Avoid divide by zero error if no gt_labels
    WHEN gt_label_counts.gt_labels=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (label_true_positives.label_true_pos::numeric/gt_label_counts.gt_labels)::numeric(4,3)
  END AS l_recall
FROM table_method_list
  JOIN output_label_counts
    ON table_method_list.table_name = output_label_counts.table_name
    AND table_method_list.table_method = output_label_counts.table_method
  JOIN gt_label_counts
    ON table_method_list.table_name = gt_label_counts.table_name
    AND table_method_list.table_method = gt_label_counts.table_method
  JOIN label_true_positives
    ON table_method_list.table_name = label_true_positives.table_name
    AND table_method_list.table_method = label_true_positives.table_method
ORDER BY table_method_list.table_method, table_method_list.table_name)
SELECT 
  -- Select all rows from subquery and calculate f-measure based on precision and recall
  *,
  CASE 
    -- Avoid divide by zero error if no output_entry_labels
    WHEN l_precision+l_recall=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (2*l_precision*l_recall/(l_precision+l_recall))::numeric(4,3)
  END AS l_f_measure
FROM data;

ALTER VIEW label_confusion OWNER TO table_model;

-- LABEL_LABEL_CONFUSION - views to display confusion matrix for set of label-label pairs

\echo Create label_label_confusion view (and the views that are used to build it)

-- One row per table and per method being compared
-- Count is zero if no label-label pairs exist for given table
CREATE OR REPLACE VIEW gt_label_label_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) filter( where gt_label_label_set.table_name is not null) AS gt_label_labels
  FROM table_method_list   -- use table_method_list as driving table
    LEFT JOIN gt_label_label_set -- ensures one row per table and per method
      ON table_method_list.table_name = gt_label_label_set.table_name
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW gt_label_label_counts OWNER TO table_model;

-- One row per table and per method being compared. 
-- Count is zero if no label-label pairs exist for given tbale nd method
CREATE OR REPLACE VIEW output_label_label_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) filter( where output_label_label_set.table_name is not null) AS output_label_labels
  FROM table_method_list       -- use table_method_list as driving table
    LEFT JOIN output_label_label_set -- ensures one row per table and per method
      ON table_method_list.table_name = output_label_label_set.table_name
      AND table_method_list.table_method = output_label_label_set.table_method
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW output_label_label_counts OWNER TO table_model;

-- Intersection of ground truth and output per table and per method
CREATE OR REPLACE VIEW label_label_true_positives AS
  SELECT
    table_method_list.table_name, 
    table_method_list.table_method, 
    count(*) 
      FILTER (
        -- WHERE output_label_label_set.label = gt_label_label_set.label 
        -- AND output_label_label_set.parent_label = gt_label_label_set.parent_label
        WHERE is_reconcilable(output_label_label_set.label, gt_label_label_set.label)
        AND is_reconcilable (output_label_label_set.parent_label, gt_label_label_set.parent_label)
        AND output_label_label_set.left_col = gt_label_label_set.left_col
        AND output_label_label_set.top_row = gt_label_label_set.top_row) 
      AS label_label_true_pos
  FROM table_method_list
    FULL JOIN output_label_label_set
      ON table_method_list.table_name = output_label_label_set.table_name
      AND table_method_list.table_method = output_label_label_set.table_method
    FULL JOIN gt_label_label_set 
      ON table_method_list.table_name = gt_label_label_set.table_name
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW label_label_true_positives OWNER TO table_model;

CREATE OR REPLACE VIEW label_label_confusion AS
WITH data AS (
SELECT 
  table_method_list.table_method,
  table_method_list.table_name,
  gt_label_label_counts.gt_label_labels,
  output_label_label_counts.output_label_labels,
  label_label_true_positives.label_label_true_pos AS ll_true_pos,
  output_label_label_counts.output_label_labels - label_label_true_positives.label_label_true_pos AS ll_false_pos,
  gt_label_label_counts.gt_label_labels - label_label_true_positives.label_label_true_pos AS ll_false_neg,
  CASE 
    -- Avoid divide by zero error if no output_label_labels
    WHEN output_label_label_counts.output_label_labels=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (label_label_true_positives.label_label_true_pos::numeric/output_label_label_counts.output_label_labels)::numeric(4,3)
  END AS ll_precision,
  CASE 
    -- Avoid divide by zero error if no gt_label_labels
    WHEN gt_label_label_counts.gt_label_labels=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (label_label_true_positives.label_label_true_pos::numeric/gt_label_label_counts.gt_label_labels)::numeric(4,3)
  END AS ll_recall
FROM table_method_list
  JOIN output_label_label_counts
    ON table_method_list.table_name = output_label_label_counts.table_name
    AND table_method_list.table_method = output_label_label_counts.table_method
  JOIN gt_label_label_counts
    ON table_method_list.table_name = gt_label_label_counts.table_name
    AND table_method_list.table_method = gt_label_label_counts.table_method
  JOIN label_label_true_positives
    ON table_method_list.table_name = label_label_true_positives.table_name
    AND table_method_list.table_method = label_label_true_positives.table_method
ORDER BY table_method_list.table_method, table_method_list.table_name)
SELECT 
  -- Select all rows from subquery and calculate f-measure based on precision and recall
  *,
  CASE 
    -- Avoid divide by zero error if no output_entry_labels
    WHEN ll_precision+ll_recall=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (2*ll_precision*ll_recall/(ll_precision+ll_recall))::numeric(4,3)
  END AS ll_f_measure
FROM data;

ALTER VIEW label_label_confusion OWNER TO table_model;



-- ENTRY_LABEL_CONFUSION - views to display confusion matrix for set of entry-label pairs

\echo Create entry_label_confusion view (and the views that are used to build it)

-- One row per table and per method being compared
-- Count is zero if no entry-label pairs exist for given table
CREATE OR REPLACE VIEW gt_entry_label_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) filter( where gt_entry_label_set.table_name is not null) AS gt_entry_labels
  FROM table_method_list   -- use table_method_list as driving table
    LEFT JOIN gt_entry_label_set -- ensures one row per table and per method
      ON table_method_list.table_name = gt_entry_label_set.table_name
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW gt_entry_label_counts OWNER TO table_model;

-- One row per table and per method being compared. 
-- Count is zero if no entry-label pairs exist for given tbale nd method
CREATE OR REPLACE VIEW output_entry_label_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) filter( where output_entry_label_set.table_name is not null) AS output_entry_labels
  FROM table_method_list       -- use table_method_list as driving table
    LEFT JOIN output_entry_label_set -- ensures one row per table and per method
      ON table_method_list.table_name = output_entry_label_set.table_name
      AND table_method_list.table_method = output_entry_label_set.table_method
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW output_entry_label_counts OWNER TO table_model;

-- Intersection of ground truth and output per table and per method
CREATE OR REPLACE VIEW entry_label_true_positives AS
  SELECT
    table_method_list.table_name, 
    table_method_list.table_method, 
    count(*) 
      FILTER (
        -- NB MAY WANT TO ADD MATCH ON left_col AND top_row
        -- WHERE output_entry_label_set.label = gt_entry_label_set.label 
        -- AND output_entry_label_set.entry = gt_entry_label_set.entry
        WHERE is_reconcilable(output_entry_label_set.label, gt_entry_label_set.label)
        AND is_reconcilable(output_entry_label_set.entry, gt_entry_label_set.entry)
        AND output_entry_label_set.left_col = gt_entry_label_set.left_col
        AND output_entry_label_set.top_row = gt_entry_label_set.top_row)  
      AS entry_label_true_pos
  FROM table_method_list
    FULL JOIN output_entry_label_set
      ON table_method_list.table_name = output_entry_label_set.table_name
      AND table_method_list.table_method = output_entry_label_set.table_method
    FULL JOIN gt_entry_label_set 
      ON table_method_list.table_name = gt_entry_label_set.table_name
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW entry_label_true_positives OWNER TO table_model;

CREATE OR REPLACE VIEW entry_label_confusion AS
WITH data AS (
SELECT 
  table_method_list.table_method,
  table_method_list.table_name,
  gt_entry_label_counts.gt_entry_labels,
  output_entry_label_counts.output_entry_labels,
  entry_label_true_positives.entry_label_true_pos AS el_true_pos,
  output_entry_label_counts.output_entry_labels - entry_label_true_positives.entry_label_true_pos AS el_false_pos,
  gt_entry_label_counts.gt_entry_labels - entry_label_true_positives.entry_label_true_pos AS el_false_neg,
  CASE 
    -- Avoid divide by zero error if no output_entry_labels
    WHEN output_entry_label_counts.output_entry_labels=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (entry_label_true_positives.entry_label_true_pos::numeric/output_entry_label_counts.output_entry_labels)::numeric(4,3)
  END AS el_precision,
  CASE 
    -- Avoid divide by zero error if no gt_entry_labels
    WHEN gt_entry_label_counts.gt_entry_labels=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (entry_label_true_positives.entry_label_true_pos::numeric/gt_entry_label_counts.gt_entry_labels)::numeric(4,3)
  END AS el_recall
FROM table_method_list
  JOIN output_entry_label_counts
    ON table_method_list.table_name = output_entry_label_counts.table_name
    AND table_method_list.table_method = output_entry_label_counts.table_method
  JOIN gt_entry_label_counts
    ON table_method_list.table_name = gt_entry_label_counts.table_name
    AND table_method_list.table_method = gt_entry_label_counts.table_method
  JOIN entry_label_true_positives
    ON table_method_list.table_name = entry_label_true_positives.table_name
    AND table_method_list.table_method = entry_label_true_positives.table_method
ORDER BY table_method_list.table_method, table_method_list.table_name)
SELECT 
  -- Select all rows from subquery and calculate f-measure based on precision and recall
  *,
  CASE 
    -- Avoid divide by zero error if no output_entry_labels
    WHEN el_precision+el_recall=0 THEN 0.000
    -- Cast to numeric and round to 3 decimal places
    ELSE (2*el_precision*el_recall/(el_precision+el_recall))::numeric(4,3)
  END AS el_f_measure
FROM data;

ALTER VIEW entry_label_confusion OWNER TO table_model;

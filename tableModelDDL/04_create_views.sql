
/* ------------------------------------------------------------------------------------------------------------ */
/*          Create views to support mapping Ground Truth and Output to the (TabbyXL-based) table model          */
/* ------------------------------------------------------------------------------------------------------------ */

-- 1. Create tabby_cell_view

\echo Create view tabby_cell_view
-- Uses table_start to convert cell addresses to physical location in input file

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

-- 2. Create tabby_entry_view

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

-- 3. Create tabby_label_view

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

-- 4. Create tabby_entry_label_view

\echo Create view tabby_entry_label_view

-- Based on entry_label, with additional information from table_cell

-- WHAT HAPPENED TO THE ENTRIES IN CATEGORY ColumnHeading ?? -- FIX THIS !!

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

/* ------------------------------------------------------------------------------------------------------------ */
/* Create functions and views to support evaluation (comparison of output against ground truth for each method) */
/* ------------------------------------------------------------------------------------------------------------ */

-- 1. Create function to compare two values

\echo Create function is_reconcilable()
-- Boolean function that determines whether or not two given values match

CREATE OR REPLACE FUNCTION is_reconcilable(val1 text, val2 text) RETURNS boolean
    IMMUTABLE
    RETURNS NULL ON NULL INPUT
    AS
    $BODY$
    BEGIN
      --  Replace any non-ascii characters in each value with a space:
      val1 = regexp_replace(val1,'[^[:ascii:]]',' ','g');
      val2 = regexp_replace(val2,'[^[:ascii:]]',' ','g');
      --  Remove leading spaces from each vaue:
      val1 = ltrim(val1);
      val2 = ltrim(val2);
      -- compare as numeric if the following rules are obeyed:
      --   1. may or may not start with a minus sign
      --   2. remaining string contains repetitions of: one or more characters 0-9 followed by 0 or one comma, full stop or space
      IF val1 SIMILAR TO '-?([0-9]+[,. ]?)+' THEN
        -- compare as numeric
        -- strip the comma, full stop and space characters:
        val1 = regexp_replace(val1,'[,. ]','','gi');
        val2 = regexp_replace(val2,'[,. ]','','gi');
        -- trim any trailing zeros via rtrim(string,'0')
        val1 = rtrim(val1,'0');
        val2 = rtrim(val2,'0');
        -- this could result in false positives - 6430 would match 643 - but it is unlikely that we would compare two such numbers in the tests
        RETURN val1 = val2;
      ELSE
        -- compare as text using case-insensitive comparison:
        RETURN lower(val1) = lower(val2);
      END IF;
    END;    
    $BODY$
    LANGUAGE plpgsql;

-- 2. Create view that lists each ground truth table with the associated output table for each method

\echo Create tables_to_compare view
-- Returns one row per table and per method that contains the ground truth table_id and associated output table_id 

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

-- 3 Create views that return the 'set of instances' 
--     i.e. the set of entries, set of labels, set of entry-label pairs or set of label-label pairs
--     if a given set is empty for a given table, the view will return no rows for that table

\echo Create gt_label_set view
-- for each table, return the "set of labels" from the ground truth

CREATE OR REPLACE VIEW gt_label_set AS
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  table_cell.cell_id,
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
WITH hypoparsr_base_labels AS (
    -- list of labels in hypoparsr output with no n suffix (where n is one or more numeric characters)
    SELECT 
    source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS base_label_table_name, 
    table_cell.cell_content AS base_label
    FROM source_table 
    JOIN table_cell
        ON source_table.table_id = table_cell.table_id
    JOIN label
        ON label.label_cell_id = table_cell.cell_id
    WHERE   source_table.table_method='hypoparsr'
    AND     table_cell.cell_content = regexp_replace(table_cell.cell_content,'[0-9]+$','') 
    AND NOT source_table.table_is_gt
    )
SELECT 
  source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number AS table_name, 
  source_table.table_method,
  table_cell.cell_id,
  table_cell.left_col, 
  table_cell.top_row, 
  label.category_name,
  CASE 
    -- for hypoparsr only: if a corresponding label without a suffix exists, return the label with the suffix removed
    WHEN (regexp_replace(table_cell.cell_content,'[0-9]+$','')  IN (SELECT base_label from hypoparsr_base_labels WHERE base_label_table_name=source_table.file_name||'_'||source_table.sheet_number||'_'||source_table.table_number)
    AND table_method = 'hypoparsr')
    THEN regexp_replace(table_cell.cell_content,'[0-9]+$','')  
    -- otherwise return the unchanged label value
    ELSE table_cell.cell_content
  END AS label
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
  table_cell.cell_id,
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
  table_cell.cell_id,
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
  entry_table_cell.cell_id entry_cell_id,
  entry_table_cell.left_col, 
  entry_table_cell.top_row, 
  entry_table_cell.cell_content AS entry, 
  label_table_cell.cell_id label_cell_id,
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
  entry_table_cell.cell_id entry_cell_id,
  entry_table_cell.left_col, 
  entry_table_cell.top_row, 
  label_table_cell.cell_id label_cell_id,
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
  label_table_cell.cell_id label_cell_id,
  label_table_cell.left_col, 
  label_table_cell.top_row, 
  label_table_cell.cell_content AS label, 
  parent_label_table_cell.cell_id parent_label_cell_id,
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
  label_table_cell.cell_id label_cell_id,
  label_table_cell.left_col, 
  label_table_cell.top_row, 
  label_table_cell.cell_content AS label, 
  parent_label_table_cell.cell_id parent_label_cell_id,
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

-- 4. Create view containing list of tables and methods to be compared 

\echo Create table_method_list view
-- return one row per table and per method found in source_table
-- should probably populate this directly during processing of the input files

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

-- 5 Create views that calculate and display the confusion matrix
--     views are based on the gt_<instance>_set and output_<instance>_set views

-- 5.1 entry_confusion - views to display confusion matrix for set of entries

\echo Create gt_entry_counts view
-- One row per table. Count is zero if no entries exist for given table

CREATE OR REPLACE VIEW gt_entry_counts AS 
  WITH table_list AS (SELECT distinct table_name FROM table_method_list)
  SELECT 
    table_list.table_name,
    count(*) FILTER( WHERE gt_entry_set.table_name is not null) AS gt_entries
  FROM table_list
    LEFT JOIN gt_entry_set -- ensures one row per table
      ON table_list.table_name = gt_entry_set.table_name
  GROUP BY table_list.table_name;

ALTER VIEW gt_entry_counts OWNER TO table_model;

\echo Create output_entry_counts view
-- One row per table and per method being compared. Count is zero if no entries exist for given table and method

CREATE OR REPLACE VIEW output_entry_counts AS 
  SELECT 
    table_method_list.table_name,
    table_method_list.table_method,
    count(*) FILTER( WHERE output_entry_set.table_name is not null) AS output_entries
  FROM table_method_list       -- use table_method_list as driving table
    LEFT JOIN output_entry_set -- ensures one row per table and per method
      ON  table_method_list.table_name = output_entry_set.table_name
      AND table_method_list.table_method = output_entry_set.table_method
  GROUP BY table_method_list.table_name, table_method_list.table_method;

ALTER VIEW output_entry_counts OWNER TO table_model;


\echo Create entry_true_positives view
-- Number of matches between ground truth and output per table and per method

CREATE OR REPLACE VIEW entry_true_positives AS
  SELECT
    table_method_list.table_name, 
    table_method_list.table_method,
    count(*) FILTER (
              -- only count rows where the row offset between GT and output is consistent
              WHERE row_offset = coalesce(prev_row_offset, row_offset) 
              AND row_offset = coalesce(next_row_offset, row_offset))
        AS entry_true_pos
  FROM (
  SELECT
    output_entry_set.table_name,
    output_entry_set.table_method,  
    gt_entry_set.top_row AS gt_top_row,
    gt_entry_set.left_col AS gt_left_col,
    output_entry_set.top_row AS out_top_row,
    output_entry_set.left_col AS out_left_col,
    lag(gt_entry_set.top_row - output_entry_set.top_row) over win_r AS prev_row_offset,
    gt_entry_set.top_row - output_entry_set.top_row AS row_offset,
    lead(gt_entry_set.top_row - output_entry_set.top_row) over win_r AS next_row_offset,
    gt_entry_set.entry gt_entry,
    output_entry_set.entry out_entry
    FROM gt_entry_set 
      JOIN output_entry_set 
      -- join rows on entry value and table_name - will get a row per table, per method and per entry value
      ON is_reconcilable(gt_entry_set.entry, output_entry_set.entry)
      AND gt_entry_set.table_name=output_entry_set.table_name
  WINDOW  win_r AS (
            -- window for comparing row offsets
            PARTITION BY output_entry_set.table_method,
                         output_entry_set.table_name
            ORDER BY     gt_entry_set.top_row, 
                         gt_entry_set.left_col)
  ) matching_entry_values
  RIGHT JOIN table_method_list
    ON matching_entry_values.table_name = table_method_list.table_name
    AND matching_entry_values.table_method = table_method_list.table_method
  GROUP BY table_method_list.table_method, table_method_list.table_name
  ORDER BY table_method_list.table_method, table_method_list.table_name;

ALTER VIEW entry_true_positives OWNER TO table_model;


\echo Create entry_confusion view

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
--    AND table_method_list.table_method = gt_entry_counts.table_method
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

-- 5.2 label_confusion - views to display confusion matrix for set of labels


\echo Create gt_label_counts view
-- One row per table. Count is zero if no labels exist for given table

CREATE OR REPLACE VIEW gt_label_counts AS 
  WITH table_list AS (SELECT distinct table_name FROM table_method_list)
  SELECT
    table_list.table_name,
    count(*) FILTER( WHERE gt_label_set.table_name is not null) AS gt_labels
  FROM table_list
    LEFT JOIN gt_label_set -- ensures one row per table
      ON table_list.table_name = gt_label_set.table_name
  GROUP BY table_list.table_name;

ALTER VIEW gt_label_counts OWNER TO table_model;


\echo Create output_label_counts view
-- One row per table and per method being compared. Count is zero if no labels exist for given table and method

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


\echo Create label_true_positives view
-- Number of matches between ground truth and output per table and per method

CREATE OR REPLACE VIEW label_true_positives AS
  SELECT
    table_method_list.table_name, 
    table_method_list.table_method,
    count(*) AS label_true_pos
  FROM (  
  -- find potentiall matching labels by comparing gt_label_set against output_label_set
  -- matching on table_name, label value and column ID (row ID may be offset - that's fine)
  SELECT
    output_label_set.table_name,
    output_label_set.table_method,  
    gt_label_set.top_row AS gt_top_row,
    gt_label_set.left_col AS gt_left_col,
    output_label_set.top_row AS out_top_row,
    output_label_set.left_col AS out_left_col,
    -- lag(gt_label_set.top_row - output_label_set.top_row) over win_r AS prev_row_offset,
    gt_label_set.top_row - output_label_set.top_row AS row_offset,
    -- lead(gt_label_set.top_row - output_label_set.top_row) over win_r AS next_row_offset,
    gt_label_set.label gt_label,
    output_label_set.label out_label
    FROM gt_label_set 
      JOIN output_label_set 
      -- join rows on label value and table_name - will get a row per table, per method and per label value
      ON is_reconcilable(gt_label_set.label, output_label_set.label)
      AND gt_label_set.table_name=output_label_set.table_name
      AND gt_label_set.left_col=output_label_set.left_col
  WINDOW  win_r AS (
            -- window for comparing row offsets per table and per method
            PARTITION BY output_label_set.table_method,
                         output_label_set.table_name
            ORDER BY     gt_label_set.top_row, 
                         gt_label_set.left_col)
  ) matching_label_values
  RIGHT JOIN table_method_list
    ON matching_label_values.table_name = table_method_list.table_name
    AND matching_label_values.table_method = table_method_list.table_method
  GROUP BY table_method_list.table_method, table_method_list.table_name
  ORDER BY table_method_list.table_method, table_method_list.table_name;

ALTER VIEW label_true_positives OWNER TO table_model;                        

\echo Create label_confusion view

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

-- 5.3 label_label_confusion - views to display confusion matrix for set of labels

\echo Create gt_label_label_counts view
-- One row per table. Count is zero if no label-label pairs exist for given table

CREATE OR REPLACE VIEW gt_label_label_counts AS 
  WITH table_list AS (SELECT distinct table_name FROM table_method_list)
  SELECT 
    table_list.table_name,
    count(*) filter( where gt_label_label_set.table_name is not null) AS gt_label_labels
  FROM table_list
    LEFT JOIN gt_label_label_set -- ensures one row per table
      ON table_list.table_name = gt_label_label_set.table_name
  GROUP BY table_list.table_name;

ALTER VIEW gt_label_label_counts OWNER TO table_model;


\echo Create output_label_label_counts view
-- One row per table and per method being compared. Count is zero if no label label pairs exist for given table and method

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
--    AND table_method_list.table_method = gt_label_label_counts.table_method
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


-- 5.4 entry_label_confusion - views to display confusion matrix for set of entry-label pairs

\echo Create gt_entry_label_counts view
-- One row per table. Count is zero if no entry label pairs exist for given table

CREATE OR REPLACE VIEW gt_entry_label_counts AS 
  WITH table_list AS (SELECT distinct table_name FROM table_method_list)
  SELECT 
    table_list.table_name,
    count(*) filter( where gt_entry_label_set.table_name is not null) AS gt_entry_labels
  FROM table_list   -- use table_method_list as driving table
    LEFT JOIN gt_entry_label_set -- ensures one row per table and per method
      ON table_list.table_name = gt_entry_label_set.table_name
  GROUP BY table_list.table_name;

ALTER VIEW gt_entry_label_counts OWNER TO table_model;


\echo Create output_entry_label_counts view
-- One row per table and per method being compared. Count is zero if no entry label pairs exist for given table and method

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
--    AND table_method_list.table_method = gt_entry_label_counts.table_method
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

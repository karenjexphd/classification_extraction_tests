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

-- for each table and for each method, returns the following:
-- ground truth table_id and associated output table_id 
-- match is based on file_name, sheet_number and table_number

CREATE OR REPLACE VIEW tables_to_compare
AS
WITH gt_tables AS (
    SELECT table_id, 
    file_name||'_'||sheet_number||'_'||table_number AS table_name 
    FROM source_table 
    WHERE table_is_gt),
    output_tables AS (
    SELECT table_id, 
    table_method,
    file_name||'_'||sheet_number||'_'||table_number AS table_name 
    FROM source_table 
    WHERE NOT table_is_gt)
SELECT gt.table_id AS gt_table_id,
       ot.table_id AS output_table_id,
       gt.table_name,
       ot.table_method 
FROM gt_tables gt
LEFT JOIN output_tables ot -- RETURN ALL GT TABLES WHETHER OR NOT AN OUTPUT TABLE EXISTS
ON gt.table_name = ot.table_name
ORDER BY gt.table_id;

ALTER VIEW tables_to_compare OWNER TO table_model;

-- 4.2 CREATE VIEWS THAT RETURN THE 'SET OF INSTANCES'
--     S for ground truth
--     R for extracted tables
--     views are based on tables_to_compare view

-- NOTE THESE CURRENTLY SOMETIMES RETURN NO ROWS
-- NEED TO WORK OUT HOW TO CREATE CONFUSION MATRIX VIEW IN THIS CASE

\echo Create gt_label_set and output_label_set views

-- return the "set of labels"

CREATE OR REPLACE VIEW gt_label_set 
AS
SELECT t2c.table_name, tc.left_col, tc.top_row, category_name, cell_content as label
FROM tables_to_compare t2c 
JOIN table_cell tc
ON t2c.gt_table_id=tc.table_id
JOIN label l 
ON l.label_cell_id=tc.cell_id;

ALTER VIEW gt_label_set OWNER TO table_model;

CREATE OR REPLACE VIEW output_label_set
AS
SELECT t2c.table_name, t2c.table_method, tc.left_col, tc.top_row, category_name, cell_content as label
FROM tables_to_compare t2c 
JOIN table_cell tc
ON t2c.output_table_id=tc.table_id
JOIN label l 
ON l.label_cell_id=tc.cell_id;

ALTER VIEW output_label_set OWNER TO table_model;

\echo Create gt_entry_set and output_entry_set views

-- return the "set of entries"

CREATE OR REPLACE VIEW gt_entry_set
AS
SELECT t2c.table_name, tc.left_col, tc.top_row, cell_content as entry 
FROM tables_to_compare t2c
JOIN table_cell tc
ON t2c.gt_table_id=tc.table_id
JOIN entry e
ON e.entry_cell_id=tc.cell_id;

ALTER VIEW gt_entry_set OWNER TO table_model;

CREATE OR REPLACE VIEW output_entry_set
AS
SELECT t2c.table_name, t2c.table_method, tc.left_col, tc.top_row, cell_content as entry
FROM tables_to_compare t2c
JOIN table_cell tc
ON t2c.output_table_id=tc.table_id
JOIN entry e
ON e.entry_cell_id=tc.cell_id;

ALTER VIEW output_entry_set OWNER TO table_model;

\echo Create gt_entry_label_set and output_entry_label_set views

-- return the "set of entry-label pairs"

CREATE OR REPLACE VIEW gt_entry_label_set
AS
SELECT t2c.table_name, 
       etc.left_col, etc.top_row, etc.cell_content as entry, 
       ltc.cell_content as label
FROM tables_to_compare t2c
JOIN table_cell etc
ON t2c.gt_table_id=etc.table_id
JOIN table_cell ltc
ON t2c.gt_table_id=ltc.table_id
JOIN entry_label el
ON el.entry_cell_id=etc.cell_id
AND el.label_cell_id=ltc.cell_id;

ALTER VIEW gt_entry_label_set OWNER TO table_model;

CREATE OR REPLACE VIEW output_entry_label_set
AS
SELECT t2c.table_name, t2c.table_method,
       etc.left_col, etc.top_row, etc.cell_content as entry, 
       ltc.cell_content as label
FROM tables_to_compare t2c
JOIN table_cell etc
ON t2c.output_table_id=etc.table_id
JOIN table_cell ltc
ON t2c.output_table_id=ltc.table_id
JOIN entry_label el
ON el.entry_cell_id=etc.cell_id
AND el.label_cell_id=ltc.cell_id;

ALTER VIEW output_entry_label_set OWNER TO table_model;

\echo Create gt_label_label_set and output_label_label_set views

-- return the "set of label-label pairs"

CREATE OR REPLACE VIEW gt_label_label_set
AS
SELECT t2c.table_name, 
       cltc.left_col, cltc.top_row, cltc.cell_content as label, 
       pltc.cell_content as parent_label
FROM tables_to_compare t2c
JOIN table_cell cltc
ON t2c.gt_table_id=cltc.table_id
JOIN table_cell pltc
ON t2c.gt_table_id=pltc.table_id
JOIN label l
ON l.label_cell_id=cltc.cell_id
AND l.parent_label_cell_id=pltc.cell_id;

ALTER VIEW gt_label_label_set OWNER TO table_model;

CREATE OR REPLACE VIEW output_label_label_set
AS
SELECT t2c.table_name, t2c.table_method,
       cltc.left_col, cltc.top_row, cltc.cell_content as label, 
       pltc.cell_content as parent_label
FROM tables_to_compare t2c
JOIN table_cell cltc
ON t2c.output_table_id=cltc.table_id
JOIN table_cell pltc 
ON t2c.output_table_id=pltc.table_id
JOIN label l
ON l.label_cell_id=cltc.cell_id
AND l.parent_label_cell_id=pltc.cell_id;

ALTER VIEW output_label_label_set OWNER TO table_model;


-- 4.3 CREATE VIEWS THAT RETURN THE CONFUSION MATRIX
--     S for ground truth
--     R for extracted tables
--     views are based on the gt_<instance>_set and output_<instance>_set views

-- NOTE THAT WHERE A SET IS EMPTY FOR A GIVEN TABLE (OR FOR ALL TABLES)
-- THE CONFUSION MATRIX SHOULD STILL CONTAIN A ROW FOR THAT TABLE
-- THE CORRESPONDING COUNTS SHOULD BE DISPLAYED AS ZERO

/echo Create entry_confusion view
-- Confusion matrix for the set of entries per table and per model

CREATE OR REPLACE VIEW entry_confusion AS
WITH gtec AS
(select table_name, count(*) AS gt_entry_count
FROM gt_entry_set
GROUP BY table_name),
oec AS
(select table_name, table_method, count(*) AS output_entry_count
FROM output_entry_set
GROUP BY table_name, table_method),
etp AS
(SELECT oe.table_name, oe.table_method, count(*) AS entry_true_pos
FROM gt_entry_set gte
JOIN output_entry_set oe
ON gte.table_name=oe.table_name
AND gte.left_col=oe.left_col
AND gte.top_row=oe.top_row
AND gte.entry=oe.entry
group by oe.table_name, oe.table_method)
SELECT t2c.table_name,
       t2c.table_method as method_name, 
       COALESCE(gtec.gt_entry_count,0) AS gt_total_entries,
       COALESCE(oec.output_entry_count,0) AS output_total_entries,
       COALESCE(oec.output_entry_count,0)-COALESCE(etp.entry_true_pos,0) AS entry_false_pos, 
       COALESCE(gtec.gt_entry_count,0)-COALESCE(etp.entry_true_pos,0) AS entry_false_neg, 
       COALESCE(etp.entry_true_pos,0) AS entry_true_pos
FROM tables_to_compare t2c	-- driving table for list of table_names
LEFT JOIN gtec on t2c.table_name=gtec.table_name
LEFT JOIN oec ON t2c.table_name=oec.table_name AND t2c.table_method=oec.table_method
LEFT JOIN etp ON t2c.table_name=etp.table_name AND t2c.table_method=etp.table_method
ORDER BY table_name, method_name;

ALTER VIEW entry_confusion OWNER TO table_model;

/echo Create label_confusion view
-- Confusion matrix for the set of labels per table and per model

CREATE OR REPLACE VIEW label_confusion AS
WITH gtlc AS
(select table_name, count(*) AS gt_label_count
FROM gt_label_set
GROUP BY table_name),
olc AS
(select table_name, table_method, count(*) AS output_label_count
FROM output_label_set
GROUP BY table_name, table_method),
ltp AS
(SELECT ol.table_name, ol.table_method, count(*) AS label_true_pos
FROM gt_label_set gtl
JOIN output_label_set ol
ON gtl.table_name=ol.table_name
AND gtl.left_col=ol.left_col
AND gtl.top_row=ol.top_row
AND gtl.label=ol.label
--AND gtl.category_name=ol.category_name
group by ol.table_name, ol.table_method)
SELECT t2c.table_name,
       t2c.table_method as method_name, 
       COALESCE(gtlc.gt_label_count,0) AS gt_total_labels,
       COALESCE(olc.output_label_count,0) AS output_total_labels,
       COALESCE(olc.output_label_count,0)-COALESCE(ltp.label_true_pos,0) AS label_false_pos, 
       COALESCE(gtlc.gt_label_count,0)-COALESCE(ltp.label_true_pos,0) AS label_false_neg, 
       COALESCE(ltp.label_true_pos,0) AS label_true_pos
FROM tables_to_compare t2c	-- driving table for list of table_names
LEFT JOIN gtlc ON t2c.table_name=gtlc.table_name
LEFT JOIN olc ON t2c.table_name=olc.table_name AND t2c.table_method=olc.table_method
LEFT JOIN ltp ON t2c.table_name=ltp.table_name AND t2c.table_method=ltp.table_method
ORDER BY table_name, method_name;

ALTER VIEW label_confusion OWNER TO table_model;

/echo Create entry_label_confusion view
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

/echo Create label_label_confusion view
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

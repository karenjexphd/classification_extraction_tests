\echo Create procedure create_tabby_canonical_table to generate the Tabby canonical table

-- The procedure will generate the table tabby_canonical_table_<in_table_id>

CREATE OR REPLACE PROCEDURE create_tabby_canonical_table (in_table_id NUMERIC)
AS $$
DECLARE rec RECORD;
DECLARE str text;
BEGIN
str := '"Entry Value" text,';
   -- looping to get column heading string (e.g. "Entry Value" text, "label1" text, "label2" text)
   FOR rec IN SELECT DISTINCT category
        FROM tabby_entry_label_view
        WHERE table_id=in_table_id
        ORDER BY category
    LOOP
      str :=  str || '"' || rec.category || '" text' ||',';
    END LOOP;
    str:= substring(str, 0, length(str));

    EXECUTE 'CREATE EXTENSION IF NOT EXISTS tablefunc;
    DROP TABLE IF EXISTS tabby_canonical_table_'||in_table_id||';
    CREATE TABLE tabby_canonical_table_'||in_table_id||' AS
    SELECT *
    FROM crosstab(''SELECT entry_value, category, label_display_value FROM tabby_entry_label_view WHERE table_id='|| in_table_id ||' ORDER BY 1'',
                  ''SELECT DISTINCT category FROM tabby_entry_label_view WHERE table_id='|| in_table_id ||' ORDER BY 1'')
         AS final_result ('|| str ||')';
    EXECUTE 'ALTER TABLE tabby_canonical_table_'|| in_table_id ||' OWNER TO table_model';
END;
$$ LANGUAGE plpgsql;

ALTER PROCEDURE create_tabby_canonical_table OWNER TO table_model;
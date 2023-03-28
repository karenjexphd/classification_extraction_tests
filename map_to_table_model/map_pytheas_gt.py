import sys 
import psycopg2
import json

# Goal: extract information from given Pytheas ground truth file and map it to table model

# Tables to populate:
#    source_table  DONE
#    table_cell    
#    category      
#    entry         
#    label         
#    entry_label   
# Interim tables:
#    entry_temp
#    label_temp
#    entry_label_temp
# Goal:
#    canonical_table_view displays full & correct information for the processed table

# load JSON from GT file

input_file="/home/karen/workspaces/classification_extraction_tests/test_files/tabby_small_file/gt/pytheas/smpl.json"

# input_file has been hardcoded for testing. Will be provided as input parameter
# input_file = str(sys.argv[1])       # Pytheas format GT file (<basename>.json)

# filename (will be identified from the input_file name)
filename='smpl'

with open(input_file) as f:
  annotations = json.load(f)

annotated = annotations['tables']

# Connect to table_model database

tm_conn = psycopg2.connect(
    host="p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com",
    database="table_model",
    user="postgres")

cur = tm_conn.cursor()
cur.execute('SET SEARCH_PATH=table_model')

# Create temp tables (temporarily created permanent tables in DB to allow them to be viewed from other sessions)

#cur.execute('CREATE TEMPORARY TABLE entry_temp (entry_value text, entry_provenance text, entry_provenance_col text, entry_provenance_row integer, entry_labels text)')
#cur.execute('CREATE TEMPORARY TABLE label_temp (label_value text, label_provenance text, label_provenance_col text, label_provenance_row integer, label_parent text, label_category text)')
#cur.execute('CREATE TEMPORARY TABLE entry_label_temp (entry_provenance text, label_provenance text)')

# process tables

for i in range(len(annotated)):
    table=annotated[i]
    tablenum=table['table_counter']
    tablestart=table['top_boundary']
    tableend=table['bottom_boundary']

    # Insert into source_table (sheetnum will always be zero for Pytheas)
    insert_stmt="INSERT INTO source_table (table_start, table_end, file_name, sheet_number, table_number) \
                 VALUES ('"+str(tablestart)+"', '"+str(tableend)+"', '"+filename+"', 0, "+str(tablenum)+")"
    cur.execute(insert_stmt)

    # get table_id
    select_stmt="SELECT table_id FROM source_table \
                WHERE file_name='"+filename+"' AND sheet_number=0 AND table_number="+str(tablenum)
    cur.execute(select_stmt)
    table_id = cur.fetchone()[0]
    print("table_id: ",table_id)

    # Populate entry_temp temporary table
    #    Note: an entry in Pytheas is a row of the discovered table

    entries=table['data_indexes']

    for entry in entries:
        insert_et="INSERT INTO entry_temp (entry_provenance_row) VALUES ("+str(entry)+")"
        cur.execute(insert_et)

    # Populate table_cell based on entry_temp and source_table contents
    #    Note: a table_cell in Pytheas is an entire row
    #          top_row = bottom_row = entry_provenance_row-table_start

    insert_stmt="INSERT INTO table_cell \
                (table_id, top_row, bottom_row, cell_annotation) \
                SELECT  "+str(table_id)+", \
                        entry_provenance_row-"+str(tablestart)+", \
                        entry_provenance_row-"+str(tablestart)+", \
                        'DATA' \
                FROM entry_temp"
    cur.execute(insert_stmt)

    # Populate entry based on table_cell

    insert_stmt="INSERT INTO entry (entry_cell_id) \
                 SELECT cell_id FROM table_cell \
                 WHERE table_id="+str(table_id)+" AND cell_annotation='DATA'"
    cur.execute(insert_stmt)

    # Populate label_temp temporary table
    #    Note: a label in Pytheas is a heading row of the discovered table

    label_rows=table['header']

    for label_row in label_rows:
        insert_lt="INSERT INTO label_temp (label_provenance_row) VALUES ("+str(label_row)+")"
        cur.execute(insert_lt)

    # Populate table_cell based on label_temp contents

    insert_stmt="INSERT INTO table_cell \
                (table_id, top_row, bottom_row, cell_annotation) \
                SELECT  "+str(table_id)+", \
                        label_provenance_row-"+str(tablestart)+", \
                        label_provenance_row-"+str(tablestart)+", \
                        'HEADING' \
                FROM label_temp"
    cur.execute(insert_stmt)

    # Populate label based on table_cell

    insert_stmt="INSERT INTO label (label_cell_id) \
                 SELECT cell_id FROM table_cell \
                 WHERE table_id="+str(table_id)+" AND cell_annotation='HEADING'"
    cur.execute(insert_stmt)

    # Generate canonical_table_view and display contents

    # create_ctv="CALL create_canonical_table_view("+str(table_id)+")"
    # cur.execute(create_ctv)

    # select_ctv="SELECT * FROM canonical_table_view"
    # cur.execute(select_ctv)
    # canonical_table = cur.fetchall()
    # print(canonical_table)

    truncate_et="TRUNCATE TABLE entry_temp, label_temp, entry_label_temp"
    cur.execute(truncate_et)

# cur.execute('COMMIT;')

cur.close()

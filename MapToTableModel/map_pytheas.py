import sys 
import psycopg2
import json
import re

# Goals:
#   Extract tables from given Pytheas ground truth file
#   or discovered_tables from given Pytheas table output file 
#   and map the data to the table model

# 1. Process input parameters:

#   i. input_filepath       path to file to be processed
# input_filepath = str(sys.argv[1])  
# #   ii. input_filename       name of file to be processed (<basename>.json)
# input_filename = str(sys.argv[2])               
# #   iii. is_gt                TRUE if this is a file containing ground truth, FALSE if output 
# if str(sys.argv[3]) == 'TRUE':
#     is_gt=True
# else:
#     is_gt=False

input_filepath="/tmp/test_20_05_2023/pytheas"
input_filename="C10001.json"
is_gt=False

input_file = input_filepath+"/"+input_filename  # Fully qualified file

#    Note that a Pytheas ground truth file may contain multiple tables

# Get base filename based on input_file path and name
filename=input_filename.split('.json')[0]
#print("processing base filename: "+filename)


if is_gt:

  with open(input_file) as f:
    annotations = json.load(f)

  tables = annotations['tables']

else:
  # Processing a json file containing extracted tables
  # The json is not in the format expected by json.load() 
  # Replacements are necessary in order to obtain valid json that can be loaded
  # Want just the discovered_tables part, i.e. starting from first opening curly bracket

    json_in=''

    with open(input_file) as f:
        started=False
        for line in f:
            if (line.startswith('{')):
                started=True
            if started:
                json_in+=line

    # Replace ' in the middle of a double-quoted value with ''
    new_json = re.sub('(".+)\'(.+")','\g<1>\'\'\g<2>',json_in)

    # Replace all ' with "  
    new_json = re.sub('\'','"',new_json)

    # Now replace "" in the middle of a quoted value with '
    new_json = re.sub('(".+)""(.+")','\g<1>\'\g<2>',new_json)

    # Replace all <number>: with "<number>":
    new_json = re.sub('([0-9]+)(:)', '\"\g<1>\":', new_json) 

    # Remove newline in the middle of a value
    new_json = re.sub('\"\n\ +\"', '', new_json)
    #print(new_json)

    tables = json.loads(new_json) 

# 2. Create connection to table_model database with search_path set to table_model
#    (Need to parameterise this)

tm_conn = psycopg2.connect(
    host="p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com",
    database="table_model",
    user="postgres")

cur = tm_conn.cursor()
cur.execute('SET SEARCH_PATH=table_model')

# 3. Process tables

for i in range(len(tables)):
    table=tables[i]
    tablenum=table['table_counter']
    tablestart=table['top_boundary']
    tableend=table['bottom_boundary']

    # Insert into source_table (sheetnum will always be zero for Pytheas)
    insert_stmt="INSERT INTO source_table (table_is_gt, table_start_row, table_end_row, file_name, sheet_number, table_number) \
                 VALUES ("+is_gt+",'"+str(tablestart)+"', '"+str(tableend)+"', '"+filename+"', 0, "+str(tablenum)+")"
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
        print("Insert entry into entry_temp: "+str(entry))
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

    # Display contents of pytheas_canonical_table_view

    select_ctv="SELECT table_number, table_row, row_provenance, cell_annotation \
                FROM pytheas_canonical_table_view where table_id="+str(table_id)
    cur.execute(select_ctv)
    canonical_table = cur.fetchall()
    print(canonical_table)

    truncate_et="TRUNCATE TABLE entry_temp, label_temp, entry_label_temp"
    cur.execute(truncate_et)

cur.execute('COMMIT;')

cur.close()

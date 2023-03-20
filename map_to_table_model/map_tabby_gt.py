from openpyxl import load_workbook
import sys 
import psycopg2

# Goal: extract information from given Tabby ground truth file and map it to table model

# input_file has been hardcoded for testing. Will be provided as input parameter

input_file="/home/karen/workspaces/classification_extraction_tests/test_files/tabby_small_file/gt/tabby/smpl_0_0.xlsx"

#input_file = str(sys.argv[1])       # Tabby format GT file (.xlsx in same format as Tabby extracted tables file)

# filename, sheet number and table number have been hardcoded
# will need to be passed as input parameters or identified from the input_file name

filename='smpl'
sheetnum=0
tablenum=0

# table_start and table_end have been hardcoded
# will need to be passed as input parameters (will have been identified in another step from original input_file)

tablestart='A1'
tableend='H7'

# Connect to table_model database (want to separate out the connect info at some point)

tm_conn = psycopg2.connect(
    host="p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com",
    database="table_model",
    user="postgres")

cur = tm_conn.cursor()
cur.execute('SET SEARCH_PATH=table_model')

# Create temp tables (temporarily created permanent tables in DB to allow them to be viewed from other sessions)

# cur.execute('CREATE TEMPORARY TABLE entry_temp (entry_value text, entry_provenance text, entry_labels text)')
# cur.execute('CREATE TEMPORARY TABLE label_temp (label_value text, label_provenance text, label_parent text, label_category text)')

# Insert into source_table
# Need to consider how to proceed if this table has already been processed - do a delete (cascade)?

insert_stmt="INSERT INTO source_table (table_start, table_end, file_name, sheet_number, table_number) \
             VALUES ('"+tablestart+"', '"+tableend+"', '"+filename+"', "+str(sheetnum)+", "+str(tablenum)+")"
cur.execute(insert_stmt)

# get table_id

select_stmt="SELECT table_id FROM source_table \
             WHERE file_name='"+filename+"' AND sheet_number="+str(sheetnum)+" AND table_number="+str(tablenum)
cur.execute(select_stmt)
table_id = cur.fetchone()[0]
print(table_id)

# get start_col, start_row from table_start_view

select_stmt="SELECT start_col, start_row FROM table_start_view WHERE table_id="+str(table_id)
cur.execute(select_stmt)
row = cur.fetchone()
start_col = row[0]
start_row = row[1]
print(start_col, start_row)

# load the workbook and get data from the required sheets (ENTRIES and LABELS):

wb         = load_workbook(input_file)
ws_entries = wb['ENTRIES']
ws_labels  = wb['LABELS']

all_entries_rows = list(ws_entries.rows)
all_labels_rows = list(ws_labels.rows)

# Populate entry_temp temporary table from ENTRIES sheet

for row in all_entries_rows:
    entry_val  = str(row[0].value)                            # value in ENTRY column
    entry_prov = str(row[1].value)                            # value in PROVENANCE column
    entry_labels = str(row[2].value)                          # value in LABELS column
    if entry_prov != 'PROVENANCE':
        # insert values into entry_temp
        insert_stmt="INSERT INTO entry_temp (entry_value, entry_provenance, entry_labels) \
                     VALUES ('"+entry_val+"', '"+entry_prov+"', '"+entry_labels+"')"
        cur.execute(insert_stmt)

# prov_val=entry_prov.split('","')[1].split('")')[0]    # just the display value (between '","' and '")' )
# prov_num=int(''.join(filter(str.isdigit, prov_val)))  # just the numeric part

# Populate table_cell based on entry_temp and source_table contents
# Where does the right_col and bottom_row information come from? We don't have that in the GT
# Also don't have cell_datatype or cell_annotation (unless we can infer from entry or label status)

insert_stmt="INSERT INTO table_cell \
            (table_id, left_col, top_row, cell_content, cell_datatype) \
            SELECT  ("+str(table_id)+","+start_col+","+start_row+","++ \
            FROM entry_temp"
# cur.execute(insert_stmt)

# # Populate entry based on entry_temp, table_cell and source_table contents

# insert_stmt="INSERT INTO entry (entry_cell_id) \
#             SELECT  (...
# cur.execute(insert_stmt)

# Populate label_temp temporary table from LABELS sheet

for row in all_labels_rows:
    label_val  = str(row[0].value)                                 # value in LABEL column
    label_prov = str(row[1].value)                                 # value in PROVENANCE column
    label_par  = str(row[2].value)                                 # value in PARENT column
    label_cat  = str(row[3].value)                                 # value in CATEGORY column
    if label_prov != 'PROVENANCE':
        # insert values into label_temp
        insert_stmt="INSERT INTO label_temp (label_value, label_provenance, label_parent, label_category) \
                     VALUES ('"+label_val+"', '"+label_prov+"', '"+label_par+"', '"+label_cat+"')"
        cur.execute(insert_stmt)
        # prov_val=provenance.split('","')[1].split('")')[0]    # just the display value (between '","' and '")' )
        # prov_num=int(''.join(filter(str.isdigit, prov_val)))  # just the numeric part

# Display contents of label_temp
cur.execute('SELECT * FROM label_temp')
label_rows = cur.fetchall()
#print(label_rows)


#  source_table: Create a new record
#                table_start and table_end come from input file ($START and $END)
#                Need to make sure table_id is unique. 
#                Re-model to have file_name, sheet_number and table_numer (table_number is what we're currently using as table_id)
#                then automatically generated surrogate key table_id
#  table_cell: 
#  entry
#  category    <-- how to populate this?
#  label
#  entry_label


cur.execute('COMMIT;')
cur.close()

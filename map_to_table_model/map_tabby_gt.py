from openpyxl import load_workbook
import sys 
import psycopg2

# Goal: extract information from given Tabby ground truth file and map it to table model

# Tables to populate:
#    source_table  DONE
#    table_cell    DONE
#    category      DONE         -- Should category contain a table_id ?
#    entry         DONE
#    label         DONE (except parent info)
#    entry_label   DONE
# Interim tables:
#    entry_temp
#    label_temp
#    entry_label_temp
# Goal:
#    canonical_table_view displays full & correct information for the processed table

# input_file has been hardcoded for testing. Will be provided as input parameter

input_file="/home/karen/workspaces/classification_extraction_tests/test_files/tabby_small_file/gt/tabby/smpl_0_0.xlsx"

#input_file = str(sys.argv[1])       # Tabby format GT file (.xlsx in same format as Tabby extracted tables file)

# filename, sheet number (will be identified from the input_file name)

filename='smpl'
sheetnum=0
tablenum=0

# table_start and table_end (will have been identified in previous step from original input_file)

tablestart='A1'
tableend='H7'

tablestart_col=''.join(filter(str.isalpha, tablestart))        # alpha part
tablestart_row=int(''.join(filter(str.isdigit, tablestart)))   # numeric part

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

# Insert into source_table

    # What if table has already been processed - do a delete (cascade)? stop processing?

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

# Populate entry_temp and entry_label_temp temporary table from ENTRIES sheet

for row in all_entries_rows:
    entry_val  = str(row[0].value)                            # value in ENTRY column
    entry_prov_text = str(row[1].value)                       # value in PROVENANCE column
    entry_labels = str(row[2].value)                          # value in LABELS column
    if entry_prov_text != 'PROVENANCE':                       # ignore header row
        entry_prov=entry_prov_text.split('","')[1].split('")')[0]   # get display val between '","' and '")'
        entry_prov_col=''.join(filter(str.isalpha, entry_prov))        # alpha part
        entry_prov_row=int(''.join(filter(str.isdigit, entry_prov)))   # numeric part
        insert_et="INSERT INTO entry_temp (entry_value, entry_provenance, entry_provenance_col, entry_provenance_row, entry_labels) \
                     VALUES ('"+entry_val+"', '"+entry_prov+"', '"+entry_prov_col+"', "+str(entry_prov_row)+", '"+entry_labels+"')"
        cur.execute(insert_et)
        # split entry_labels (on comma) to get list of labels
        entry_label_list = entry_labels.split(',')
        for entry_label in entry_label_list:
            # get value found between square brackets as label_provenance
            label_prov=entry_label.split('[')[1].split(']')[0]
            insert_elt="INSERT INTO entry_label_temp (entry_provenance, label_provenance) \
                        VALUES ('"+entry_prov+"', '"+label_prov+"')"
            cur.execute(insert_elt)


# Populate table_cell based on entry_temp and source_table contents

    #   NB: we don't have right_col, bottom_row, cell_datatype info in the GT
    #       right_col and bottom_row are inserted as duplicates of left_col and top_row

    # left_col: ascii(entry_provenance_col)-ascii(tablestart_col)
    #           (only works with up to 26 cols - need additional logic for AA, AB etc)
    # top_row:  entry_provenance_row-tablestart_row

insert_stmt="INSERT INTO table_cell \
            (table_id, left_col, top_row, right_col, bottom_row, cell_content, cell_annotation) \
            SELECT  "+str(table_id)+", \
                    ascii(entry_provenance_col)-ascii('"+tablestart_col+"'), \
                    entry_provenance_row-"+str(tablestart_row)+", \
                    ascii(entry_provenance_col)-ascii('"+tablestart_col+"'), \
                    entry_provenance_row-"+str(tablestart_row)+", \
                    entry_value, 'DATA' \
            FROM entry_temp"
cur.execute(insert_stmt)

# Populate entry based on table_cell

insert_stmt="INSERT INTO entry (entry_cell_id) \
             SELECT cell_id FROM table_cell \
             WHERE table_id="+str(table_id)+" AND cell_annotation='DATA'"
cur.execute(insert_stmt)

# Populate label_temp temporary table from LABELS sheet

for row in all_labels_rows:
    label_val  = str(row[0].value)                             # value in LABEL column
    label_prov_text = str(row[1].value)                        # value in PROVENANCE column
    label_par  = str(row[2].value)                             # value in PARENT column
    label_cat  = str(row[3].value)                             # value in CATEGORY column
    if label_prov_text != 'PROVENANCE':                        # ignore header row
        label_prov=label_prov_text.split('","')[1].split('")')[0]      # get display val between '","' and '")'
        label_prov_col=''.join(filter(str.isalpha, label_prov))        # alpha part
        label_prov_row=int(''.join(filter(str.isdigit, label_prov)))   # numeric part        
        insert_stmt="INSERT INTO label_temp (label_value, label_provenance, label_provenance_col, label_provenance_row, label_parent, label_category) \
                     VALUES ('"+label_val+"', '"+label_prov+"', '"+label_prov_col+"', '"+str(label_prov_row)+"', '"+label_par+"', '"+label_cat+"')"
        cur.execute(insert_stmt)

insert_stmt="insert into category (category_name) select distinct label_category from label_temp"
cur.execute(insert_stmt)

# Populate table_cell based on label_temp and source_table contents

insert_stmt="INSERT INTO table_cell \
            (table_id, left_col, top_row, right_col, bottom_row, cell_content, cell_annotation) \
            SELECT  "+str(table_id)+", \
                    ascii(label_provenance_col)-ascii('"+tablestart_col+"'), \
                    label_provenance_row-"+str(tablestart_row)+", \
                    ascii(label_provenance_col)-ascii('"+tablestart_col+"'), \
                    label_provenance_row-"+str(tablestart_row)+", \
                    label_value, 'HEADING' \
            FROM label_temp"
cur.execute(insert_stmt)

# Populate label based on table_cell and label_temp
#     need to add parent info

insert_stmt="INSERT INTO label (label_cell_id, category_name) \
             SELECT tcv.cell_id, lt.label_category \
             FROM tabby_cell_view tcv \
             JOIN label_temp lt \
             ON tcv.cell_provenance=lt.label_provenance  \
             WHERE tcv.table_id="+str(table_id)+" AND tcv.cell_annotation='HEADING'"
cur.execute(insert_stmt)

# Populate entry_label from entry_label_temp and tabby_cell_view

insert_el="INSERT INTO entry_label (entry_cell_id, label_cell_id) \
           SELECT e_cell.cell_id, l_cell.cell_id \
           FROM entry_label_temp elt \
           JOIN tabby_cell_view e_cell ON elt.entry_provenance = e_cell.cell_provenance \
           JOIN tabby_cell_view l_cell ON elt.label_provenance = l_cell.cell_provenance"
cur.execute(insert_el)

# Generate canonical_table_view and display contents

create_ctv="CALL create_canonical_table_view("+str(table_id)+")"
cur.execute(create_ctv)

select_ctv="SELECT * FROM canonical_table_view"
cur.execute(select_ctv)
canonical_table = cur.fetchall()
print(canonical_table)

# Don't commit (at least during initial testing - will decide later whether or not data is to be kept)
#cur.execute('COMMIT;')
cur.close()

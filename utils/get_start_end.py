from openpyxl import load_workbook
import sys 
import os
import psycopg2

# Goals: 
#   Extract $START and $END cell ids from first sheet of TabbyXL input files

# 1. Process input parameters:

#   i. input_filepath       path to file to be processed
input_filepath = str(sys.argv[1])               
# input_filepath = '/home/karen/workspaces/classification_extraction_tests/test_files/tabby_10_files/xlsx'

# sheet_num and table_num will always be 0 for now - assuming one sheet per file, and one table per sheet
sheet_num=0
table_num=0

# 2. Create connection to table_model database with search_path set to table_model
#    (Need to parameterise this)

# tm_conn = psycopg2.connect(
#     host="p.qnplnpl3nbabto2zddq2phjlwi.db.postgresbridge.com",
#     database="table_model",
#     user="postgres")

tm_conn = psycopg2.connect(
    host="127.0.0.1",
    database="table_model",
    user="postgres")

cur = tm_conn.cursor()
cur.execute('SET SEARCH_PATH=table_model')


for file in os.listdir(input_filepath):
    input_file = input_filepath+"/"+file      # fully qualified file
    #print(input_file)
    base_filename=file.split('.xlsx')[0]      # base filename

    # Use openpyxl load_workbook to load the input file as a workbook (wb)
    # and get data from the required sheet as a worksheet (ws):

    wb = load_workbook(input_file)
    sheets=wb.sheetnames
    ws=wb[sheets[sheet_num]]
    
    all_rows = list(ws.rows)
    for row in all_rows:
        for cell in row:
            if cell.value == "$START":
                table_start=cell.coordinate
            elif cell.value == "$END":
                table_end=cell.coordinate

    #print("Table Start: "+table_start)
    #print("Table End: "+table_end)

    tablestart_col=''.join(filter(str.isalpha, table_start))        # alpha part, e.g. "A" from "A2"
    tablestart_row=int(''.join(filter(str.isdigit, table_start)))   # numeric part, e.g. 2 from "A2"

    tableend_col=''.join(filter(str.isalpha, table_end))        # alpha part, e.g. "U" from "U2"
    tableend_row=int(''.join(filter(str.isdigit, table_end)))   # numeric part, e.g. 12 from "U12"

    # Populate source_table
    # with a single row describing the table being processed

    insert_stmt="INSERT INTO source_table ( \
                table_is_gt, \
                table_method, \
                table_start_col, \
                table_start_row, \
                table_end_col, \
                table_end_row, \
                file_name,  \
                sheet_number, \
                table_number) \
                VALUES (TRUE, \
                        'tabbyxl', \
                        '"+tablestart_col+"', \
                        "+str(tablestart_row)+", \
                        '"+tableend_col+"', \
                        "+str(tableend_row)+", \
                        '"+base_filename+"', \
                        "+str(sheet_num)+", \
                        "+str(table_num)+")"
    cur.execute(insert_stmt)

# Commit changes to retain data input into tables
cur.execute('COMMIT;')
cur.close()
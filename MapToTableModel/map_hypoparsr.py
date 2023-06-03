import sys 
import psycopg2
import feather 
from io import StringIO

# Goals: 
#   Extract information from given Hypoparsr ground truth or extracted tables file and map it to table model
#   Hypoparsr extracted tables file is currently not in feather format

# 1. Process input parameters:

#   i. input_filepath       path to file to be processed
input_filepath = str(sys.argv[1])  
#   ii. input_filename       name of file to be processed (<basename>.csv.feather)
input_filename = str(sys.argv[2])               
#   iii. is_gt                TRUE if this is a file containing ground truth, FALSE if output 
if str(sys.argv[3]) == 'TRUE':
    table_is_gt='TRUE'
    is_gt=True
else:
    table_is_gt='FALSE'
    is_gt=False

# sample file for testing
# input_filepath="/tmp/test_21_05_2023/hypoparsr/"
# input_filename="C10001.csv.feather"
# is_gt=False

input_file = input_filepath+"/"+input_filename  # Fully qualified file

#    Get base filename based on input_file path and name

# filename=input_filename.split('.csv.feather')[0]
filename=input_filename.split('.csv')[0]

#    Get dataframe from input file

df = feather.read_dataframe(input_file) 
# print(df)

# 2. Create connection to table_model database with search_path set to table_model

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

# 3. Process table(s) in input (GT) file

#    Currently processing a single table per Hypoparsr GT file
#    table_number, table_start_col and table_start_row all hardcoded to 0
#    Can Hypoparsr GT files contain multiple tables?

sheet_num=0
table_num=0

tablestart_col=0
tablestart_row=0

# 3.1 Insert into source_table (sheetnum will always be zero for Hypoparsr, tableend isn't being populated for now)

insert_stmt="INSERT INTO source_table( \
                table_is_gt, \
                table_method, \
                table_start_col, \
                table_start_row, \
                file_name, \
                sheet_number, \
                table_number) \
            VALUES ( \
                "+table_is_gt+", \
                'hypoparsr', \
                '"+str(tablestart_col)+"', \
                "+str(tablestart_row)+", \
                '"+filename+"', \
                "+str(sheet_num)+", \
                "+str(table_num)+")"
cur.execute(insert_stmt)

#    get table_id
select_stmt="SELECT table_id \
             FROM source_table \
             WHERE table_is_gt="+table_is_gt+" \
             AND table_method='hypoparsr' \
             AND file_name='"+filename+"' \
             AND sheet_number="+str(sheet_num)+" \
             AND table_number="+str(table_num)+""
cur.execute(select_stmt)
table_id = cur.fetchone()[0]
print("table_id: ",table_id)

#    get number of (data) rows in dataframe
num_rows=df.shape[0]

#    get list of columns from dataframe - these will be the labels, i.e. the column headings
#    NOTE: can there be more than one row of labels in the dataframe?
df_columns=list(df)

# 3.2 Insert into category (only 1 category for hypoparsr - ColumnHeading)

insert_stmt_cat="INSERT INTO category ( \
                    category_name, \
                    table_id) \
                 VALUES ( \
                    'ColumnHeading', \
                    "+str(table_id)+")"
cur.execute(insert_stmt_cat)

# 3.3 Populate label_temp temporary table

#    Note: a label in Hypoparsr is a heading row of the discovered table
#          (label_category='ColumnHeading', cell_annotation='HEADING')
#          Current assumption: only 1 row of headings

# if tablestart is (0,0), then heading starts at (1,1):
heading_col=tablestart_col+1
heading_row=tablestart_row+1

for col in df_columns:
    #print(col)
    insert_lt="INSERT INTO label_temp ( \
                label_value, \
                label_provenance_row, \
                label_provenance_col, \
                label_category) \
               VALUES ( \
                '"+str(col)+"', \
                "+str(heading_row)+", \
                "+str(heading_col)+", \
                'ColumnHeading')"
    cur.execute(insert_lt)
    heading_col+=1

# 3.4 Populate entry_temp temporary table

#     for each (data) row in dataframe, insert each cell into entry_temp.

first_data_row=heading_row+1          # first data row is row after last heading row
first_data_col=tablestart_col+1       # first data col is same as first heading col

for row_id in range(num_rows):
  col_id=first_data_col               # reset col_id for each row
  for col in df_columns:
    cell=df.loc[row_id][col]
    cell=str(cell).replace("'","''")   # cell value with single quotes escaped
    # print('row_id: '+str(row_id)+' cell: '+str(cell))
    insert_et="INSERT INTO entry_temp ( \
                entry_value, \
                entry_provenance_row, \
                entry_provenance_col, \
                entry_labels) \
               VALUES ( \
                '"+str(cell)+"', \
                "+str(row_id+first_data_row)+", \
                "+str(col_id)+", \
                '"+str(col)+"')"
    cur.execute(insert_et)
    col_id+=1

# 3.4 Populate table_cell 

#     First, insert 'DATA' rows, based on entry_temp contents 
#     (right_col=left_col and top_row=bottom_row because each table_cell is made up of a single csv "cell")

insert_stmt_t_cell="INSERT INTO table_cell \
            (table_id, left_col, top_row, right_col, bottom_row, cell_content, cell_annotation) \
            SELECT  "+str(table_id)+", \
                    entry_provenance_col::int, entry_provenance_row, \
                    entry_provenance_col::int, entry_provenance_row, \
                    entry_value, 'DATA' \
            FROM entry_temp"
cur.execute(insert_stmt_t_cell)

#    Next, insert 'HEADING' rows, based on label_temp contents 

insert_stmt_t_cell="INSERT INTO table_cell \
                   (table_id, left_col, top_row, right_col, bottom_row, cell_content, cell_annotation) \
                    SELECT  "+str(table_id)+", \
                        label_provenance_col::int, label_provenance_row, \
                        label_provenance_col::int, label_provenance_row, \
                        label_value, 'HEADING' \
            FROM label_temp"
cur.execute(insert_stmt_t_cell)

#    Populate label based on table_cell

insert_stmt_label="INSERT INTO label (label_cell_id, category_name) \
                   SELECT cell_id, 'ColumnHeading' FROM table_cell \
                   WHERE table_id="+str(table_id)+" AND cell_annotation='HEADING'"
cur.execute(insert_stmt_label)

#    Populate entry based on table_cell

insert_stmt_entry="INSERT INTO entry (entry_cell_id) \
                SELECT cell_id FROM table_cell \
                WHERE table_id="+str(table_id)+" AND cell_annotation='DATA'"
cur.execute(insert_stmt_entry)

# Populate entry_label from entry_temp

insert_stmt_el="INSERT INTO entry_label (entry_cell_id, label_cell_id) \
           SELECT e_cell.cell_id, l_cell.cell_id \
           FROM entry_label_temp elt \
           JOIN tabby_cell_view e_cell ON elt.entry_provenance = e_cell.cell_provenance \
           JOIN tabby_cell_view l_cell ON elt.label_provenance = l_cell.cell_provenance"
cur.execute(insert_stmt_el)

# Empty temp tables

truncate_et="TRUNCATE TABLE entry_temp, label_temp, entry_label_temp"
cur.execute(truncate_et)

# Commit changes to retain data input into tables
cur.execute('COMMIT;')

cur.close()

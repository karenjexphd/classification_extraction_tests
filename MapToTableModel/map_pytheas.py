import sys 
import psycopg2
import json
import re


# Goals: 
#   Extract information from given Pytheas ground truth file or output file and map it to table model
#   Note: a Pytheas output file may contain one or more tables in the discovered_tables section

#   WE ARE CURRENTLY ASSUMING A SINGLE TABLE BECAUSE WE ARE PROCESSING A DATA SET THAT CONTAINS ONLY ONE TABLE PER SHEET
#   ISSUE #13 HAS BEEN CREATED TO ADDRESS THIS

# 1. Process input parameters:

#   i. input_filepath       path to file to be processed
input_filepath = str(sys.argv[1])               
#   ii. input_filename       name of file to be processed (<filename>.json)
input_filename = str(sys.argv[2])               
#   iii. is_gt                TRUE if this is a file containing ground truth, FALSE if is is an output file 
if str(sys.argv[3]) == 'TRUE':
    is_gt=True
else:
    is_gt=False

input_file = input_filepath+"/"+input_filename  # Fully qualified file


# sample input_file for testing
# input_filepath="/tmp/test_20_05_2023/pytheas"
# input_filename="C10001.json"
# is_gt=False

# Get base filename based on input_file path and name

filename=input_filename.split('.json')[0]

if is_gt:

  # processing a (json) ground truth file

  with open(input_file) as f:
    annotations = json.load(f)

  # extract the tables from the json (this is the only part needed for the evaluation)
  tables = annotations['tables']

else:
  # processing a (json) output file containing extracted tables
  # The json file is not in the format expected by json.load() 
  # Replacements are necessary in order to obtain valid json that can be loaded
  # We want just the discovered_tables part, i.e. starting from first opening curly bracket

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


    # print("new_json: ")
    # print(new_json)

    tables = json.loads(new_json) 

# 2. Create connection to table_model database with search_path set to table_model
#    (Need to parameterise this)

tm_conn = psycopg2.connect(
    host="127.0.0.1",
    database="table_model",
    user="postgres")

cur = tm_conn.cursor()
cur.execute('SET SEARCH_PATH=table_model')

# 3. Process tables

# print ("number of tables: ",len(tables))

for i in range(len(tables)):
    table=tables[str(i+1)]              # first table (in output) will have key '1', second will have key '2' etc.
                                        # CHECK: this may differ if we are processing the GT
    tablenum=i                          # to match the way in which the tables are numbered for the other systems
    tablestart=table['top_boundary']
    tableend=table['bottom_boundary']

    # print()
    # print()
    # print("table being processed:")
    # print(table)
    # print()
    # print()

    # retrieve existing data (table ID, table start/end col & row) from source_table for the file/table being processed
    # note that sheet_number is always 0 for pytheas

    select_stmt="SELECT table_id, \
                        table_start_col, \
                        table_start_row, \
                        table_end_col, \
                        table_end_row \
                FROM source_table \
                WHERE table_is_gt=TRUE \
                AND file_name='"+filename+"' \
                AND sheet_number=0 \
                AND table_number="+str(tablenum)
    cur.execute(select_stmt)

    table_info = cur.fetchone()

    gt_table_id    = table_info[0]
    tablestart_col = table_info[1]
    tablestart_row = table_info[2]
    tableend_col   = table_info[3]
    tableend_row   = table_info[4]

    if is_gt:

        # We're processing the ground truth file so source_table is already populated
        # Set gt_table_id to table_id in preparation for populating the remaining tables
        table_id=gt_table_id

    else:       
        
        # We're processing the output file so we need to populate source_table with the information just retrieved
        # note that pytheas only provides table_start_row and table_end_row, not table_start_col or table_end_col

        insert_stmt="INSERT INTO source_table ( \
                        table_is_gt, \
                        table_method, \
                        table_start_row, \
                        table_end_row, \
                        file_name, \
                        sheet_number, \
                        table_number) \
                    VALUES ( \
                        FALSE, \
                        'pytheas', \
                        "+str(tablestart)+", \
                        "+str(tableend)+", \
                        '"+filename+"', \
                        0, \
                        "+str(tablenum)+")"
        cur.execute(insert_stmt)

        # retrieve (automatically generated) table_id from source_table

        select_stmt="SELECT table_id FROM source_table \
                    WHERE table_is_gt=FALSE \
                    AND table_method='pytheas' \
                    AND file_name='"+filename+"' \
                    AND sheet_number=0 \
                    AND table_number="+str(tablenum)
        cur.execute(select_stmt)
        
        table_info = cur.fetchone() 

        table_id = table_info[0]
        print('table_id: '+str(table_id))

    # Continue to populate the table_model whether this is a ground truth or an output file

    # GET COLUMN & LABEL INFORMATION AND POPULATE LABEL_TEMP

    # label_rows=table['header']       # header is list of rows containing headers - only exists in the GT, not the output

    # get cells containing column headings and populate label_temp temporary table

    columns=table['columns']

    col_nums=[]

    for col_id in range(len(columns)):
        column=columns[str(col_id)]            
        col_num = column['table_column']       # NOTE: doesn't necessarily represent column number in the spreadsheet - may need to do some translation
        col_nums.append(col_num)             

        column_header=column['column_header']
        if len(column_header)>0:          # i.e. the column contains labels)

            # print('Column ',col_id,':')

            for k in range(len(column_header)):
                label=column_header[k]  

                label_prov_col=label['column']         
                label_prov_row=label['row']
                label_index=label['index']
                label_val=label['value']

                # insert info for this label into label_temp IF IT DOES NOT ALREADY EXIST (parent labels are repeated in the JSON)

                insert_lt="INSERT INTO label_temp (\
                                table_id,\
                                label_value,\
                                label_provenance_col,\
                                label_provenance_row) \
                            SELECT \
                                "+str(table_id)+",\
                                '"+label_val+"',\
                                '"+str(label_prov_col)+"',\
                                '"+str(label_prov_row)+"'\
                            WHERE NOT EXISTS ( \
                                SELECT \
                                    table_id,\
                                    label_value,\
                                    label_provenance_col,\
                                    label_provenance_row \
                                FROM label_temp \
                                WHERE \
                                    table_id = "+str(table_id)+" AND \
                                    label_value = '"+label_val+"' AND \
                                    label_provenance_col = '"+str(label_prov_col)+"' AND \
                                    label_provenance_row = '"+str(label_prov_row)+"')"
                                
                cur.execute(insert_lt)

    # Populate table_cell based on label_temp contents

    # QUESTION: Do the Pytheas table_cell coordinates (left_col and top_row) represent the position of the cell within the table
    # or the position of the cell within the file (i.e. the cell provenance in TabbyXL language)?

    # May need to calculate based on table start row and column as for tabbyxl mapping

    #   top_row = bottom_row and right_col = left_col because the Pytheas table_cell is always a single physical cell

    insert_stmt="INSERT INTO table_cell (\
                        table_id, \
                        left_col, \
                        top_row, \
                        right_col, \
                        bottom_row, \
                        cell_content, \
                        cell_annotation) \
                SELECT  "+str(table_id)+", \
                        CAST(label_provenance_col AS INTEGER), \
                        label_provenance_row, \
                        CAST(label_provenance_col AS INTEGER), \
                        label_provenance_row, \
                        label_value, \
                        'HEADING' \
                FROM label_temp WHERE table_id="+str(table_id)
    cur.execute(insert_stmt)

    # Populate label based on table_cell
    # NOTE: not yet infering parent label information - TO DO

    insert_stmt="INSERT INTO label (label_cell_id) \
                 SELECT cell_id FROM table_cell \
                 WHERE table_id="+str(table_id)+" AND cell_annotation='HEADING'"
    cur.execute(insert_stmt)

    # print("there are ",len(columns)," columns in the table:")
    # print(col_nums)

    # ENTRIES

    # Get data row information and populate entry_temp table

    #    Pytheas does not output the actual data as part of the output file
    #    but identifies the position of data rows and columns which can be mapped back to the original input file

    # data_rows=table['data_indexes']       # data_indexes is list of rows containing data - only exists in the GT, not the output

    # get list of rows containing data by listing rows between data_start and data_end inclusive

    data_start=table['data_start']
    data_end=table['data_end']

    data_rows=[row for row in range(data_start,data_end+1)]

    # Populate temporary table entry_temp       NOTE: infer the cells that contain data/entries from the list of data rows and the list of columns

    for data_row in data_rows:

        for col_num in col_nums:

            insert_et="INSERT INTO entry_temp (\
                        table_id, \
                        entry_provenance_col, \
                        entry_provenance_row) \
                    VALUES ( \
                        "+str(table_id)+", \
                        "+str(col_num)+", \
                        "+str(data_row)+")"
            cur.execute(insert_et)

    # Populate table_cell based on contents of entry_temp

    # QUESTION: Do the Pytheas table_cell coordinates (left_col and top_row) represent the position of the cell within the table
    # or the position of the cell within the file (i.e. the cell provenance in TabbyXL language)?

    # May need to calculate based on table start row and column as for tabbyxl mapping

    #   top_row = bottom_row and right_col = left_col because the Pytheas table_cell is always a single physical cell

    insert_stmt="INSERT INTO table_cell (\
                        table_id, \
                        left_col, \
                        top_row, \
                        right_col, \
                        bottom_row, \
                        cell_annotation) \
                SELECT  "+str(table_id)+", \
                        CAST(entry_provenance_col AS INTEGER), \
                        entry_provenance_row, \
                        CAST(entry_provenance_col AS INTEGER), \
                        entry_provenance_row, \
                        'DATA' \
                FROM entry_temp WHERE table_id="+str(table_id)
    cur.execute(insert_stmt)

    # Populate entry based on table_cell

    insert_stmt="INSERT INTO entry (entry_cell_id) \
                SELECT cell_id FROM table_cell \
                WHERE table_id="+str(table_id)+" AND cell_annotation='DATA'"
    cur.execute(insert_stmt)

    # Display contents of pytheas_canonical_table_view

    # select_ctv="SELECT table_number, table_row, row_provenance, cell_annotation \
    #             FROM pytheas_canonical_table_view where table_id="+str(table_id)
    # cur.execute(select_ctv)
    # canonical_table = cur.fetchall()
    # print(canonical_table)

    truncate_et="TRUNCATE TABLE entry_temp, label_temp, entry_label_temp"
    cur.execute(truncate_et)

cur.execute('COMMIT;')

cur.close()

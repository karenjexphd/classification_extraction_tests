import sys 
import psycopg2
import psycopg2.extras as extras
import json
import re
import pandas

# Goal: Extract information from given Strudel output file and map it to table model

# Will be called once for each file found in the strudel table extraction output directory
# i.e. <outputdir>/strudel/<dataset>_lstrudel.csv 
# and  <outputdir>/strudel/<dataset>_cstrudel.csv
# We don't (currently) want to process the line classifications - just the column classifications

# Test files (COMMENT ONCE FINISHED TESTING AND UNCOMMENT INPUT PARAMETERS)

input_filepath='/tmp/kjtest'
# line_classifications
input_filename='tabby_200_files_cstrudel.csv'
# cell_classifications
# input_filename='tabby_200_files_cstrudel.csv'
is_gt=False

# 1. Process input parameters:

#   i. input_filepath       path to file to be processed
# input_filepath = str(sys.argv[1])               
#   ii. input_filename       name of file to be processed (<filename>.json)
# input_filename = str(sys.argv[2])               
#   iii. is_gt                TRUE if this is a file containing ground truth, FALSE if is is an output file 
# if str(sys.argv[3]) == 'TRUE':
#     is_gt=True
# else:
#     is_gt=False

filetype   = input_filename.split('.csv')[0].split('_')[-1]
print('filetype:',filetype)


if filetype=='cstrudel':
    # Continue only if this is the output of cell classification
    print("Processing cell classification output")

    input_file = input_filepath+"/"+input_filename  # Fully qualified file

    dataset=pandas.read_csv(input_file)

    # 2. Create connection to table_model database with search_path set to table_model
    #    (Need to parameterise this)

    tm_conn = psycopg2.connect(
        host="127.0.0.1",
        database="table_model",
        user="postgres")

    cur = tm_conn.cursor()
    cur.execute('SET SEARCH_PATH=table_model')

    # 3. Identify inidividual filenames in dataset

    # NOTE: WANT TO PROCCESS BY TABLE. 
    #       Output contains file_name & sheet_name which combine to identify the table
    #       In this dataset, we know that there's one table per sheet and one sheet per file
    #       How do we want to deal with this?
    #       Just use file_name as the table_name as a temporary measure?
    #       Later: check how many sheets there are for a given file to get individual tables

    # get list of file_names in the dataset
    groups_by_file = dataset.groupby('file_name')
    filenames = list(groups_by_file.groups.keys())

    for filename in filenames:

        print("INFO: processing file ",filename)

        # filedata = groups_by_file.get_group(filename)

        # restrict rows to just those with this file_name, and colums to 'row_index', 'column_index' and 'predict'
        filedata=dataset.loc[dataset['file_name'] == filename, ['row_index','column_index','predict']]

        print(filedata)

        # retrieve existing data (table ID, table start/end col & row) 
        # from source_table for the file/table being processed

        select_stmt="SELECT table_id, \
                            table_start_col, \
                            table_start_row, \
                            table_end_col, \
                            table_end_row \
                    FROM source_table \
                    WHERE table_is_gt=TRUE \
                    AND file_name='"+filename+"' \
                    AND sheet_number=0 \
                    AND table_number=0"
        cur.execute(select_stmt)

        table_info = cur.fetchone()

        # the following should only be executed if a corresponding ground truth table exists in source_table
        # i.e. a row has beeen returned by the previous statement

        try:
            gt_table_id    = table_info[0]
            tablestart_col = table_info[1]
            tablestart_row = table_info[2]
            tableend_col   = table_info[3]
            tableend_row   = table_info[4]
        except TypeError:
            print('WARNING: No ground truth exists for this table')

        if is_gt:

            # We're processing the ground truth file so source_table is already populated
            # Set gt_table_id to table_id in preparation for populating the remaining tables
            table_id=gt_table_id

        else:
            
            # We're processing the output file so we need to populate source_table with the information just retrieved

            insert_stmt="INSERT INTO source_table ( \
                            table_is_gt, \
                            table_method, \
                            file_name, \
                            sheet_number, \
                            table_number) \
                        VALUES ( \
                            FALSE, \
                            'strudel', \
                            '"+filename+"', \
                            0, \
                            0)"
            cur.execute(insert_stmt)

            # retrieve (automatically generated) table_id from source_table

            select_stmt="SELECT table_id FROM source_table \
                        WHERE table_is_gt=FALSE \
                        AND table_method='strudel' \
                        AND file_name='"+filename+"' \
                        AND sheet_number=0 \
                        AND table_number=0"
            cur.execute(select_stmt)
            
            table_info = cur.fetchone() 

            table_id = table_info[0]
            print('INFO: source_table.table_id: '+str(table_id))

        # Continue to populate the table_model whether this is a ground truth or an output file

            # Headings in cell classification that we are interested in:

            # file_name
            # sheet_name
            # row_index
            # column_index
            # predict         <-- not sure if we want "predict" or "label" - check code

        # Populate entry_temp

        # Required enhancement: create separate temp table for the cell classification
        #                       (currently using entry_value in entry_temp to store the cell type)

        # Create a list of tuples from the dataframe values
        tuples = [tuple(x) for x in filedata.to_numpy()]
        cols=('row_index','column_index','predict')

        insert_et="INSERT INTO entry_temp (\
            entry_provenance_row, \
            entry_provenance_col, \
            entry_value) \
          VALUES %s"

        extras.execute_values(cur, insert_et, tuples)

        # Set table_id
        cur.execute("UPDATE entry_temp set table_id="+str(table_id))

        # Populate table_cell from entry_temp

        insert_stmt="INSERT INTO table_cell (\
                            table_id, \
                            left_col, \
                            top_row, \
                            cell_annotation) \
                    SELECT  "+str(table_id)+", \
                            CAST(entry_provenance_col AS INTEGER), \
                            entry_provenance_row, \
                            entry_value \
                    FROM entry_temp"
        cur.execute(insert_stmt)

        # Populate entry based on table_cell

        insert_stmt="INSERT INTO entry (entry_cell_id) \
                    SELECT cell_id FROM table_cell \
                    WHERE table_id="+str(table_id)+" AND cell_annotation ='DATA'"
        cur.execute(insert_stmt)

        # Populate label based on table_cell

        insert_stmt="INSERT INTO label (label_cell_id) \
                    SELECT cell_id FROM table_cell \
                    WHERE table_id="+str(table_id)+" AND cell_annotation='HEADING'"
        cur.execute(insert_stmt)

        # Truncate entry_temp for this table

        cur.execute('TRUNCATE TABLE entry_temp')

    cur.execute('COMMIT')
    cur.close()
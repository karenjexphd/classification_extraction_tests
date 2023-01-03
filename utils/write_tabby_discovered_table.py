from openpyxl import load_workbook
import sys 

# Goal: extract the following information from the given spreadsheet and write it in Pytheas format to discovered tables  file:

# data_start      = (min numeric part of 2nd col (PROVENANCE) from ENTRIES sheet) -1
# data_end        = (max numeric part of 2nd col (PROVENANCE) from ENTRIES sheet) -1
# top_boundary    = (min numeric part of 2nd col (PROVENANCE) from LABELS sheet) -1
# bottom_boundary = (max numeric part of 2nd col (PROVENANCE) from LABELS sheet) -1

data_file = str(sys.argv[1])
output_file = str(sys.argv[2])
table_id = str(sys.argv[3])

# load the workbook and get the required sheets (ENTRIES and LABELS):
wb         = load_workbook(data_file)
ws_entries = wb['ENTRIES']
ws_labels  = wb['LABELS']

all_entries_rows = list(ws_entries.rows)
all_labels_rows = list(ws_labels.rows)

# get entries
entries_vals=[]
for row in all_entries_rows:
    provenance = row[1].value                                 # value in PROVENANCE column
    if provenance != 'PROVENANCE':
        prov_val=provenance.split('","')[1].split('")')[0]    # just the display value (between '","' and '")' )
        prov_num=int(''.join(filter(str.isdigit, prov_val)))  # just the numeric part
        entries_vals.append(prov_num)

min_entry_row=min(v for v in entries_vals)
max_entry_row=max(v for v in entries_vals)

# get labels
labels_vals=[]
for row in all_labels_rows:
    provenance = row[1].value                                 # value in PROVENANCE column
    if provenance != 'PROVENANCE':
        prov_val=provenance.split('","')[1].split('")')[0]    # just the display value (between '","' and '")' )
        prov_num=int(''.join(filter(str.isdigit, prov_val)))  # just the numeric part
        labels_vals.append(prov_num)

min_label_row=min(v for v in labels_vals)
max_label_row=max(v for v in labels_vals)

data_start      = str(min_entry_row - 1)
data_end        = str(max_entry_row - 1)
top_boundary    = str(min_label_row - 1)
bottom_boundary = str(max_label_row - 1)

discovered_table = table_id + ": { 'aggregation_scope': {}, \n \
    'bottom_boundary':" + bottom_boundary + ",\n \
    'columns': {   0: {'column_header': [], 'table_column': 0 }},\n \
    'data_end':" + data_end + ", \n \
    'data_end_confidence': 1.0,\n \
    'data_start': " + data_start + ",\n \
    'fdl_confidence': {   'avg_confusion_index': 0.5,\n \
                          'avg_difference': 0.5,\n \
                          'avg_majority_confidence': 0.5,\n \
                          'softmax': 0.5 },\n \
    'footnotes': [],\n \
    'header': [],\n \
    'subheader_scope': {},\n \
    'top_boundary':" + top_boundary + " }"

with open(output_file, 'a') as f:                # append discovered_table to output file 
    f.write(discovered_table)

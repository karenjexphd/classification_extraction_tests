from openpyxl import load_workbook
import sys 

# Goal: extract information from given Tabby ground truth file and write it in Pytheas ground truth format 

input_file = str(sys.argv[1])       # Tabby format GT file (.xlsx in same format as Tabby extracted tables file)
output_file = str(sys.argv[2])      # Name required for extracted pytheas ground truth file

# load the workbook and get the required sheets (ENTRIES and LABELS):
wb         = load_workbook(input_file)
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


ground_truth = '{\n \
        "blanklines": [],\n \
        "tables": [{\n \
                "table_counter": 1,\n \
                "top_boundary": ' + top_boundary + ',\n \
                "bottom_boundary": ' + bottom_boundary + ',\n \
                "data_start": ' + data_start + ',\n \
                "data_end": ' + data_end + ',\n \
                "headnotes": [],\n \
                "header": [],\n \
                "subheaders": [],\n \
                "data_indexes": [],\n \
                "first_data_line": ' + data_start + ',\n \
                "not_data": [],\n \
                "footnotes": []\n \
        }]\n \
}'

with open(output_file, 'a') as f:                # write ground_truth to output file 
    f.write(ground_truth)

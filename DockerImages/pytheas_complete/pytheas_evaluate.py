# Python script to perform evaluation of table extraction

# input:  argv[1] Ground Truth in json format (annotated_tables) 
#         argv[2] output from table extraction in json format (discovered_tables)
# output: argv[3] table_confusion_matrix 
#         argv[4] table_confidences

# import required libraries
import sys
import json
import re
import evaluation.evaluation_utilities as eval_utils
from pytheas import pytheas
from pprint import pprint

Pytheas = pytheas.API()

# load first file (ground truth) as annotations, and extract annotated_tables from it

file1 = open(str(sys.argv[1]))
annotations = json.load(file1)
annotated = annotations['tables']

# load second file provided (discovered_tables) starting from first opening curly bracket

json_in=''

with open(str(sys.argv[2])) as file2:
    started=False
    for line in file2:
        if (line.startswith('{')):
            started=True
        if started:
            json_in+=line
#    json_in = file2.read()

# **TEMP SOLUTION** : files require editing to obtain valid json that can be loaded

# Replace ' in the middle of a double-quoted value with ''
new_json = re.sub('(".+)\'(.+")','\g<1>\'\'\g<2>',json_in)

# Replace all ' with "  
new_json = re.sub('\'','"',new_json)

# Now replace "" in the middle of a quoted value with '
new_json = re.sub('(".+)""(.+")','\g<1>\'\g<2>',new_json)

# Replace all <number>: with "<number>":
new_json = re.sub('([0-9]+)(:)', '\"\g<1>\":', new_json) 

# Remove newline in the middle of a value (** TEMPORARY SOLUTION **)
new_json = re.sub('\"\n\ +\"', '', new_json)
#print(new_json)

discovered = json.loads(new_json)

# Get table confusion matrix and table confidences by evaluating the discovered tables
conf_matrix, confidences = eval_utils.evaluate_relation_extraction(annotated, discovered)

# output table confusion matrix (json object) to file
json.dump(conf_matrix, open(str(sys.argv[3]),"w"))

# output table confidences (panda DataFrame object) to csv
confidences.to_csv(str(sys.argv[4]), index=False, header=True)
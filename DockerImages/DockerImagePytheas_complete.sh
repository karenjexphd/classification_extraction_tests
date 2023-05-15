#-----------------------------------------------------------------------#
# File containing instructions for adding scripts to base Docker image  #
#   docker-pytheas-base to create docker-pytheas image                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

mkdir /tmp/pytheas_dockerfiles
cp -r test_files /tmp/pytheas_dockerfiles
cd /tmp/pytheas_dockerfiles

# Create Python script to apply pytheas table extraction against given .csv file

cat > pytheas_apply_to_file.py << EOF
import sys
from nltk.corpus import stopwords
from pytheas import pytheas
from pprint import pprint
Pytheas = pytheas.API()
Pytheas.load_weights('/app/pytheas/src/pytheas/trained_rules.json')
filepath = str(sys.argv[1])
file_annotations = Pytheas.infer_annotations(filepath)
pprint(file_annotations)
EOF

# Create script to perform just extract_tables() to get discovered_tables

cat > pytheas_extract_tables.py << EOF

# input:  argv[1] directory containing input (csv) files
#         argv[2] filename of csv file being processed

import sys
import json
from nltk.corpus import stopwords
from pytheas import pytheas
from pprint import pprint
import pytheas.file_utilities as file_utils

mypytheas = pytheas.PYTHEAS()
mypytheas.load_weights('/app/pytheas/src/pytheas/trained_rules.json')
blank_lines = []

inputdir = str(sys.argv[1])
filename = str(sys.argv[2])
inputfile = inputdir + "/" + filename

file_dataframe=file_utils.get_dataframe(inputfile, None)
file_dataframe_trimmed=file_dataframe
discovered_tables = mypytheas.extract_tables(file_dataframe_trimmed, blank_lines)

pprint(discovered_tables)

EOF

# Create script to call pytheas table extraction for each csv file in input directory

cat > pytheas_extract_tables.sh << EOF
inputdir=\$1
outputdir=\$2
for file in \$(ls \$inputdir)
do
  if [[ \$file == *.csv ]]
  then
    basefile=\$(basename \$file .csv)
    outputfile=\${outputdir}/\${basefile}.json
    python3 pytheas_extract_tables.py \$inputdir \$file > \$outputfile
  fi
done
EOF

chmod u+x pytheas_extract_tables.sh

# create shell script to call pytheas_evaluate
# against all files for given method in a given folder

cat > pytheas_evaluate_tables.sh << EOF
gtdir=\$1
outputdir=\$2
method=\$3
for file in \$(ls \$outputdir)
do
  echo "processing file \${file} for method \${method}"
  if [[ \$file == *\${method}_tables.json ]]
  then
    basefile=\$(basename \$file _\${method}_tables.json)  # remove _method_tables.json
    gt_file=\${gtdir}/\${basefile}.json
    tables_file=outputdir/\${file}
    confusion_file=outputdir/\${basefile}_\${method}_confusion.out
    confidences_file=outputdir/\${basefile}_\${method}_confidences.out
    echo "calling pytheas_evaluate with gt file \${gt_file}, discovered tables file \${file}, and writing to \${confusion_file} and \${confidences_file}"
    python3 pytheas_evaluate.py \$gt_file \$tables_file \$confusion_file \$confidences_file
  fi
done
EOF

chmod u+x pytheas_evaluate_tables.sh

# Create Python script to perform evaluation of table extraction

cat > pytheas_evaluate.py << EOF
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

EOF

# Create Python script to compare table extraction evaluations

cat > pytheas_compare.py << EOF
# input:  argv[1] list of methods (separated by white space, eg "method1 method2 method3")
#         argv[2] list of files (separated by white space, eg "C10001 C10002")
#         argv[3] desired output directory
# output: printed output : table confusion matrix for each method in tabular format

import sys
import json

filedir = str(sys.argv[3])
comparison_table = []  # define comparison table as empty list

keys = []
vals = []

methods = str(sys.argv[1])      # get string containing list of methods from input
filenames = str(sys.argv[2])    # get string containing list of filenames from input
method_list = methods.split()   # split string to get list of methods
file_list = filenames.split()   # split string to get list of files

for file in file_list:
    print(file)
    for method in method_list:      # process confusion matrix file for each method
        conf_file=filedir+"/"+file+"_"+method+"_confusion.out"
        with open(conf_file) as f:  # open the file and process the confusion matrix
            confusion_matrix = f.read()  
            confusion_info=json.loads(confusion_matrix) # convert confusion matrix to json
            val = []
            keys.append('file')
            val.append(file)
            keys.append('method')
            val.append(method)
            for k,v in confusion_info.items():
                keys.append(k)
                val.append(v)
            vals.append(val)

# print comparison_table

print(list(dict.fromkeys(keys)))
for v in vals:
    print(v)

EOF

# Create Dockerfile

cat > Dockerfile << EOF
# syntax=docker/dockerfile:1
FROM karenjexphd/table_extraction_tests:docker-pytheas-base
WORKDIR /app
COPY pytheas_apply_to_file.py pytheas_apply_to_file.py 
COPY pytheas_evaluate_tables.sh pytheas_evaluate_tables.sh
COPY pytheas_evaluate.py pytheas_evaluate.py
COPY pytheas_extract_tables.py pytheas_extract_tables.py
COPY pytheas_extract_tables.sh pytheas_extract_tables.sh
COPY pytheas_compare.py pytheas_compare.py
WORKDIR /app
EOF

# Build docker-pytheas Docker image

docker build --tag docker-pytheas .

# Save image to Docker Hub

docker tag docker-pytheas karenjexphd/table_extraction_tests:docker-pytheas
docker push karenjexphd/table_extraction_tests:docker-pytheas

rm -rf /tmp/pytheas_dockerfiles

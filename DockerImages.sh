#-----------------------------------------------------------------------#
# File containing instructions for creating Docker images               #
# 1. docker-pytheas containing Pytheas runtime environment              #
# 2. docker-hypoparsr containing Hypoparsr runtime environment
# 3. docker-tabby containing TabbyXL runtime environment                #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#                         -- Prerequisites --                           #
#-----------------------------------------------------------------------#

# User performing tasks should be added to docker group:
#    sudo usermod -a -G <group> <username>
#    sudo usermod -a -G docker karen

# Logged in to Docker Hub:
#   docker login -u <username>
#   docker login -u karenjexphd

#-----------------------------------------------------------------------#
#                            -- TO DO --                                #
#-----------------------------------------------------------------------#

# parameterise dockerhub and github usernames (currently karenjexphd)

# use mounts instead of copying files during creation of docker images

# allow for multiple demo_a_n_n.xlsx files (multiple tables in input)
# loop through $outputdir and process all files with xlsx2csv


#-----------------------------------------------------------------------#
# 0. Setup                                                               #
#-----------------------------------------------------------------------#

# Install pip
sudo apt install python3-pip

# Enable Docker buildKit
sudo DOCKER_BUILDKIT=1 docker build .

#-----------------------------------------------------------------------#
# 1. Create Docker Images                                               #
#-----------------------------------------------------------------------#

#-----   1a. create docker-tabby image for TabbyXL                  -----#

mkdir ~/tabby_dockerfiles
cd ~/tabby_dockerfiles

# Clone required repos

git clone git@github.com:karenjexphd/tabbyxl.git
git clone git@github.com:karenjexphd/test_data_10_tables.git

# Create Dockerfile - image based on rockylinux 8

cat > Dockerfile << EOF
FROM rockylinux:8
WORKDIR /app
COPY tabbyxl tabbyxl
COPY test_data_10_tables/simple_test test_data
RUN yum -y update
RUN yum -y install git maven
RUN mvn -f ./tabbyxl/pom.xml clean install
RUN sed -i 's/java /java -Xmx1024m /' tabbyxl/test.sh
RUN chmod u+x tabbyxl/test.sh
EOF

# Build docker-tabby Docker image
docker build --tag docker-tabby .

# Save image to Docker Hub
docker tag docker-tabby karenjexphd/table_extraction_tests:docker-tabby
docker push karenjexphd/table_extraction_tests:docker-tabby

#-----   1b. create docker-pytheas image for Pytheas              -----#

mkdir ~/pytheas_dockerfiles
cd ~/pytheas_dockerfiles

# Clone necessary repos

git clone git@github.com:karenjexphd/pytheas.git
git clone git@github.com:karenjexphd/test_data_10_tables.git

# Create file containing pip install requirements

cat > requirements.txt << EOF
psycopg2-binary==2.9.4
nltk==3.6
pytest==7.0.1
EOF

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
# TO DO: save the output directly to a file instead of using pprint() :
#    with open('outputdir/discovered_tables.json', 'w') as f:
#        f.write(discovered_tables)

cat > pytheas_extract_tables.py << EOF
import sys
from nltk.corpus import stopwords
from pytheas import pytheas
from pprint import pprint
import pytheas.file_utilities as file_utils
mypytheas = pytheas.PYTHEAS()
mypytheas.load_weights('/app/pytheas/src/pytheas/trained_rules.json')
blank_lines = []
filepath = str(sys.argv[1])
file_dataframe=file_utils.get_dataframe(filepath, None)
file_dataframe_trimmed=file_dataframe
discovered_tables = mypytheas.extract_tables(file_dataframe_trimmed, blank_lines)
pprint(discovered_tables)
EOF


# Create Python script to perform evaluation of table extraction

cat > pytheas_evaluate.py << EOF
# input:  argv[1] Ground Truth in json format (annotated_tables) 
#         argv[2] output from table extraction in json format (discovered_tables)
# output: argv[3] table_confusion_matrix 
#         argv[4] table_confidences
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
# load second file provided (discovered_tables) and edit it to make it valid json
with open(str(sys.argv[2])) as file2:
    json_in = file2.read()
# Replace all ' with "
json_mod = json_in.replace("'", '"')
# Replace all n: with "n":
new_json = re.sub('([0-9]+)(:)', '\"\g<1>\"\g<2>', json_mod) 
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
#         argv[2] desired output directory
# output: printed output : table confusion matrix for each method in tabular format

import sys
import json

filedir = str(sys.argv[2])
#filedir = "outputdir"
comparison_table = []  # define comparison table as empty list

keys = []
vals = []

methods = str(sys.argv[1])      # get string containing list of methods from input
method_list = methods.split()   # split string to get list of methods
for method in method_list:      # process confusion matrix file for each method
    conf_file=filedir+"/"+method+"_confusion.out"
    with open(conf_file) as f:  # open the file and process the confusion matrix
        confusion_matrix = f.read()  
        confusion_info=json.loads(confusion_matrix) # convert confusion matrix to json
        val = []
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
FROM python:3.6
WORKDIR /app
COPY requirements.txt requirements.txt 
COPY pytheas_apply_to_file.py pytheas_apply_to_file.py 
COPY pytheas_evaluate.py pytheas_evaluate.py
COPY pytheas_extract_tables.py pytheas_extract_tables.py
COPY pytheas_compare.py pytheas_compare.py
RUN pip3 install -r requirements.txt
COPY pytheas pytheas 
COPY test_data_10_tables/simple_test test_data
WORKDIR /app/pytheas/src
RUN python3 setup.py sdist bdist_wheel
RUN python3 -m nltk.downloader stopwords
RUN pip3 install  --upgrade --force-reinstall dist/pytheas-0.0.1-py3-none-any.whl
WORKDIR /app
EOF

# Build docker-pytheas Docker image

docker build --tag docker-pytheas .

# Save image to Docker Hub

docker tag docker-pytheas karenjexphd/table_extraction_tests:docker-pytheas
docker push karenjexphd/table_extraction_tests:docker-pytheas

#-----   1c. create docker-hypoparsr image for Hypoparsr          -----#

mkdir ~/hypoparsr_dockerfiles
cd ~/hypoparsr_dockerfiles

# Clone necessary repos

git clone git@github.com:karenjexphd/hypoparsr.git
git clone git@github.com:karenjexphd/test_data_10_tables.git

# Create script to apply hypoparsr table extraction against given .csv file

cat > hypoparsr_apply_to_file.r << EOF
args = commandArgs(trailingOnly=TRUE)
input_file = args[1]
# call hypoparsr
res <- hypoparsr::parse_file(input_file)
# get result data frames
best_guess <- as.data.frame(res)
print(best_guess)
EOF

cat > hypoparsr_install.r << EOF
devtools::install_github("karenjexphd/hypoparsr")
EOF

# Create Dockerfile

cat > Dockerfile << EOF
# syntax=docker/dockerfile:1
FROM rocker/verse:3.6.0                  
WORKDIR /app
COPY hypoparsr_apply_to_file.r hypoparsr_apply_to_file.r
COPY hypoparsr_install.r hypoparsr_install.r
COPY hypoparsr hypoparsr
COPY test_data_10_tables/simple_test test_data
RUN Rscript hypoparsr_install.r
EOF

# Build docker-hypoparsr Docker image

docker build --tag docker-hypoparsr .

# Save image to Docker Hub

docker tag docker-hypoparsr karenjexphd/table_extraction_tests:docker-hypoparsr
docker push karenjexphd/table_extraction_tests:docker-hypoparsr


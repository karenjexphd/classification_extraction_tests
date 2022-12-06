#!/bin/bash

#-----------------------------------------------------------------------#
# Runtime commands to perform end to end table extraction tests         #
# Goal: compare the Pytheas, Hypoparsr and TabbyXL table extraction     #
#       against the Pytheas demo file using the Pytheas evaluation      #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#                         -- Prerequisites --                           #
#-----------------------------------------------------------------------#

# Docker images docker-pytheas, docker-hypoparsr and docker-tabby
# have been created and pushed to Docker Hub

# User performing tasks should be added to docker group:
#    sudo usermod -a -G <group> <username>
#    sudo usermod -a -G docker karen

# xlsx2csv utility used to help map Tabby output => Pytheas format
# installed via : sudo apt install xlsx2csv

#-----------------------------------------------------------------------#
#                            -- TO DO --                                #
#-----------------------------------------------------------------------#

# allow for multiple demo_a_n_n.xlsx files (multiple tables in input)
# loop through $outputdir and process all files with xlsx2csv

# automate remaining steps in mapping TabbyXL output to pytheas format

# use for-loop to evaluate each of the methods 

# remove previous containers only if cleanup_containers=Y
# remove previous output directories only if cleanup_outputdirs=Y

# print messages only if verbose mode chosen

# add usage/help/man to script

# replace "sleep 5" after steps to perform table extractions:
# alternatives:
#  i. remove "d" from -di in docker run commands. 
#      Container would no longer run in background
#     + : no need to check for processes to complete or to sleep
#     - : have to wait for each to complete before starting next
#  ii. loop to check that processes have completed before continuing
#     + : can run containers in background and therefore in parallel
#     - : more complex

#-----------------------------------------------------------------------#
#                           -- OVERVIEW --                              #
#-----------------------------------------------------------------------#

# Input file location:  /app/test_data (inside containers)
# Pytheas Input:        demo.csv
# Pytheas GT:           demo.json
# Tabby Input:          demo_a.xls   (annotated spreadsheet generated from demo.csv)

# Tasks:
# 1. Clean up from previous tests and setup for current test
# 2. Run table extractions
#   2a. Pytheas table extraction
#   2b. Hypoparsr table extraction
#   2c. TabbyXL table extraction
# 3. Map table extraction output to Pytheas discovered_tables format
#   3a. Hypoparsr output
#   3b. Tabby XL output (currently manual operation - to be automated)
# 4. Perform Pytheas evaluation on output from table extraction
#   4a. Evaluate Pytheas extracted tables
#   4b. Evaluate Hypoparsr extracted tables
#   4c. Evaluate TabbyXL extracted tables
# 5. Compare evaluation output for each method

#-----------------------------------------------------------------------#
#                            -- TASKS --                                #
#-----------------------------------------------------------------------#

echo INFO: Beginning tests : $(date)
today=$(date +"%d_%m_%Y")
export outputdir=/tmp/test_$today
echo INFO: Output will be written to $outputdir

#----- 1. Clean up from previous tests and setup for current test  -----#

#----- 1a. Set parameters                                          -----#

export methods="pytheas tabbyxl hypoparsr"

echo INFO: Methods to be processed: $methods

#----- 1b. Remove previous containers (just certain containers?)   -----#

echo
echo INFO: Removing previous containers...
docker rm -f `docker ps -aq`

#----- 1c. Create outputdir                                        -----#

echo
echo INFO: Removing previous outputdirs 

rm -rf /tmp/test*

echo
echo INFO: creating outputdir $outputdir
mkdir $outputdir

#-----------------------------------------------------------------------#

#----- 2. Run table extractions                                    -----#

# for each method:
#  - create container from docker-$method image
#  - run extract tables script
#  - tested logging in as current user via --user $(id -u):$(id -g)
#             - files no longer owned by root but:
#             - not necessary
#             - breaks Pytheas

#----- 2a. Pytheas table extraction                                -----#

# run pytheas_extract_tables.py against demo.csv
# will generate pytheas_tables.json (discovered_tables format) in $outputdir

echo
echo INFO: Running Pytheas table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 -di karenjexphd/table_extraction_tests:docker-pytheas \
 bash -c "python3 pytheas_extract_tables.py test_data/demo.csv \
          > outputdir/pytheas_tables.json"

#----- 2b. Hypoparsr table extraction                              -----#

# run hypoparsr table extraction on demo.csv
# will generate hypoparsr.out in $outputdir

echo
echo INFO: Running Hypoparsr table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 -di karenjexphd/table_extraction_tests:docker-hypoparsr \
 bash -c "Rscript hypoparsr_apply_to_file.r test_data/demo.csv \
          > outputdir/hypoparsr.out"

#----- 2c. Tabby table extraction                                  -----#

# run Tabby table extraction on demo_a.xlsx (annotated version of demo.csv)
# will generate demo_a_0_0.xlsx in $outputdir

echo
echo INFO: Running TabbyXL table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 -di karenjexphd/table_extraction_tests:docker-tabby \
 bash -c "java -Xmx1024m \
               -jar tabbyxl/target/TabbyXL-1.1.1-jar-with-dependencies.jar \
               -input test_data/demo_a.xlsx \
               -ruleset tabbyxl/examples/rules/smpl.crl \
               -output outputdir"

#-- ! TEMP - SLEEP 5 SECONDS TO ALLOW PROCESSES TO COMPLETE ! --#
echo
echo INFO: Waiting 5 seconds for processes to complete 
sleep 5 

#-----------------------------------------------------------------------#

# 3. Map output to Pytheas discovered_tables format

# create function write_discovered_tables with discovered_tables template

write_discovered_tables(){
  tables_out=$1
  ti_val=1	# table index: always 1 until support is added for multiple tables
  bb_val=$2
  de_val=$3
  ds_val=$4
  tb_val=$5
  cat > $tables_out << EOF
{   $ti_val: { 'aggregation_scope': {},
         'bottom_boundary': $bb_val,
         'columns': {   0: {'column_header': [], 'table_column': 0 }},
         'data_end': $de_val,
         'data_end_confidence': 1.0,
         'data_start': $ds_val,
         'fdl_confidence': {   'avg_confusion_index': 0.5,
                               'avg_difference': 0.5,
                               'avg_majority_confidence': 0.5,
                               'softmax': 0.5},
         'footnotes': [],
         'header': [],
         'subheader_scope': {},
         'top_boundary': $tb_val }}
EOF
}

# 3a. map Hypoparsr output

# Hypoparsr output is in tabular format with line numbers alongside the data rows
# data_end = max(first word in hypoparsr.out) - 1
# data_start = min(first word in hypoparsr.out) - 1
# in each case, ignore line(s) starting with blank space
# don't have a value for top boundary. Temporarily using data_start - 1

tables_in=${outputdir}/hypoparsr.out
tables_out=${outputdir}/hypoparsr_tables.json

de_val=$((`grep -v "^ " $tables_in | sort -g -r | awk '{print $1}' | head -1`-1))
bb_val=$de_val
ds_val=$((`grep -v "^ " $tables_in | sort -g | awk '{print $1}' | head -1`-1))
tb_val=$((ds_val - 1))

echo
echo INFO: Mapping Hypoparsr output to Pytheas discovered_tables format
echo "  Data end: " $de_val
echo "  Bottom boundary: " $bb_val 
echo "  Data start: " $ds_val
echo "  Top Boundary: " $tb_val

write_discovered_tables $tables_out $bb_val $de_val $ds_val $tb_val

# 3b. map TabbyXL output
#     (mapping is currently a manual operation - must be automated)

# first step in automating mapping:
# convert sheets 2 & 3 from tabby output to csv using xlsx2csv
# Note: this leaves the PROVENANCE column from both sheets empty
#       because the information from the hyperlinks isn't extracted

xlsx2csv -s 2 $outputdir/demo_a_0_0.xlsx $outputdir/demo_out_entries.csv
xlsx2csv -s 3 $outputdir/demo_a_0_0.xlsx $outputdir/demo_out_labels.csv

# data_start      = (min numeric part of 2nd col (PROVENANCE) from demo_out_entries.csv) -1 
# data_end        = (max numeric part of 2nd col (PROVENANCE) from demo_out_entries.csv) -1
# top_boundary    = (min numeric part of 2nd col (PROVENANCE) from demo_out_labels.csv) -1
# bottom_boundary = (max numeric part of 2nd col (PROVENANCE) from demo_out_labels.csv) -1

# temporary: hardcode values for bottom_boundary, top_boundary, data_start and data_end:

tables_out=$outputdir/tabbyxl_tables.json 
de_val=11 
bb_val=11 
ds_val=5 
tb_val=4 

echo
echo INFO: Mapping TabbyXL output to Pytheas discovered_tables format 
echo "  Data end: " $de_val 
echo "  Bottom boundary: " $bb_val 
echo "  Data start: " $ds_val 
echo "  Top Boundary: " $tb_val 

write_discovered_tables $tables_out $bb_val $de_val $ds_val $tb_val

# 4. Perform Pytheas evaluation on TabbyXL, Hypoparsr and Pytheas table extraction output

#    Parameters for pytheas_evaluate.py script:
#       1 (input): Ground truth for demo.csv
#       2 (input): discovered tables from associated table extraction 
#       3 (output): <method>_confusion.out
#       4 (output): <method>_confidences.out

for method in $methods
do
  echo
  echo INFO: Evaluating output for $method method
  tables_file=outputdir/${method}_tables.json
  confusion_file=outputdir/${method}_confusion.out
  confidences_file=outputdir/${method}_confidences.out
  docker run --mount type=bind,source=$outputdir,target=/app/outputdir \
             -di karenjexphd/table_extraction_tests:docker-pytheas \
             bash -c "python3 pytheas_evaluate.py \
                      test_data/demo.json $tables_file $confusion_file $confidences_file"
done

#-- ! TEMP - SLEEP 2 SECONDS TO ALLOW CONTAINERS TO COMPLETE TASKS ! --#
echo
echo INFO: Waiting 2 seconds for processes to complete 
sleep 2

# 5. Compare evaluation output for Pytheas, Hypoparsr and TabbyXL

# compare contents of $outputdir/*_confusion.out files (for each method in $methods)

docker run --mount type=bind,source=$outputdir,target=/app/outputdir \
             -i karenjexphd/table_extraction_tests:docker-pytheas \
             bash -c "python3 pytheas_compare.py \"$methods\" outputdir > outputdir/confusion_matrix_comparison.out"

echo
echo INFO: Comparison of table extraction evaluation for each method:
echo
cat $outputdir/confusion_matrix_comparison.out

echo
echo
echo INFO: Tests complete: `date`
echo INFO: Output written to $outputdir

# --------------------------------------------------------------------- #

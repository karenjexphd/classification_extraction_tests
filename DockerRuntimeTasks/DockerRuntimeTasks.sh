#!/bin/bash

#-----------------------------------------------------------------------#
# Runtime commands to perform end to end table extraction tests         #
# Goal: compare the Pytheas, Hypoparsr and TabbyXL table extraction     #
#       against the specified file using the Pytheas evaluation         #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#                   -- Process Input Parameters --                      #
#-----------------------------------------------------------------------#

# NOTE: Currently no checks in place to confirm that the files exist
#       Directory containing the files will be mounted to the container at runtime

while getopts 'p:c:x:g:h' OPTION; do
    case "$OPTION" in 
        p)
          filepath=$OPTARG
          ;;
        c)
          csv_input="$OPTARG"
          ;;
        x)
          xls_annotated_input="$OPTARG"
          ;;
        g)
          ground_truth=$OPTARG
          ;;
        h)
          echo "script usage: $0 [-p filepath] [-c csvfile] [-x xlsxfile] [-g ground_truth]"
          echo "-p   filepath:     path to input files"
          echo "                   default value: /app/test_data/pytheas_demo_file"
          echo
          echo "-c   csvfile:      name of input for Pytheas and Hypoparsr table extraction"
          echo "                   default value: demo.csv"
          echo
          echo "-x   xlsxfile:      name of (annotated) input for TabbyXL table extraction"
          echo "                   default value: demo_a.xlsx"
          echo
          echo "-g   ground_truth: name of file containing Pytheas ground truth"
          echo "                   default value: demo.json"
          echo
          exit 0
          ;;
        ?)
          echo "script usage: $0 [-p filepath] [-c csvfile] [-x xlsxfile] [-g ground_truth]"
          exit 1
          ;;
    esac
done

# DEFAULTS: 
#     Input file path: /app/test_data/pytheas_demo_file
#     Input files:     demo.csv    for Pytheas and Hypoparsr
#                      demo_a.xlsx annotated xlsx file for TabbyXL
#                      demo.json   ground truth data in Pytheas format

filepath=${filepath:-/app/test_data/pytheas_demo_file}
csv_input=${csv_input:-demo.csv}
xls_annotated_input=${xls_annotated_input:-demo_a.xlsx}
ground_truth=${ground_truth:-demo.json}

echo "File used for Pytheas and Hypoparsr table extraction: " $csv_input
echo "File used for TabbyXL table extraction: " $xls_annotated_input

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
# OR/
# xlsx2csv.py script available - add to one of the container images?
# Pytheas makes sense because it already has Python available

#-----------------------------------------------------------------------#
#                            -- TO DO --                                #
#-----------------------------------------------------------------------#

# automate remaining steps in mapping TabbyXL output to pytheas format

# use for-loop to evaluate each of the methods 

# remove previous containers only if cleanup_containers=Y
# remove previous output directories only if cleanup_outputdirs=Y

# print messages only if verbose mode chosen

#-----------------------------------------------------------------------#
#                           -- OVERVIEW --                              #
#-----------------------------------------------------------------------#

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

#----- 1. Clean up from previous tests and setup for current test  -----#

#----- 1a. Set parameters                                          -----#

echo INFO: Beginning tests : $(date)
today=$(date +"%d_%m_%Y")
export outputdir=/tmp/test_$today
echo INFO: Output will be written to $outputdir

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

#----- 2a. Pytheas table extraction                                -----#

# run pytheas_extract_tables.py against $csv_input file
# will generate pytheas_tables.json (discovered_tables format) in $outputdir

echo
echo INFO: Running Pytheas table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$filepath,target=/app/inputdir,readonly \
 -i karenjexphd/table_extraction_tests:docker-pytheas \
 bash -c "python3 pytheas_extract_tables.py inputdir/${csv_input} \
          > outputdir/pytheas_tables.json"

#----- 2b. Hypoparsr table extraction                              -----#

# run hypoparsr table extraction on demo.csv
# will generate hypoparsr.out in $outputdir

echo
echo INFO: Running Hypoparsr table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$filepath,target=/app/inputdir,readonly \
 -i karenjexphd/table_extraction_tests:docker-hypoparsr \
 bash -c "Rscript hypoparsr_apply_to_file.r inputdir/${csv_input} \
          > outputdir/hypoparsr.out"

#----- 2c. Tabby table extraction                                  -----#

# run Tabby table extraction on $xls_annotated_input (annotated version of $csv_input)
# will generate fileame_0_0.xlsx in $outputdir

echo
echo INFO: Running TabbyXL table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$filepath,target=/app/inputdir,readonly \
 -u 1000:1000 \
 -i karenjexphd/table_extraction_tests:docker-tabby \
 bash -c "java -Xmx1024m \
               -jar tabbyxl/target/TabbyXL-1.1.1-jar-with-dependencies.jar \
               -input inputdir/${xls_annotated_input} \
               -ruleset tabbyxl/examples/rules/smpl.crl \
               -output outputdir/tabby_out"

#-----------------------------------------------------------------------#

# 3. Map output to Pytheas discovered_tables format

# create function write_discovered_table based on discovered_tables template

write_discovered_table(){
  ti_val=$1      # table index
  bb_val=$2
  de_val=$3
  ds_val=$4
  tb_val=$5
  t_out=$6
  cat >> $t_out << EOF
  $ti_val: { 'aggregation_scope': {},
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
         'top_boundary': $tb_val } 
EOF
}

# 3a. map Hypoparsr output

# Hypoparsr output is in tabular format with line numbers alongside the data rows
#   data_end = max(first word in hypoparsr.out) - 1
#   data_start = min(first word in hypoparsr.out) - 1
# in each case, ignore line(s) starting with blank space
# don't have a value for top boundary. Temporarily using data_start - 1

tables_in=${outputdir}/hypoparsr.out
tables_out=${outputdir}/hypoparsr_tables.json

ti_val=1
de_val=$((`grep -v "^ " $tables_in | sort -g -r | awk '{print $1}' | head -1`-1))
bb_val=$de_val
ds_val=$((`grep -v "^ " $tables_in | sort -g | awk '{print $1}' | head -1`-1))
tb_val=$((ds_val - 1))

echo
echo INFO: Mapping Hypoparsr output to Pytheas discovered_tables format

echo "{" > $tables_out
write_discovered_table $ti_val $bb_val $de_val $ds_val $tb_val $tables_out
echo "}" >> $tables_out

# 3b. map TabbyXL output
#     (mapping is currently a manual operation - must be automated - still working on xls2csv)

# first step in automating mapping:
# convert sheets 2 & 3 from tabby output to csv using xlsx2csv
# Note: this leaves the PROVENANCE column from both sheets empty
#       because the information from the hyperlinks isn't extracted

echo
echo INFO: Mapping TabbyXL output to Pytheas discovered_tables format

tables_out=$outputdir/tabbyxl_tables.json

ti_val=0
echo "{" > $tables_out
# Loop through files generated by table extraction
for file in $(ls $outputdir/tabby_out)
do
  if [ $ti_val -gt 0 ]
  then
    echo "," >> $tables_out    # add a comma after each table
  fi  
  ((ti_val++))
  filename=$(basename -s .xlsx $file)

  python3 utils/xlsx2csv.py --hyperlinks -s 2 $outputdir/tabby_out/$file $outputdir/${filename}_entries.csv
  python3 utils/xlsx2csv.py --hyperlinks -s 3 $outputdir/tabby_out/$file $outputdir/${filename}_labels.csv

  # xlsx2csv -s 2 $file $outputdir/${filename}_entries.csv
  # xlsx2csv -s 3 $file $outputdir/${filename}_labels.csv

  # data_start      = (min numeric part of 2nd col (PROVENANCE) from filename_entries.csv) -1 
  # data_end        = (max numeric part of 2nd col (PROVENANCE) from filename_entries.csv) -1
  # top_boundary    = (min numeric part of 2nd col (PROVENANCE) from filename_labels.csv) -1
  # bottom_boundary = (max numeric part of 2nd col (PROVENANCE) from filename_labels.csv) -1

  # temporary: hardcode values for bottom_boundary, top_boundary, data_start and data_end:
  de_val=11 
  bb_val=11 
  ds_val=5 
  tb_val=4 

  write_discovered_table $ti_val $bb_val $de_val $ds_val $tb_val $tables_out
done
echo "}" >> $tables_out

# 4. Perform Pytheas evaluation on TabbyXL, Hypoparsr and Pytheas table extraction output

#    Parameters for pytheas_evaluate.py script:
#       1 (input): Ground truth file
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
   --mount type=bind,source=$filepath,target=/app/inputdir,readonly \
           -i karenjexphd/table_extraction_tests:docker-pytheas \
             bash -c "python3 pytheas_evaluate.py \
                      inputdir/${ground_truth} $tables_file $confusion_file $confidences_file"
done

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

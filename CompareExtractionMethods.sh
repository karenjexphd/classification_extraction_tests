#!/bin/bash

#-----------------------------------------------------------------------#
# Main script for framework to perform end to end comparison            #
# of table extraction methods against each others' data sets            #
# Methods currently available: Pytheas, Hypoparsr, TabbyXL              #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#                         -- Prerequisites --                           #
#-----------------------------------------------------------------------#

# 1.DOCKER IMAGES
 
# Docker images have been created and pushed to Docker Hub:
# docker-pytheas, docker-hypoparsr, docker-tabby, docker-strudel

# 2. DOCKER GROUP

# User performing tasks should be added to docker group:
#    sudo usermod -a -G docker <username>

# 3. TABLE MODEL DATABASE

# (Postgres) database exists, is up and running
# and is configured in ./config/classification_extraction_tests.cfg

#-----------------------------------------------------------------------#
#                            -- TO DO --                                #
#-----------------------------------------------------------------------#

# 1. CONTAINERS CLEANUP

# create a cleanup_containers flag
# remove previous containers only if cleanup_containers=Y 
# check that containers exist before attempting to delete
# only delete relevant containers

# 2. OUTPUTDIR CLEANUP

# create a cleanup_outputdirs flag
# remove previous output directories only if cleanup_outputdirs=Y

# 3. VERBOSE MODE

# print information (INFO) messages only if verbose mode chosen

# 4. ADDITIONAL METHODS

# write instructions for adding another method

#-----------------------------------------------------------------------#
#                   -- Process Input Parameters --                      #
#-----------------------------------------------------------------------#

# first apply defaults from conf file classification_extraction_tests.cfg 

source ./config/classification_extraction_tests.cfg

# next process input parameters (may overwrite parameters in conf file)

while getopts 'm:d:p:h' OPTION; do
    case "$OPTION" in 
        m)
          methods="$OPTARG"
          ;;
        d)
          dataset_method="$OPTARG"
          ;;
        p)
          filepath="$OPTARG"
          ;;
        h)
          echo "script usage: $0 [-m methods] [-p filepath]"
          echo "-m   methods:       list of methods to evaluate (double-quoted, blank space-separated list)"
          echo "                    accepted methods: pytheas, hypoparsr, tabbyxl, strudel"
          echo
          echo "-d   dataset_method: the name of the method associated with the available ground truth files"
          echo "-p   filepath:      path to input files."
          echo "                    expected structure: filepath/csv filepath/xlsx filepath/gt"
          echo
          exit 0
          ;;
        ?)
          echo "script usage: $0 [-m methods] [-p filepath]" 
          exit 1
          ;;
    esac
done

# set csv_filepath, xlsx_filepath and gt_filepath relative to filepath provided

csv_filepath=$filepath/csv         # path to input files for Pytheas and Hypoparsr
xlsx_filepath=$filepath/xlsx       # path to (annotated) input files for TabbyXL
gt_filepath=$filepath/gt           # path to files containing associated ground truth

#  Note: Required directories will be mounted to the containers at runtime

echo "INFO: Methods to be processed: " $methods
echo "INFO: Ground truth belongs to method: " $dataset_method
echo "INFO: root input file path: " $filepath
echo "INFO: csv input file path: " $csv_filepath
echo "INFO: xlsx input file path: " $xlsx_filepath
echo "INFO: ground truth file path: " $gt_filepath

#-----------------------------------------------------------------------#
#                           -- OVERVIEW --                              #
#-----------------------------------------------------------------------#

# Tasks:
# 1. Clean up from previous tests and setup for current test - DONE
# 2. Map GT to table model <-- NOTE - THIS STEP WILL DEPEND ON THE GT FORMAT
# 3. Run table extractions - DONE
# 4. Map output to table model <-- THIS STEP TO BE DONE FOR EACH METHOD
# 5. Evaluate extraction by comparing GT and output in table model
# 6. Display metrics to compare the methods 

#-----------------------------------------------------------------------#
#                            -- TASKS --                                #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#----- 1. Clean up from previous tests and setup for current test  -----#
#-----------------------------------------------------------------------#

#----- 1a. Set parameters                                          -----#

echo INFO: Beginning tests : $(date)
today=$(date +"%d_%m_%Y")
export outputdir=/tmp/test_$today
echo INFO: Output will be written to $outputdir

#----- 1b. Remove previous containers (just certain containers?)   -----#

echo
echo INFO: Removing previous containers... 

#docker rm -f `docker ps -aq`

for container in $(docker ps -aq)
do
  docker rm -f $container
done

#----- 1c. Create outputdir                                        -----#

echo
echo INFO: Removing previous outputdirs 

rm -rf /tmp/test*

echo
echo INFO: creating outputdir $outputdir
mkdir $outputdir

#---- 1d. Get list of base filenames (filename.csv with extension removed)

for file in $(ls $csv_filepath)
do
  if [[ $file == *.csv ]]
  then
    basefile=$(basename $file .csv) 
    if [[ ${#filenames} -eq 0 ]]
    then
        filenames=$basefile
    else
        filenames=${filenames}' '${basefile}
    fi
  fi
done

echo INFO: base filenames: $filenames

#--- 1e. Drop and re-create table_model database

$pg_conn_table_model -f tableModelDDL/00_drop_schema.sql

$pg_conn_table_model -f tableModelDDL/01_create_schema.sql
$pg_conn_table_model -f tableModelDDL/02_create_tables.sql
$pg_conn_table_model -f tableModelDDL/02b_create_indexes.sql
$pg_conn_table_model -f tableModelDDL/03_create_constraints.sql
$pg_conn_table_model -f tableModelDDL/04_create_views.sql
$pg_conn_table_model -f tableModelDDL/05_create_temp_tables.sql
#$pg_conn_table_model -f tableModelDDL/06_create_procedures.sql

# $pg_conn_table_model -c "TRUNCATE entry_label, label, entry, category, table_cell, source_table, entry_temp, label_temp, entry_label_temp"

#-----------------------------------------------------------------------#
#----- 2. Map ground truth to table model                          -----#
#-----------------------------------------------------------------------#

# NOTE: We will always use TabbyXL format Ground Truth
#       Can remove the dataset_method parameter and the logic around this

# Get address of $START and $END cells if this is a TabbyXL dataset 

if [[ $dataset_method == tabbyxl ]]
then
  input_file_path=$xlsx_filepath
  python3 utils/get_start_end.py $xlsx_filepath
fi

# Call map_${dataset_method}.py passing TRUE for "is_gt"

echo INFO: Mapping $dataset_method ground truth to table model
for file in $(ls $gt_filepath)
do
  echo INFO: Processing file ${gt_filepath}/${file}
  python3 MapToTableModel/map_${dataset_method}.py $gt_filepath $file 'TRUE'
done

#-----------------------------------------------------------------------#
#----- 3. Run table extractions                                    -----#
#-----------------------------------------------------------------------#

for method in $methods
do
  echo
  echo INFO: Extracting tables using $method method
  outputfiledir=${outputdir}/${method}
  mkdir $outputfiledir
  ./ExtractTables/extract_${method}.sh $outputfiledir $filepath
done

#-----------------------------------------------------------------------#
#----- 4. Map output to table model                                -----#
#-----------------------------------------------------------------------#

for method in $methods
do
  outputfiledir=${outputdir}/${method}
  echo
  echo INFO: Mapping $method extracted tables to table model 
  for file in $(ls $outputfiledir)
  do
    echo INFO: Processing extracted file ${outputfiledir}/${file}
    python3 ./MapToTableModel/map_${method}.py $outputfiledir $file 'FALSE'
  done
done

#-----------------------------------------------------------------------#
#----- 5. Evaluate output                                          -----#
#-----------------------------------------------------------------------#

# Compare GT against extracted tables for each method
# Generate confusion matrices

echo INFO: Evaluating extracted tables

$pg_conn_table_model -f EvaluateOutput/00_display_conf_matrix.sql


#-----------------------------------------------------------------------#
#----- 6. Display Graph(s)                                         -----#                
#-----------------------------------------------------------------------#

for method in $methods
do
  echo
  echo INFO: Plotting results for $method
  python3 ./utils/plot_results.py $outputdir $method
done

# --------------------------------------------------------------------- #

echo
echo INFO: Tests complete: `date`
echo INFO: Output written to $outputdir

# --------------------------------------------------------------------- #

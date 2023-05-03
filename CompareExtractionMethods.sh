#!/bin/bash

#-----------------------------------------------------------------------#
# Main script for framework to perform end to end comparison            #
# of table extraction methods against each others' data sets            #
# Methods currently compared: Pytheas, Hypoparsr, TabbyXL               #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#                         -- Prerequisites --                           #
#-----------------------------------------------------------------------#

# Docker images docker-pytheas, docker-hypoparsr and docker-tabby
# have been created and pushed to Docker Hub

# User performing tasks should be added to docker group:
#    sudo usermod -a -G docker <username>

#-----------------------------------------------------------------------#
#                            -- TO DO --                                #
#-----------------------------------------------------------------------#

# use for-loop to evaluate each of the methods

# remove previous containers only if cleanup_containers=Y and containers exist
# remove previous output directories only if cleanup_outputdirs=Y

# print messages only if verbose mode chosen

#-----------------------------------------------------------------------#
#                   -- Process Input Parameters --                      #
#-----------------------------------------------------------------------#

# apply defaults from classification_extraction_tests.cfg config file
# these may be overwritten by the input parameters provided to the script

source ./config/classification_extraction_tests.cfg

while getopts 'm:p:h' OPTION; do
    case "$OPTION" in 
        m)
          methods="$OPTARG"
          ;;
        p)
          filepath="$OPTARG"
          ;;
        h)
          echo "script usage: $0 [-m methods] [-p filepath]"
          echo "-m   methods:       list of methods to evaluate (double-quoted, blank space-separated list)"
          echo
          echo "-p   filepath:      path to input files."
          echo "                    default value: /app/test_data/tabby_10_files"
          echo "                    Expected structure: filepath/csv filepath/xlsx filepath/gt"
          echo
          exit 0
          ;;
        ?)
          echo "script usage: $0 [-m methods] [-p filepath]" 
          exit 1
          ;;
    esac
done

csv_filepath=$filepath/csv       # path to input files for Pytheas and Hypoparsr"
xlsx_filepath=$filepath/xlsx     # path to (annotated) input files for TabbyXL. Expects 1 per file in csv_filepath"
gt_filepath=$filepath/gt         # path to files containing associated ground truth"

#  Note: Required directories will be mounted to the containers at runtime

echo "INFO: Methods to be processed: " $methods
echo "INFO: root input file path: " $filepath
echo "INFO: csv input file path: " $csv_filepath
echo "INFO: xlsx input file path: " $xlsx_filepath
echo "INFO: ground truth file path: " $gt_filepath

#-----------------------------------------------------------------------#
#                           -- OVERVIEW --                              #
#-----------------------------------------------------------------------#

# Tasks:
# 1. Clean up from previous tests and setup for current test - DONE
# 2. Map GT to table model 
# 3. Run table extractions - DONE
# 4. Map output to table model 
# 5. Evaluate extraction by comparing GT and output 
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
docker rm -f `docker ps -aq`

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

#-----------------------------------------------------------------------#
#----- 2. Map ground truth to table model     TO DO                -----#
#-----------------------------------------------------------------------#

# for each method, process all gt files in gt_filepath/method

for method in $methods
do
  echo
  echo INFO: Mapping $method ground truth to table model
  method_gt_filepath=${gt_filepath}/${method}
  echo INFO: method_gt_filepath: $method_gt_filepath
  for file in $(ls $method_gt_filepath)
  do
    echo INFO: Processing file ${method_gt_filepath}/${file}
    python3 ./MapToTableModel/map_${method}_gt.py $method_gt_filepath $file
  done
done


exit


#-----------------------------------------------------------------------#
#----- 3. Run table extractions           COMPLETE                 -----#
#-----------------------------------------------------------------------#

for method in $methods
do
  echo
  echo INFO: Extracting tables using $method method
  ./ExtractTables/extract_${method}.sh $outputdir $filepath
done

#-----------------------------------------------------------------------#
#----- 4. Map output to table model                                -----#
#-----------------------------------------------------------------------#

for method in $methods
do
  echo
  echo INFO: Mapping $method ground truth to table model 
  method_gt_filepath=${gt_filepath}/${method}
  echo INFO: method_gt_filepath: $method_gt_filepath
#  for file in $(ls $method_gt_filepath)
#  do
#    echo INFO: Processing file $file
#    python3 map_${method}_gt.py $file
#  done
done



exit



### *** REMAINDER OF SCRIPT IS DIRECTLY COPIED FROM PREVIOUS VERSION - NOT TO BE USED AS-IS *** ###

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
  echo INFO: Ground truth dir is $gt_filepath

#  tables_file=outputdir/${method}_tables.json
#  confusion_file=outputdir/${method}_confusion.out
#  confidences_file=outputdir/${method}_confidences.out

  # Run the pytheas evaluate script on each of the _method_tables.json files in outputdir

  docker run --mount type=bind,source=$outputdir,target=/app/outputdir \
   --mount type=bind,source=$gt_filepath,target=/app/gtdir,readonly \
           -i karenjexphd/table_extraction_tests:docker-pytheas \
             bash -c "./pytheas_evaluate_tables.sh gtdir outputdir $method"

done

# 5. Compare evaluation output for Pytheas, Hypoparsr and TabbyXL

# compare contents of $outputdir/*_confusion.out files 
#   for each method in $methods
#   and for each file in filenames

# ** NEED SHELL SCRIPT TO GO THROUGH ALL FILES (ADD TO DOCKER IMAGE) **

docker run --mount type=bind,source=$outputdir,target=/app/outputdir \
             -i karenjexphd/table_extraction_tests:docker-pytheas \
             bash -c "python3 pytheas_compare.py \"$methods\" \"$filenames\" outputdir > outputdir/confusion_matrix_comparison.out"

echo
echo INFO: Comparison of table extraction evaluation for each method:
echo
cat $outputdir/confusion_matrix_comparison.out

echo
echo
echo INFO: Tests complete: `date`
echo INFO: Output written to $outputdir

# --------------------------------------------------------------------- #

#!/bin/bash

#-----------------------------------------------------------------------#
# Runtime commands to perform end to end table extraction tests         #
# Goal: compare the Pytheas, Hypoparsr and TabbyXL table extraction     #
#       against the specified files using the Pytheas evaluation        #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
# NEW VERSION OF DockerRuntimeTasks.sh with support for multiple files  #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#                   -- Process Input Parameters --                      #
#-----------------------------------------------------------------------#

# NOTES: 
#  Currently no checks in place to confirm that the directories or files exist
#  Directories containing the files will be mounted to the container at runtime

while getopts 'p:c:x:g:h' OPTION; do
    case "$OPTION" in 
        p)
          filepath="$OPTARG"
          ;;
        c)
          csv_filepath="$OPTARG"
          ;;
        x)
          xlsx_filepath="$OPTARG"
          ;;
        g)
          gt_filepath="$OPTARG"
          ;;
        h)
          echo "script usage: $0 [-p filepath] [-c csv_filepath] [-x xlsx_filepath] [-g gt_filepath]"
          echo "-p   filepath:      path to input files."
          echo "                    default value: /app/test_data/tabby_10_files"
          echo
          echo "-c   csv_filepath:  path to files for Pytheas and Hypoparsr table extraction"
          echo "                    default value: filepath/csv"
          echo
          echo "-x   xlsx_filepath: path to (annotated) files for TabbyXL table extraction. Expects 1 file per file in csv_filepath"
          echo "                    default value: filepath/xlsx"
          echo
          echo "-g   gt_filepath:   path to files containing Pytheas ground truth. Expects 1 file per file in csv_filepath"
          echo "                    default value: filepath/gt"
          echo
          exit 0
          ;;
        ?)
          echo "script usage: $0 [-p filepath] [-c csv_filepath] [-x xlsx_filepath] [-g gt_filepath]" 
          exit 1
          ;;
    esac
done

# DEFAULTS: 

filepath=${filepath:-/app/test_data/tabby_10_files}
csv_filepath=${csv_filepath:-$filepath/csv} 
xlsx_filepath=${xlsx_filepath:-$filepath/xlsx}
gt_filepath=${gt_filepath:-$filepath/gt} 

echo "INFO: csv input file path: " $csv_filepath
echo "INFO: xlsx input file path: " $xlsx_filepath
echo "INFO: ground truth file path: " $gt_filepath

#-----------------------------------------------------------------------#
#                         -- Prerequisites --                           #
#-----------------------------------------------------------------------#

# Docker images docker-pytheas, docker-hypoparsr and docker-tabby
# have been created and pushed to Docker Hub

# User performing tasks should be added to docker group:
#    sudo usermod -a -G <group> <username>
#    sudo usermod -a -G docker karen

#-----------------------------------------------------------------------#
#                            -- TO DO --                                #
#-----------------------------------------------------------------------#

# use for-loop to evaluate each of the methods 

# remove previous containers only if cleanup_containers=Y and containers exist
# remove previous output directories only if cleanup_outputdirs=Y

# print messages only if verbose mode chosen

# process mutiple input files (specify a file path instead of a single file)

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

# export methods="pytheas tabbyxl hypoparsr"
export methods="pytheas tabby hypoparsr"

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

#----- 2. Run table extractions                                    -----#

#----- 2a. Pytheas table extraction                                -----#

# run pytheas_extract_tables.py against csv files in $csv_filepath
# will generate basefilename_pytheas_tables.json in $outputdir for each file

echo
echo INFO: Running Pytheas table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$csv_filepath,target=/app/inputdir,readonly \
 -i karenjexphd/table_extraction_tests:docker-pytheas \
 bash -c "./pytheas_extract_tables.sh inputdir outputdir"

#----- 2b. Hypoparsr table extraction                              -----#

# run hypoparsr table extraction on csv files in $csv_filepath
# will generate basefilename_hypoparsr.out in $outputdir for each file

echo
echo INFO: Running Hypoparsr table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$csv_filepath,target=/app/inputdir,readonly \
 -i karenjexphd/table_extraction_tests:docker-hypoparsr \
 bash -c "./call_hypoparsr_apply_to_file.sh inputdir outputdir"

#----- 2c. Tabby table extraction                                  -----#

# run Tabby table extraction on annotated xlsx files in $xlsx_filepath
# will generate basefilename_tabby.xlsx in $outputdir for each file

echo
echo INFO: Running TabbyXL table extraction

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$xlsx_filepath,target=/app/inputdir,readonly \
 -u 1000:1000 \
 -i karenjexphd/table_extraction_tests:docker-tabby \
 bash -c "./call_tabby_extraction.sh inputdir outputdir"

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

# NOTE:
#   ignore line(s) in xx_hypoparsr.out files that start with blank space
#   TEMP: ignore line(s) starting with < (indicates error during table extraction)

#   data_end     : max(first word in hypoparsr.out) - 1
#   data_start   : min(first word in hypoparsr.out) - 1
#   top_boundary : data_start - 1                       # don't have actual value for this

echo
echo INFO: Mapping Hypoparsr output to Pytheas discovered_tables format

for file in $(ls $outputdir)
# process all *_hypoparsr.out files in $outputdir
do
  if [[ $file == *hypoparsr.out ]]
  then
    inputfile=${outputdir}/${file}                    # full path to x_hypoparsr.out file
    basefile=$(basename $file .out)                   # x_hypoparsr (.out removed)
    outputfile=${outputdir}/${basefile}_tables.json   # full path to x_hypoparsr_tables.json (discovered tables file)

    ti_val=1                                          # table index value currently hardcoded to 1

        # grep -v "^ \|<"  : exclude lines starting with space or <
        # awk '{print $1}' : work with just first word of each line
        # sort -g -r       : sort numerically in reverse order
        # head -1          : get first value in list (ie highest value because reversed)

    de_val=$((`grep -v "^ \|<" $inputfile | sort -g -r | awk '{print $1}' | head -1`-1))
    bb_val=$de_val
    ds_val=$((`grep -v "^ \|<" $inputfile | sort -g | awk '{print $1}' | head -1`-1))
    tb_val=$((ds_val - 1))

    echo "{" > $outputfile
    write_discovered_table $ti_val $bb_val $de_val $ds_val $tb_val $outputfile
    echo "}" >> $outputfile

  fi
done

# 3b. map TabbyXL output

echo
echo INFO: Mapping TabbyXL output to Pytheas discovered_tables format

#for folder in $(ls $outputdir)                                  # loop through contents of $outputdir
#do
#  folderpath=${outputdir}/${folder}                             # get full path of this item in $outputdir 
#  if [[ $folder == *_tabby_out ]] && [ -d $folderpath ]         # only process if it's a directory and its name ends _tabby_out
#  then
#    folder_basename=$(basename -s _tabby_out $folder)             # get name of original input file by removing _tabby_out from dir name
#    tables_out=$outputdir/${folder_basename}_tabby_tables.json  # write the discovered_tables output to _tabby_tables.json
#    ti_val=0                                                    # start with table index (ti) 0
#    echo "{" > $tables_out                                      # begin writing the discovered_tables json to the _tabby_tables.json
#    for file in $(ls $folderpath)                               # Loop through the files in this folder
#                                                                #   (each file contains output for 1 table in the input file)
#    do                                                            
#      if [ $ti_val -gt 0 ]                                      # If we're not at the first table
#      then
#        echo "," >> $tables_out                                 # add a comma (want a comma after each table)
#      fi
#      ((ti_val++))                                              # increase the table index
#      full_filename=${folderpath}/${file}
#      python3 utils/write_tabby_discovered_table.py $full_filename $tables_out $ti_val # call the write_tabby_discovered_table script
#                                                                                       # to add discovered_tables format of the table
#                                                                                       # to discovered_tables file ($tables_out)
#    done
#    echo "}" >> $tables_out                                     # end the discovered_tables json with a final bracket
#  fi
#done

for file in $(ls $outputdir)                               # process all *_tabby_out.xlsx files in $outputdir
do
  if [[ $file == *tabby_out.xlsx ]]
  then
    inputfile=${outputdir}/${file}                         # full path to <basefile>_tabby_out.xlsx file
    basefile=$(basename $file _out.xlsx)                   # *_tabby (<basefile>_out.xlsx removed)
    outputfile=${outputdir}/${basefile}_tables.json        # full path to <basefile>_tabby_tables.json (discovered tables file)
    echo "{" > $outputfile                                 # begin writing the discovered_tables json to the <basefile>_tabby_tables.json
    ti_val=1                                               # assume single table per file = table index will always be 1
    python3 utils/write_tabby_discovered_table.py $inputfile $outputfile $ti_val   # call the write_tabby_discovered_table script
    echo "}" >> $outputfile
  fi
done

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

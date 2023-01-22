#!/bin/bash

#-----------------------------------------------------------------------#
#    Commands to prepare data prior to table extraction tests           #
#    Goal: Take TabbyXL spreadsheet(s) as input and generate:           #
#          - csv files for input to Pytheas and Hypoparsr               #
#          - Pytheas-format ground truth files                          #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#                   -- Process Input Parameters --                      #
#-----------------------------------------------------------------------#

# NOTE: Currently no checks in place to confirm that the files exist

while getopts 'p:h' OPTION; do
    case "$OPTION" in 
        p)
          filepath=$OPTARG
          ;;
        h)
          echo "script usage: $0 [-p filepath]"
          echo "-p   filepath:     path to input files"
          echo "                   default value: /app/test_data/pytheas_demo_file"
          exit 0
          ;;
        ?)
          echo "script usage: $0 [-p filepath]"
          exit 1
          ;;
    esac
done

echo "processing files in filep path" $filepath

#-----------------------------------------------------------------------#
#                           -- OVERVIEW --                              #
#-----------------------------------------------------------------------#

# Tasks:

# For each .xslx file in filepath
#     For each sheet in file
#         write data as .csv file
#         generate Pytheas format Ground Truth file

#-----------------------------------------------------------------------#
#                            -- TASKS --                                #
#-----------------------------------------------------------------------#

# Loop through .xlsx files in filepath and generate csv from data (using convert_to_csv.py)
for file in $(ls $filepath)
do
  echo $filepath $file
  python3 utils/convert_to_csv.py $filepath $file

done

# --------------------------------------------------------------------- #

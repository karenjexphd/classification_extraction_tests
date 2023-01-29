#!/bin/bash

filepath=$1
echo "processing files in file path" $filepath

# Loop through .xlsx files in filepath and generate pytheas ground truth

for file in $(ls $filepath)
do
  if [[ $file == *.xlsx ]]
  then
    basefile=$(basename $file .xlsx)
    inputfile=${filepath}/${file}
    ground_truth_file=${filepath}/${basefile}.json
    python3 utils/write_pytheas_gt.py $inputfile $ground_truth_file
  fi
done

#!/bin/bash

#-----------------------------------------------------------------------#
# Runtime commands to map GT to our table model for each system         #
#-----------------------------------------------------------------------#

# TO DO

# Changes to database tables: add unique identifier for each file that's processed?

# first, manually translate one or more GT files for each system to test the model
# then, automate the translation for one system at a time

#-----------------------------------------------------------------------#
#                   -- Process Input Parameters --                      #
#-----------------------------------------------------------------------#

# Assumes config file is found in classification_extraction_tests/config/classification_extraction_tests.cfg
source ../../config/classification_extraction_tests.cfg

echo $methods
echo $gt_filepath

for method in $methods
do
  echo
  echo INFO: Translating GT to table model for $method method
  method_gt_filepath=$gt_filepath/$method
  echo INFO: GT files in $method_gt_filepath
  for file in $(ls $method_gt_filepath)
  do
    echo INFO: Processing file $file
    # CODE TO ACTUALLY MAP THE GT INTO THE TABLE MODEL
    python3 map_${method}_gt.py $file
  done
done
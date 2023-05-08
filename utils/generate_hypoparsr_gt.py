import sys 
import feather 
import os
import pandas as pd

# input:  path to input files. e.g. /my/test/files
# output: filename.csv.feather file in /my/test/files/gt/hypoparsr for each filename.csv file in /my/test/files/csv

# Goals: 
#   Generate Hypoparsr GT feather file for each csv file in input directory

#sample input file path for for testing
#input_filepath = "/home/karen/workspaces/classification_extraction_tests/test_files/tabby_10_files"

input_filepath = str(sys.argv[1])               # path to (root of) input files: eg /test_files/tabby_10_files
input_csv_filepath = input_filepath+"/csv"      # path to csv input files
output_gt_filepath = input_filepath+"/gt/hypoparsr"

files=os.listdir(input_csv_filepath)

for file in files:
    input_file=input_csv_filepath+"/"+file
    output_file=output_gt_filepath+"/"+file+".feather"
    print(output_file)
    df = pd.read_csv(input_file)
    # print(df)
    df.to_feather(output_file)
import sys 
import psycopg2
import feather 
from io import StringIO

# Goals: 
#   View Hypoparsr (feather format) output file for testing or debugging

# 1. Process input parameters:

input_file="/tmp/test_09_10_2023/hypoparsr/C10001.csv.feather"

df = feather.read_dataframe(input_file) 
print(df)
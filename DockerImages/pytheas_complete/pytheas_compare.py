# Create Python script to compare table extraction evaluations

# input:  argv[1] list of methods (separated by white space, eg "method1 method2 method3")
#         argv[2] list of files (separated by white space, eg "C10001 C10002")
#         argv[3] desired output directory
# output: printed output : table confusion matrix for each method in tabular format

import sys
import json

filedir = str(sys.argv[3])
comparison_table = []  # define comparison table as empty list

keys = []
vals = []

methods = str(sys.argv[1])      # get string containing list of methods from input
filenames = str(sys.argv[2])    # get string containing list of filenames from input
method_list = methods.split()   # split string to get list of methods
file_list = filenames.split()   # split string to get list of files

for file in file_list:
    print(file)
    for method in method_list:      # process confusion matrix file for each method
        conf_file=filedir+"/"+file+"_"+method+"_confusion.out"
        with open(conf_file) as f:  # open the file and process the confusion matrix
            confusion_matrix = f.read()  
            confusion_info=json.loads(confusion_matrix) # convert confusion matrix to json
            val = []
            keys.append('file')
            val.append(file)
            keys.append('method')
            val.append(method)
            for k,v in confusion_info.items():
                keys.append(k)
                val.append(v)
            vals.append(val)

# print comparison_table

print(list(dict.fromkeys(keys)))
for v in vals:
    print(v)
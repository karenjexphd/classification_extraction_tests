# Create script to perform just extract_tables() to get discovered_tables

# input:  argv[1] directory containing input (csv) files
#         argv[2] filename of csv file being processed

import sys
import json
from nltk.corpus import stopwords
from pytheas import pytheas
from pprint import pprint
import pytheas.file_utilities as file_utils

mypytheas = pytheas.PYTHEAS()
mypytheas.load_weights('/app/pytheas/src/pytheas/trained_rules.json')
blank_lines = []

inputdir = str(sys.argv[1])
filename = str(sys.argv[2])
inputfile = inputdir + "/" + filename

file_dataframe=file_utils.get_dataframe(inputfile, None)
file_dataframe_trimmed=file_dataframe
discovered_tables = mypytheas.extract_tables(file_dataframe_trimmed, blank_lines)

pprint(discovered_tables)
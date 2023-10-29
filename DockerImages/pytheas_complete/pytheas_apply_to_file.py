# Create Python script to apply pytheas table extraction against given .csv file

import sys
from nltk.corpus import stopwords
from pytheas import pytheas
from pprint import pprint
Pytheas = pytheas.API()
Pytheas.load_weights('/app/pytheas/src/pytheas/trained_rules.json')
filepath = str(sys.argv[1])
file_annotations = Pytheas.infer_annotations(filepath)
pprint(file_annotations)
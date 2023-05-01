# classification_extraction_tests

The classification_extraction_tests repository contains a Framework 
to allow comparison of different table extraction tools. 

The tools currently included are:

* [Pytheas](https://github.com/cchristodoulaki/Pytheas)
* [Hypoparsr](https://github.com/tdoehmen/hypoparsr)
* [TabbyXL](https://github.com/tabbydoc/tabbyxl)

## Usage

### Run table extraction for all available mathods against a single input file 

DockerRuntimeTasks/DockerRuntimeTasks.sh [-p filepath] [-c csvfile] [-x xlsxfile] [-g ground_truth]"

* filepath:     path to input files (default value: /app/test_data/pytheas_demo_file)
* csvfile:      name of input for Pytheas and Hypoparsr table extraction (default value: demo.csv)
* xlsxfile:     name of (annotated) input for TabbyXL table extraction (default value: demo_a.xlsx)
* ground_truth: name of file containing Pytheas ground truth (default value: demo.json)

e.g. run against tabbyXL demo file smpl.xlsx:

./DockerRuntimeTasks/DockerRuntimeTasks.sh -p /app/test_data/tabby_demo_file -c smpl.csv -x smpl.xlsx -g smpl.json 

### Run table extraction for all available methods against set of input files

** This script replaces the DockerRuntimeTasks/DockerRuntimeTasks.sh script, which is now obsolete **

DockerRuntimeTasks/RunExtractionTests.sh [-p filepath] [-c csv_filepath] [-x xlsx_filepath] [-g gt_filepath]

* filepath:      path to input files (default value: /app/test_data/tabby_10_files)
* csv_filepath:  path to files for Pytheas and Hypoparsr table extraction (default value: filepath/csv)
* xlsx_filepath: path to (annotated) files for TabbyXL table extraction. Expects 1 file per file in csv_filepath (default value: filepath/xlsx)
* gt_filepath:   path to files containing Pytheas ground truth. Expects 1 file per file in csv_filepath (default value: filepath/gt)


## The following folders containing scripts/utilities have been created:

### DockerImages 

The DockerImages folder contains files required to create Docker images to test the table extraction methods 
(currently Pytheas, Hypoparsr and TabbyXL)

The images include the required
* runtime environment
* test files
* scripts
to test the table extraction method against a given input file

### DockerRuntimeTasks

** THIS FOLDER WILL BE REPLACED BY A SET OF FOLDERS, EACH CONTAINING A DIFFERENT UTILITY **

DockerRuntimeTasks contains scripts that use the DockerImages to run end-to-end table extraction tests

e.g. RunExtractionTests.sh
Contains commands required to perform end-to-end table extraction test
to compare Pytheas, Hypoparar and TabbyXL table extraction against files provided as input
using the Pytheas evaluation method

This is an updated version of DockerRuntimeTasks.sh, that includes support for multiple files  


### tableModelDDL

Contains DDL that creates the table_model schema, creating the tables, views and procedures required
to map the Ground Truth and extracted tables for each method into a relational database model

### map_to_table_model

Folder contains Python scripts that map a given input (Ground Truth) file to the shared table model


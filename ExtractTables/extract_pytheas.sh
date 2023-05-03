#-----------------------------------------------------------------------#
#----- Pytheas table extraction                                    -----#
#-----------------------------------------------------------------------#

# run pytheas_extract_tables.py against set of (csv) input files
# will generate basefilename_pytheas_tables.json in $outputdir for each file

outputdir=$1
filepath=$2
csv_filepath=${filepath}/csv

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$csv_filepath,target=/app/inputdir,readonly \
 -i karenjexphd/table_extraction_tests:docker-pytheas \
 bash -c "./pytheas_extract_tables.sh inputdir outputdir"

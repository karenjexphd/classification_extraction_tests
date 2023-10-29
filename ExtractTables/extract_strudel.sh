#-----------------------------------------------------------------------#
#----- Strudel table extraction                                    -----#
#-----------------------------------------------------------------------#

# run strudel_extract_tables.sh against set of input files
# will generate xxx.csv in $outputdir 

outputdir=$1
filepath=$2
csv_filepath=${filepath}/csv

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$csv_filepath,target=/app/inputdir,readonly \
 -i karenjexphd/table_extraction_tests:docker-strudel \
 bash -c "./strudel_extract_tables.sh inputdir outputdir"
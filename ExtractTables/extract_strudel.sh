#-----------------------------------------------------------------------#
#----- Strudel table extraction                                    -----#
#-----------------------------------------------------------------------#

# run strudel_extract_tables.sh against set of input files
# will generate xxx.csv in $outputdir 

outputdir=$1
filepath=$2

dataset_name=$(basename $filepath) # the data set is named after the directory containing the data files

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$filepath,target=/app/inputdir,readonly \
 -i karenjexphd/table_extraction_tests:docker-strudel \
 bash -c "./strudel_extract_tables.sh /app/inputdir /app/outputdir $dataset_name"
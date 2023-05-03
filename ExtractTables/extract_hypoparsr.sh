#-----------------------------------------------------------------------#
#----- Hypoparsr table extraction                                  -----#
#-----------------------------------------------------------------------#

# run call_hypoparsr_apply_to_file.sh against set of (csv) input files
# will generate basefilename_hypoparsr.out in $outputdir for each file

outputdir=$1
filepath=$2
csv_filepath=${filepath}/csv

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$csv_filepath,target=/app/inputdir,readonly \
 -i karenjexphd/table_extraction_tests:docker-hypoparsr \
 bash -c "./call_hypoparsr_apply_to_file.sh inputdir outputdir"

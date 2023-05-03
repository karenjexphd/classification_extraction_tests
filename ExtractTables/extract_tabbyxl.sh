#-----------------------------------------------------------------------#
#----- Tabby table extraction                                      -----#
#-----------------------------------------------------------------------#

# run call_tabby_extraction.sh against set of (annotated xlsx) input files
# will generate basefilename_tabby_out.xls in $outputdir for each file

outputdir=$1
filepath=$2
xlsx_filepath=${filepath}/xlsx

docker run \
 --mount type=bind,source=$outputdir,target=/app/outputdir \
 --mount type=bind,source=$xlsx_filepath,target=/app/inputdir,readonly \
 -u 1000:1000 \
 -i karenjexphd/table_extraction_tests:docker-tabby \
 bash -c "./call_tabby_extraction.sh inputdir outputdir"

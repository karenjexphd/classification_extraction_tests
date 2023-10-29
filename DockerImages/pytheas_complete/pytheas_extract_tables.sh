# Create script to call pytheas table extraction for each csv file in input directory

inputdir=\$1
outputdir=\$2
for file in \$(ls \$inputdir)
do
  if [[ \$file == *.csv ]]
  then
    basefile=\$(basename \$file .csv)
    outputfile=\${outputdir}/\${basefile}.json
    python3 pytheas_extract_tables.py \$inputdir \$file > \$outputfile
  fi
done

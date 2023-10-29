# script to call hypoparsr extraction script for each file in given directory

inputdir=$1
outputdir=$2
for file in $(ls $inputdir)
do
  if [[ $file == *.csv ]]
  then
    inputfile=$inputdir/$file
    basefile=$(basename $file .csv)
    # outputfile=\${outputdir}/\${basefile}_hypoparsr.out
    outputfile=${outputdir}/${basefile}.csv.feather
    # Rscript hypoparsr_apply_to_file.r \$inputfile > \$outputfile
    Rscript hypoparsr_apply_to_file.r $inputfile $outputfile
  fi
done
# shell script to call pytheas_evaluate against all files for given method in a given folder

gtdir=\$1
outputdir=\$2
method=\$3
for file in \$(ls \$outputdir)
do
  echo "processing file \${file} for method \${method}"
  if [[ \$file == *\${method}_tables.json ]]
  then
    basefile=\$(basename \$file _\${method}_tables.json)  # remove _method_tables.json
    gt_file=\${gtdir}/\${basefile}.json
    tables_file=outputdir/\${file}
    confusion_file=outputdir/\${basefile}_\${method}_confusion.out
    confidences_file=outputdir/\${basefile}_\${method}_confidences.out
    echo "calling pytheas_evaluate with gt file \${gt_file}, discovered tables file \${file}, and writing to \${confusion_file} and \${confidences_file}"
    python3 pytheas_evaluate.py \$gt_file \$tables_file \$confusion_file \$confidences_file
  fi
done
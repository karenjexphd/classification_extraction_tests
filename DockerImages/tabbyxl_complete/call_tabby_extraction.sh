#!/bin/bash

# Script to call TabbyXL extraction for each file in given directory

inputdir=\$1
outputdir=\$2
for file in \$(ls \$inputdir)
do
  if [[ \$file == *.xlsx ]]
  then
    inputfile=\${inputdir}/\${file}
    echo "Processing file " \$inputfile
    basefile=\$(basename \$file .xlsx)
    # outputfiledir=\${outputdir}/\${basefile}_tabby_out
    # replace tabbyxl/examples/rules/smpl.crl with test_data/tabby_200_rules.crl
    java -Xmx1024m -jar tabbyxl/target/TabbyXL-1.1.1-jar-with-dependencies.jar \\
         -input \$inputfile -ruleset test_data/tabby_200_rules.crl -output \$outputdir
    # copy created file $basefile_0_0.xlsx to $basefile_tabby_out.xlsx 
    # (assuming one sheet and one table per file)
    mv \${outputdir}/\${basefile}_0_0.xlsx \${outputdir}/\${basefile}.xlsx
  fi
done
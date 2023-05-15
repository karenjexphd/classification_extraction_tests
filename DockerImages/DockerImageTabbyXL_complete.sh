#-----------------------------------------------------------------------#
# File to create TabbyXL Docker image containing required scripts       #
# image based on karenjexphd/table_extraction_tests:docker-tabby-base   #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

mkdir /tmp/tabby_dockerfiles
cd /tmp/tabby_dockerfiles

# Create script to call TabbyXL extraction for each file in given directory

cat > call_tabby_extraction.sh << EOF
#!/bin/bash
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
    java -Xmx1024m -jar tabbyxl/target/TabbyXL-1.1.1-jar-with-dependencies.jar \\
         -input \$inputfile -ruleset tabbyxl/examples/rules/smpl.crl -output \$outputdir
    # copy created file $basefile_0_0.xlsx to $basefile_tabby_out.xlsx 
    # (assuming one sheet and one table per file)
    mv \${outputdir}/\${basefile}_0_0.xlsx \${outputdir}/\${basefile}.xlsx
  fi
done
EOF

# Create Dockerfile - image based on karenjexphd/table_extraction_tests:docker-tabby-base

cat > Dockerfile << EOF
FROM karenjexphd/table_extraction_tests:docker-tabby-base
COPY call_tabby_extraction.sh call_tabby_extraction.sh
RUN chmod +x call_tabby_extraction.sh
EOF

# Build docker-tabby Docker image
docker build --tag docker-tabby .

# Save image to Docker Hub
docker tag docker-tabby karenjexphd/table_extraction_tests:docker-tabby
docker push karenjexphd/table_extraction_tests:docker-tabby

rm -rf /tmp/tabby_dockerfiles

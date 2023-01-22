#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-tabby containing TabbyXL runtime environment                 #
# See DockerSetup.sh for prerequisites                                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

mkdir /tmp/tabby_dockerfiles
cp -r test_files /tmp/tabby_dockerfiles
cd /tmp/tabby_dockerfiles

# Clone TabbyXL repo

git clone git@github.com:karenjexphd/tabbyxl.git

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
    outputfiledir=\${outputdir}/\${basefile}_tabby_out
    java -Xmx1024m -jar tabbyxl/target/TabbyXL-1.1.1-jar-with-dependencies.jar \\
         -input \$inputfile -ruleset tabbyxl/examples/rules/smpl.crl -output \$outputfiledir
  fi
done
EOF

# Create Dockerfile - image based on rockylinux 8

cat > Dockerfile << EOF
FROM rockylinux:8
WORKDIR /app
COPY tabbyxl tabbyxl
COPY test_files test_data
COPY call_tabby_extraction.sh call_tabby_extraction.sh
RUN yum -y update
RUN yum -y install git maven
RUN mvn -f ./tabbyxl/pom.xml clean install
RUN sed -i 's/java /java -Xmx1024m /' tabbyxl/test.sh
RUN chmod +x tabbyxl/test.sh
RUN chmod +x call_tabby_extraction.sh
EOF

# Build docker-tabby Docker image
docker build --tag docker-tabby .

# Save image to Docker Hub
docker tag docker-tabby karenjexphd/table_extraction_tests:docker-tabby
docker push karenjexphd/table_extraction_tests:docker-tabby

rm -rf /tmp/tabby_dockerfiles

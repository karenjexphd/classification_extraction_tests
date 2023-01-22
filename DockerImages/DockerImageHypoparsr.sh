#-----------------------------------------------------------------------#
# File containing instructions for creating Docker images               #
#   docker-tabby containing TabbyXL runtime environment                 #
# See DockerSetup.sh for prerequisites                                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

mkdir /tmp/hypoparsr_dockerfiles
cp -r test_files /tmp/hypoparsr_dockerfiles
cd /tmp/hypoparsr_dockerfiles

echo "INFO: Cloning hypoparsr repo"

git clone git@github.com:karenjexphd/hypoparsr.git

echo "INFO: Creating script to apply hypoparsr table extraction against given .csv file"

cat > hypoparsr_apply_to_file.r << EOF
args = commandArgs(trailingOnly=TRUE)
input_file = args[1]
# call hypoparsr
res <- hypoparsr::parse_file(input_file)
# get result data frames
best_guess <- as.data.frame(res)
print(best_guess)
EOF

echo "INFO: Creating script to call hypoparsr extraction script for each file in given directory"

cat > call_hypoparsr_apply_to_file.sh << EOF
inputdir=\$1
outputdir=\$2
for file in \$(ls \$inputdir)
do
  if [[ \$file == *.csv ]]
  then
    inputfile=\$inputdir/\$file
    basefile=\$(basename \$file .csv)
    outputfile=\${outputdir}/\${basefile}_hypoparsr.out
    Rscript hypoparsr_apply_to_file.r \$inputfile > \$outputfile
  fi
done
EOF

chmod u+x call_hypoparsr_apply_to_file.sh

echo "INFO: Creating hypoparsr install script"

cat > hypoparsr_install.r << EOF
devtools::install_github("karenjexphd/hypoparsr")
EOF

echo "INFO: Creating Dockerfile"

cat > Dockerfile << EOF
# syntax=docker/dockerfile:1
FROM rocker/verse:3.6.0                  
WORKDIR /app
COPY hypoparsr_apply_to_file.r hypoparsr_apply_to_file.r 
COPY call_hypoparsr_apply_to_file.sh call_hypoparsr_apply_to_file.sh
COPY hypoparsr_install.r hypoparsr_install.r
COPY hypoparsr hypoparsr
COPY test_files test_data
RUN Rscript hypoparsr_install.r
EOF

echo "INFO: Building docker-hypoparsr Docker image"

docker build --tag docker-hypoparsr .

echo "INFO: Saving image to Docker Hub"

docker tag docker-hypoparsr karenjexphd/table_extraction_tests:docker-hypoparsr
docker push karenjexphd/table_extraction_tests:docker-hypoparsr

echo "INFO: Removing temp files created during processing"

rm -rf /tmp/hypoparsr_dockerfiles


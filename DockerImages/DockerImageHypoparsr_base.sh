#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-hypoparsr-base containing Hypoparsr runtime environment      #
# See DockerSetup.sh for prerequisites                                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

mkdir /tmp/hypoparsr_dockerfiles
cp -r test_files /tmp/hypoparsr_dockerfiles
cd /tmp/hypoparsr_dockerfiles

echo "INFO: Cloning hypoparsr repo"

git clone git@github.com:karenjexphd/hypoparsr.git

echo "INFO: Creating hypoparsr install script"

cat > hypoparsr_install.r << EOF
devtools::install_github("karenjexphd/hypoparsr")
EOF

echo "INFO: Creating Dockerfile"

cat > Dockerfile << EOF
# syntax=docker/dockerfile:1
FROM rocker/verse:3.6.0                  
WORKDIR /app
COPY hypoparsr_install.r hypoparsr_install.r
COPY hypoparsr hypoparsr
# COPY test_files test_data
RUN Rscript hypoparsr_install.r
EOF

echo "INFO: Building docker-hypoparsr Docker image"

docker build --tag docker-hypoparsr-base .

echo "INFO: Saving image to Docker Hub"

docker tag docker-hypoparsr-base karenjexphd/table_extraction_tests:docker-hypoparsr-base
docker push karenjexphd/table_extraction_tests:docker-hypoparsr-base

echo "INFO: Removing temp files created during processing"

rm -rf /tmp/hypoparsr_dockerfiles
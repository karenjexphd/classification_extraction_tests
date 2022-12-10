#-----------------------------------------------------------------------#
# File containing instructions for creating Docker images               #
#   docker-tabby containing TabbyXL runtime environment                 #
# See DockerSetup.sh for prerequisites                                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

mkdir /tmp/hypoparsr_dockerfiles
cp -r test_files /tmp/hypoparsr_dockerfiles
cd /tmp/hypoparsr_dockerfiles

# Clone hypoparsr repo

git clone git@github.com:karenjexphd/hypoparsr.git

# Create script to apply hypoparsr table extraction against given .csv file

cat > hypoparsr_apply_to_file.r << EOF
args = commandArgs(trailingOnly=TRUE)
input_file = args[1]
# call hypoparsr
res <- hypoparsr::parse_file(input_file)
# get result data frames
best_guess <- as.data.frame(res)
print(best_guess)
EOF

cat > hypoparsr_install.r << EOF
devtools::install_github("karenjexphd/hypoparsr")
EOF

# Create Dockerfile

cat > Dockerfile << EOF
# syntax=docker/dockerfile:1
FROM rocker/verse:3.6.0                  
WORKDIR /app
COPY hypoparsr_apply_to_file.r hypoparsr_apply_to_file.r
COPY hypoparsr_install.r hypoparsr_install.r
COPY hypoparsr hypoparsr
COPY test_files test_data
RUN Rscript hypoparsr_install.r
EOF

# Build docker-hypoparsr Docker image

docker build --tag docker-hypoparsr .

# Save image to Docker Hub

docker tag docker-hypoparsr karenjexphd/table_extraction_tests:docker-hypoparsr
docker push karenjexphd/table_extraction_tests:docker-hypoparsr

rm -rf /tmp/hypoparsr_dockerfiles


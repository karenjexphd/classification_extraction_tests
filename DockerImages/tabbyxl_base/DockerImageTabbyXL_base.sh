#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-tabby containing TabbyXL runtime environment                 #
# See DockerSetup.sh for prerequisites                                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

# Create temporary clone of tabbyxl (v1.1.1) repo
git clone git@github.com:karenjexphd/tabbyxl.git tabbyxl_clone_tmp

# Build docker-tabby-base Docker image
docker build --tag docker-tabby-base .

# Save image to Docker Hub
docker tag docker-tabby-base karenjexphd/table_extraction_tests:docker-tabby-base
docker push karenjexphd/table_extraction_tests:docker-tabby-base

# Remove temporary clone of tabbyxl (v1.1.1) repo
rm -rf tabbyxl_clone_tmp

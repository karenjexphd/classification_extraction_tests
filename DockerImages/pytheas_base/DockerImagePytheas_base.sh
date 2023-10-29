#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-pytheas-base containing Pytheas runtime environment          #
# See DockerSetup.sh for prerequisites                                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

# Clone Pytheas repo

git clone git@github.com:karenjexphd/pytheas.git pytheas_clone_tmp

# Build docker-pytheas Docker image

docker build --tag docker-pytheas-base .

# Save image to Docker Hub

docker tag docker-pytheas-base karenjexphd/table_extraction_tests:docker-pytheas-base
docker push karenjexphd/table_extraction_tests:docker-pytheas-base

rm -rf pytheas_clone_tmp

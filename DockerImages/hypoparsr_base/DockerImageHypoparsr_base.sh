#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-hypoparsr-base containing Hypoparsr runtime environment      #
# See DockerSetup.sh for prerequisites                                  #
#-----------------------------------------------------------------------#

echo "INFO: Creating temporary clone of hypoparsr repo"

git clone git@github.com:karenjexphd/hypoparsr.git hypoparsr_clone_tmp

echo "INFO: Building docker-hypoparsr-base Docker image"

docker build --tag docker-hypoparsr-base .

echo "INFO: Saving image to Docker Hub"

docker tag docker-hypoparsr-base karenjexphd/table_extraction_tests:docker-hypoparsr-base
docker push karenjexphd/table_extraction_tests:docker-hypoparsr-base

echo "INFO: Removing temp repo created during processing"

rm -rf hypoparsr_clone_tmp
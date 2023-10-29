#-----------------------------------------------------------------------#
# File containing instructions for adding scripts to base Docker image  #
#   docker-hypoparsr-base to create docker-hypoparsr image              #
#-----------------------------------------------------------------------#

echo "INFO: Building docker-hypoparsr Docker image"

docker build --tag docker-hypoparsr .

echo "INFO: Saving image to Docker Hub"

docker tag docker-hypoparsr karenjexphd/table_extraction_tests:docker-hypoparsr
docker push karenjexphd/table_extraction_tests:docker-hypoparsr

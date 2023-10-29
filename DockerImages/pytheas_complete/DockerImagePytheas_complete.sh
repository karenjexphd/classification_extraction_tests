#-----------------------------------------------------------------------#
# File containing instructions for adding scripts to base Docker image  #
#   docker-pytheas-base to create docker-pytheas image                  #
#-----------------------------------------------------------------------#

# Build docker-pytheas Docker image

docker build --tag docker-pytheas .

# Save image to Docker Hub

docker tag docker-pytheas karenjexphd/table_extraction_tests:docker-pytheas
docker push karenjexphd/table_extraction_tests:docker-pytheas

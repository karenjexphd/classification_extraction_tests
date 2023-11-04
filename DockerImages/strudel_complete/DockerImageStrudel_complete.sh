#-----------------------------------------------------------------------#
# File containing instructions for adding scripts to base Docker image  #
#   docker-strudel-base to create docker-strudel image                  #
# to be run from classification_extraction_tests folder                 #
#-----------------------------------------------------------------------#

# Build docker-strudel Docker image
docker build --tag docker-strudel .

# Save image to Docker Hub
docker tag docker-strudel karenjexphd/table_extraction_tests:docker-strudel
docker push karenjexphd/table_extraction_tests:docker-strudel

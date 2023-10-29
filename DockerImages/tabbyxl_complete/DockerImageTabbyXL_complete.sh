#-----------------------------------------------------------------------#
# File to create TabbyXL Docker image containing required scripts       #
# image based on karenjexphd/table_extraction_tests:docker-tabby-base   #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

# Build docker-tabby Docker image
docker build --tag docker-tabby .

# Save image to Docker Hub
docker tag docker-tabby karenjexphd/table_extraction_tests:docker-tabby
docker push karenjexphd/table_extraction_tests:docker-tabby

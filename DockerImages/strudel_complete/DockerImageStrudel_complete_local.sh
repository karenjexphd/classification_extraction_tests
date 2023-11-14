#-----------------------------------------------------------------------#
# File containing instructions for adding scripts to base Docker image  #
#   docker-strudel-base to create docker-strudel image                  #
# to be run from classification_extraction_tests folder                 #
#-----------------------------------------------------------------------#

# Build docker-strudel Docker image
docker build -f Dockerfile_local --tag docker-strudel .
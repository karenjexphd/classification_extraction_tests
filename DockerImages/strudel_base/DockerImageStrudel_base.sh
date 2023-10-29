#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-strudel-base containing Strudel runtime environment          #
# See DockerSetup.sh for prerequisites                                  #
#-----------------------------------------------------------------------#

# Clone Strudel repo into /tmp/strudel
git clone git@github.com:karenjexphd/strudel.git strudel_clone_tmp

# Build docker-strudel-base Docker image
docker build --tag docker-strudel-base .

# Save image to Docker Hub
docker tag docker-strudel-base karenjexphd/table_extraction_tests:docker-strudel-base
docker push karenjexphd/table_extraction_tests:docker-strudel-base

rm -rf strudel_clone_tmp
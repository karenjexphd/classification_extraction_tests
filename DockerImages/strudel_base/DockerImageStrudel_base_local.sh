#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-strudel-base containing Strudel runtime environment          #
# See DockerSetup.sh for prerequisites                                  #
#-----------------------------------------------------------------------#

# Clone Strudel repo strudel_clone_tmp
git clone git@github.com:karenjexphd/strudel.git strudel_clone_tmp

# Build docker-strudel-base Docker image
docker build --tag docker-strudel-base .

rm -rf strudel_clone_tmp

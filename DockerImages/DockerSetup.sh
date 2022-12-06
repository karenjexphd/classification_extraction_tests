#-----------------------------------------------------------------------#
# File containing prerequisites and setup for creating Docker images    #
#-----------------------------------------------------------------------#

#-----------------------------------------------------------------------#
#                         -- Prerequisites --                           #
#-----------------------------------------------------------------------#

# User performing tasks should be added to docker group:
#    sudo usermod -a -G <group> <username>
#    sudo usermod -a -G docker karen

# Logged in to Docker Hub:
#   docker login -u <username>
#   docker login -u karenjexphd

#-----------------------------------------------------------------------#
#                     -- TO DO (all scripts) --                         #
#-----------------------------------------------------------------------#

# parameterise dockerhub and github usernames (currently karenjexphd)

# use mounts instead of copying files during creation of docker images

# allow for multiple demo_a_n_n.xlsx files (multiple tables in input)
# loop through $outputdir and process all files with xlsx2csv


#-----------------------------------------------------------------------#
# 0. Setup                                                               #
#-----------------------------------------------------------------------#

# Install pip
sudo apt install python3-pip

# Enable Docker buildKit
sudo DOCKER_BUILDKIT=1 docker build .

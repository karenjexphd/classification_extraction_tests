
# -------------------------------------------------------------------- #
# replace "mymethod" with name of method to create Docker image for    #
# add in any necessary steps and/or scripts                            #
# select required image to base Docker image on                        #
# -------------------------------------------------------------------- #

mkdir ~/mymethod_dockerfiles
cd ~/mymethod_dockerfiles

# Clone required repos

git clone git@github.com:karenjexphd/mymethod.git
git clone git@github.com:karenjexphd/test_data_10_tables.git

# Create Dockerfile - select required image in place of rockylinux8

cat > Dockerfile << EOF
FROM rockylinux:8
WORKDIR /app
COPY mymethod mymethod
COPY test_data_10_tables/simple_test test_data
# insert required commands here
EOF

# Build docker-mymethod Docker image
docker build --tag docker-mymethod .

# Save image to Docker Hub
docker tag docker-mymethod karenjexphd/table_extraction_tests:docker-mymethod
docker push karenjexphd/table_extraction_tests:docker-mymethod

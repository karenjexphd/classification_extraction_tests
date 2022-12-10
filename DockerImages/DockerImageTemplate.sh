
# -------------------------------------------------------------------- #
# replace "mymethod" with name of method to create Docker image for    #
# add in any necessary steps and/or scripts                            #
# select required image to base Docker image on                        #
# Commands run from cloned classification_extraction_tests repo        #
# -------------------------------------------------------------------- #

mkdir /tmp/mymethod_dockerfiles
cp -r test_files /tmp/mymethod_dockerfiles
cd /tmp/mymethod_dockerfiles


# Clone mymethod repo

git clone git@github.com:karenjexphd/mymethod.git

# Create Dockerfile - select required image in place of rockylinux8

cat > Dockerfile << EOF
FROM rockylinux:8
WORKDIR /app
COPY mymethod mymethod
COPY test_files test_data
# insert required commands here
EOF

# Build docker-mymethod Docker image
docker build --tag docker-mymethod .

# Save image to Docker Hub
docker tag docker-mymethod karenjexphd/table_extraction_tests:docker-mymethod
docker push karenjexphd/table_extraction_tests:docker-mymethod

rm -rf /tmp/mymethod_dockerfiles

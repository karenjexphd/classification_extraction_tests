#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-tabby containing TabbyXL runtime environment                 #
# See DockerSetup.sh for prerequisites                                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

mkdir /tmp/tabby_dockerfiles
cp -r test_files /tmp/tabby_dockerfiles
cd /tmp/tabby_dockerfiles

# Clone TabbyXL repo

git clone git@github.com:karenjexphd/tabbyxl.git

# Create Dockerfile - image based on rockylinux 8

cat > Dockerfile << EOF
FROM rockylinux:8
WORKDIR /app
COPY tabbyxl tabbyxl
COPY test_files test_data
RUN yum -y update
RUN yum -y install git maven
RUN mvn -f ./tabbyxl/pom.xml clean install
RUN sed -i 's/java /java -Xmx1024m /' tabbyxl/test.sh
RUN chmod +x tabbyxl/test.sh
EOF

# Build docker-tabby Docker image
docker build --tag docker-tabby-base .

# Save image to Docker Hub
docker tag docker-tabby karenjexphd/table_extraction_tests:docker-tabby-base
docker push karenjexphd/table_extraction_tests:docker-tabby-base

rm -rf /tmp/tabby_dockerfiles

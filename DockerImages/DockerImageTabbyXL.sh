#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-tabby containing TabbyXL runtime environment                 #
# See PytheasSetup.sh for prerequisites                                 #
#-----------------------------------------------------------------------#

mkdir ~/tabby_dockerfiles
cd ~/tabby_dockerfiles

# Clone required repos

git clone git@github.com:karenjexphd/tabbyxl.git
git clone git@github.com:karenjexphd/test_data_10_tables.git

# Create Dockerfile - image based on rockylinux 8

cat > Dockerfile << EOF
FROM rockylinux:8
WORKDIR /app
COPY tabbyxl tabbyxl
COPY test_data_10_tables/simple_test test_data
RUN yum -y update
RUN yum -y install git maven
RUN mvn -f ./tabbyxl/pom.xml clean install
RUN sed -i 's/java /java -Xmx1024m /' tabbyxl/test.sh
RUN chmod u+x tabbyxl/test.sh
EOF

# Build docker-tabby Docker image
docker build --tag docker-tabby .

# Save image to Docker Hub
docker tag docker-tabby karenjexphd/table_extraction_tests:docker-tabby
docker push karenjexphd/table_extraction_tests:docker-tabby

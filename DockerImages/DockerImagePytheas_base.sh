#-----------------------------------------------------------------------#
# File containing instructions for creating Docker image                #
#   docker-pytheas-base containing Pytheas runtime environment          #
# See DockerSetup.sh for prerequisites                                  #
# Commands run from cloned classification_extraction_tests repo         #
#-----------------------------------------------------------------------#

mkdir /tmp/pytheas_dockerfiles
cp -r test_files /tmp/pytheas_dockerfiles
cd /tmp/pytheas_dockerfiles

# Clone Pytheas repo

git clone git@github.com:karenjexphd/pytheas.git

# Create file containing pip install requirements

cat > requirements.txt << EOF
psycopg2-binary==2.9.4
nltk==3.6
pytest==7.0.1
EOF

# Create Dockerfile

cat > Dockerfile << EOF
# syntax=docker/dockerfile:1
FROM python:3.6
WORKDIR /app
COPY requirements.txt requirements.txt 
RUN pip3 install -r requirements.txt
COPY pytheas pytheas 
COPY test_files test_data
WORKDIR /app/pytheas/src
RUN python3 setup.py sdist bdist_wheel
RUN python3 -m nltk.downloader stopwords
RUN pip3 install  --upgrade --force-reinstall dist/pytheas-0.0.1-py3-none-any.whl
WORKDIR /app
EOF

# Build docker-pytheas Docker image

docker build --tag docker-pytheas-base .

# Save image to Docker Hub

docker tag docker-pytheas-base karenjexphd/table_extraction_tests:docker-pytheas-base
docker push karenjexphd/table_extraction_tests:docker-pytheas-base

rm -rf /tmp/pytheas_dockerfiles

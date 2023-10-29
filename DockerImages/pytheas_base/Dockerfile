# syntax=docker/dockerfile:1
FROM python:3.6
WORKDIR /app
COPY requirements.txt requirements.txt 
RUN pip3 install -r requirements.txt
COPY pytheas_clone_tmp pytheas
WORKDIR /app/pytheas/src
RUN python3 setup.py sdist bdist_wheel
RUN python3 -m nltk.downloader stopwords
RUN pip3 install  --upgrade --force-reinstall dist/pytheas-0.0.1-py3-none-any.whl
WORKDIR /app
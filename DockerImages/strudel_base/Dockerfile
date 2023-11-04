# syntax=docker/dockerfile:1
FROM python:3.7
WORKDIR /app
COPY strudel_clone_tmp strudel
COPY punkt.py strudel/punkt.py
WORKDIR /app/strudel
RUN python -m pip install --upgrade pip
RUN python -m pip install -r requirements.txt
RUN python -m pip install pebble
RUN python punkt.py
WORKDIR /app

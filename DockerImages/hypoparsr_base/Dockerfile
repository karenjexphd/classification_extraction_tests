# syntax=docker/dockerfile:1
FROM rocker/verse:3.6.0                  
WORKDIR /app
COPY hypoparsr_install.r hypoparsr_install.r
COPY hypoparsr_clone_tmp hypoparsr
RUN Rscript hypoparsr_install.r
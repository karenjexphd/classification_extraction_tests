FROM rockylinux:8
WORKDIR /app
COPY tabbyxl_clone_tmp tabbyxl
RUN yum -y update
RUN yum -y install git maven
RUN mvn -f ./tabbyxl/pom.xml clean install
RUN sed -i 's/java /java -Xmx1024m /' tabbyxl/test.sh
RUN chmod +x tabbyxl/test.sh
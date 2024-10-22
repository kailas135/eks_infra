FROM tomcat:8.0.20-jre8
EXPOSE 8080
COPY ./target/onlinebookstore.war  /usr/local/tomcat/webapps/onlinebookstore.war
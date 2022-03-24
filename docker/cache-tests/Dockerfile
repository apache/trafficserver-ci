FROM controller.trafficserver.org/ats/debian:11

EXPOSE 8000

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update ; \
  apt-get -y install npm curl ; \
        apt-get autoremove ; \
        apt-get clean ;

RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
RUN apt install -y nodejs
COPY cache-tests /cache-tests
RUN mkdir -p /opt/ && chmod 777 /opt/
RUN cd /cache-tests && npm i

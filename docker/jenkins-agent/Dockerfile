FROM jenkins/inbound-agent
USER root
RUN apt-get update && apt-get -y install docker docker-compose sudo
RUN usermod -aG docker jenkins
RUN echo -e "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/jenkins
RUN chmod u+wx /etc/sudoers

USER jenkins

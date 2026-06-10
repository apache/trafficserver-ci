FROM httpd:2.4

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/*

COPY mirror.conf /usr/local/apache2/conf/extra/github-mirror.conf

RUN printf '\nInclude conf/extra/github-mirror.conf\n' >> /usr/local/apache2/conf/httpd.conf

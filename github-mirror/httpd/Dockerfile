FROM httpd:2.4

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/*

RUN git config --system --add safe.directory /usr/local/apache2/mirror/trafficserver.git \
  && git config --system --add safe.directory /usr/local/apache2/mirror/trafficserver-ci.git \
  && git config --system pack.threads 1 \
  && git config --system pack.windowMemory 64m \
  && git config --system pack.deltaCacheSize 32m \
  && git config --system core.packedGitLimit 256m \
  && git config --system core.packedGitWindowSize 32m \
  && git config --system core.deltaBaseCacheLimit 32m

COPY mirror.conf /usr/local/apache2/conf/extra/github-mirror.conf

RUN printf '\nInclude conf/extra/github-mirror.conf\n' >> /usr/local/apache2/conf/httpd.conf

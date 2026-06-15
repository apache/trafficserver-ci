FROM python:3.11-slim

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    git \
    util-linux \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/github-mirror

CMD ["/opt/github-mirror/bin/github-mirror-webhook.py"]

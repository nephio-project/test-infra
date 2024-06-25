FROM python:3.11-slim

ENV USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
  openssh-client=1:9.2p1-2+deb12u1 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && pip install --no-cache-dir tox==4.11.3

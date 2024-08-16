FROM hashicorp/terraform:1.5.7

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN wget -q -c https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-446.0.0-linux-x86_64.tar.gz -O - | tar -xz -C /tmp && \
    apk add --no-cache python3=3.11.6-r0 && \
    /tmp/google-cloud-sdk/install.sh -q

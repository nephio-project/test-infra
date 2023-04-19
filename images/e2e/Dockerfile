FROM hashicorp/terraform:1.4.5
RUN apk update && \
    wget -c https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-427.0.0-linux-x86_64.tar.gz && \
    tar xf /google-cloud-cli-427.0.0-linux-x86_64.tar.gz && \
    apk add python3 && \
    /google-cloud-sdk/install.sh -q 
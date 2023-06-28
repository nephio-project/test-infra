FROM golang:1.20.5-bullseye
ADD release.sh /usr/local/bin/
RUN go install github.com/google/go-containerregistry/cmd/crane@v0.15.2 && \
    wget -c https://github.com/sigstore/cosign/releases/download/v2.0.2/cosign-linux-amd64 -O /usr/local/bin/cosign && \
    wget -c https://github.com/anchore/syft/releases/download/v0.84.0/syft_0.84.0_linux_amd64.deb && \
    dpkg -i syft_0.84.0_linux_amd64.deb && rm syft_0.84.0_linux_amd64.deb && \
    wget -c https://github.com/anchore/grype/releases/download/v0.62.3/grype_0.62.3_linux_amd64.deb && \
    dpkg -i grype_0.62.3_linux_amd64.deb && rm grype_0.62.3_linux_amd64.deb && \
    wget -c https://github.com/aquasecurity/trivy/releases/download/v0.42.1/trivy_0.42.1_Linux-64bit.deb && \
    dpkg -i trivy_0.42.1_Linux-64bit.deb && rm trivy_0.42.1_Linux-64bit.deb && \
    wget -c https://github.com/oras-project/oras/releases/download/v1.0.0/oras_1.0.0_linux_amd64.tar.gz && \
    tar xf oras_1.0.0_linux_amd64.tar.gz && mv oras /usr/local/bin && rm oras_1.0.0_linux_amd64.tar.gz && \
    wget -c https://github.com/ko-build/ko/releases/download/v0.14.1/ko_0.14.1_Linux_x86_64.tar.gz && \
    tar xf ko_0.14.1_Linux_x86_64.tar.gz && mv ko /usr/local/bin/ && rm ko_0.14.1_Linux_x86_64.tar.gz && \
    chmod +x /usr/local/bin/*

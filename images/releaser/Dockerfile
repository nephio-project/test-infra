FROM golang:1.20.5-bullseye as builder

COPY release.sh /usr/local/bin/
RUN go install github.com/google/go-containerregistry/cmd/crane@v0.15.2
ADD https://github.com/oras-project/oras/releases/download/v1.0.0/oras_1.0.0_linux_amd64.tar.gz /tmp/oras
ADD https://github.com/ko-build/ko/releases/download/v0.14.1/ko_0.14.1_Linux_x86_64.tar.gz /tmp/ko

FROM debian:bullseye-slim

COPY --from=builder /go/bin/crane /usr/local/bin/crane
COPY --from=builder /tmp/oras /usr/local/bin/oras
COPY --from=builder /tmp/ko /usr/local/bin/ko

ADD https://github.com/sigstore/cosign/releases/download/v2.0.2/cosign-linux-amd64 /usr/local/bin/cosign
ADD https://github.com/anchore/syft/releases/download/v0.84.0/syft_0.84.0_linux_amd64.deb /tmp/syft.deb
ADD https://github.com/anchore/grype/releases/download/v0.62.3/grype_0.62.3_linux_amd64.deb /tmp/grype.deb
ADD https://github.com/aquasecurity/trivy/releases/download/v0.42.1/trivy_0.42.1_Linux-64bit.deb /tmp/trivy.deb

RUN dpkg -i /tmp/*.deb && rm -rf /tmp/*.deb && \
  chmod +x /usr/local/bin/*

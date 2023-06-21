FROM golang:1.20.5-bullseye as builder
ARG ctrl_tools_ver=0.12.0
WORKDIR /go/src/
ADD https://github.com/kubernetes-sigs/controller-tools/archive/refs/tags/v$ctrl_tools_ver.tar.gz ./
RUN tar -xzf v$ctrl_tools_ver.tar.gz

WORKDIR /go/src/controller-tools-$ctrl_tools_ver/
RUN go build -o /tmp/ ./...

FROM golang:1.20.5-bullseye
RUN apt-get  update && \
    apt-get -y install make && \
    wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s v1.53.3 && \
    wget -O - -q https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s v2.16.0 && \
    go install github.com/google/addlicense@v1.1.1 && \
    go install github.com/uw-labs/lichen@v0.1.7

COPY --from=builder /tmp/controller-gen /go/bin
COPY --from=builder /tmp/helpgen /go/bin
COPY --from=builder /tmp/type-scaffold /go/bin

COPY lichen.sh checklicense.sh /usr/local/bin/
COPY lichen.yaml /etc/
RUN chmod +x /usr/local/bin/*.sh

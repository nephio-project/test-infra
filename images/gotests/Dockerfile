FROM golang:1.20.4-bullseye as builder
RUN  cd /go/src/ && wget https://github.com/kubernetes-sigs/controller-tools/archive/refs/tags/v0.12.0.tar.gz && \
     tar xf v0.12.0.tar.gz && \
     cd /go/src/controller-tools-0.12.0/cmd/controller-gen && go build && cd /go/src/controller-tools-0.12.0/cmd/helpgen && \
     go build && cd /go/src/controller-tools-0.12.0/cmd/type-scaffold && go build

FROM golang:1.20.4-bullseye
RUN apt-get  update && \
    apt-get -y install make && \
    wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s v1.52.2 && \
    wget -O - -q https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s v2.15.0 && \
    go install github.com/google/addlicense@v1.1.1

COPY --from=builder /go/src/controller-tools-0.12.0/cmd/controller-gen/controller-gen /go/bin
COPY --from=builder /go/src/controller-tools-0.12.0/cmd/helpgen/helpgen /go/bin
COPY --from=builder /go/src/controller-tools-0.12.0/cmd/type-scaffold/type-scaffold /go/bin

COPY checklicense.sh /usr/local/bin/ 
COPY lichen.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

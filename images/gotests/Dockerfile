FROM golang:1.20.2-alpine3.17

RUN apk update && \
    apk add --no-cache make && \
    wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s v1.52.2 && \
    wget -O - -q https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s v2.15.0

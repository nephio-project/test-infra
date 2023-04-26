FROM golang:1.20.3-alpine3.17

RUN apk update && \
    apk add --no-cache make && \
    wget -O- -nv https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s v1.52.2 && \
    wget -O - -q https://raw.githubusercontent.com/securego/gosec/master/install.sh | sh -s v2.15.0 && \
    go install github.com/google/addlicense@v1.1.1
COPY checklicense.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/checklicense.sh

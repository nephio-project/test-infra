FROM golang:1.20.4-alpine3.17 as builder
RUN apk update && apk add git  && cd src && \
    git clone https://github.com/kubernetes/test-infra.git && \
    cd test-infra/label_sync && \
    go build

FROM golang:1.20.4-alpine3.17
COPY --from=builder /go/src/test-infra/label_sync/label_sync /go/bin

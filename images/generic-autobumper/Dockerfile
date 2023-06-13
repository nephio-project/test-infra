FROM golang:1.18 as builder
RUN git clone --depth 1 https://github.com/kubernetes/test-infra.git /opt/test-infra

WORKDIR /opt/test-infra
RUN CGO_ENABLED=0 go build -o /tmp/ ./prow/cmd/generic-autobumper/...

FROM golang:1.20.4-alpine3.17
COPY --from=builder /go/src/test-infra/prow/cmd/generic-autobumper/generic-autobumper /go/bin

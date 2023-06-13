FROM golang:1.18 as builder
RUN git clone --depth 1 https://github.com/kubernetes/test-infra.git /opt/test-infra

WORKDIR /opt/test-infra
RUN CGO_ENABLED=0 go build -o /tmp/ ./prow/cmd/generic-autobumper/...

FROM gcr.io/distroless/static-debian11

COPY --from=builder /tmp/generic-autobumper /
CMD ["/generic-autobumper"]

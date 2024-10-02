FROM golang:1.22 AS builder
RUN git clone --depth 1 https://github.com/kubernetes-sigs/prow.git /opt/prow

WORKDIR /opt/prow
RUN CGO_ENABLED=0 go build -o /tmp/ ./cmd/generic-autobumper/...

FROM gcr.io/distroless/static-debian12@sha256:262ae336f8e9291f8edc9a71a61d5d568466edc1ea4818752d4af3d230a7f9ef

COPY --from=builder /tmp/generic-autobumper /
CMD ["/generic-autobumper"]

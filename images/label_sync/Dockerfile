FROM golang:1.20.4-alpine3.17 as builder

WORKDIR /opt
RUN apk add --no-cache git=2.38.5-r0 && \
  git clone --depth 1 https://github.com/kubernetes/test-infra.git

WORKDIR /opt/test-infra/label_sync
RUN go build

FROM gcr.io/distroless/base:nonroot

COPY --from=builder /opt/test-infra/label_sync/label_sync /bin

ENTRYPOINT ["/bin/label_sync"]

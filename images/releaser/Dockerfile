#  Copyright 2025 The Nephio Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

FROM golang:1.22-alpine AS builder

RUN go install github.com/google/go-containerregistry/cmd/crane@v0.15.2 && \
    go install github.com/sigstore/cosign/v2/cmd/cosign@v2.2.4

FROM alpine:3.19

COPY --from=builder /go/bin/crane /usr/local/bin/crane
COPY --from=builder /go/bin/cosign /usr/local/bin/cosign
COPY release.sh /usr/local/bin/release

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN apk --no-cache update && apk add --no-cache curl=8.9.0-r0 bash=5.2.21-r0 && \
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.51.2 && \
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin && \
    curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin && \
    curl -L https://github.com/oras-project/oras/releases/download/v1.1.0/oras_1.1.0_linux_amd64.tar.gz | tar -zx -C /usr/local/bin/ && \
    apk del curl && chmod +x /usr/local/bin/*

ENTRYPOINT [ "release" ]

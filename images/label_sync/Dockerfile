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

FROM golang:1.20.4-alpine3.17 AS builder

WORKDIR /opt
RUN apk add --no-cache git=2.38.5-r0 && \
  git clone --depth 1 https://github.com/kubernetes/test-infra.git

WORKDIR /opt/test-infra/label_sync
RUN go build

FROM gcr.io/distroless/base:nonroot

COPY --from=builder /opt/test-infra/label_sync/label_sync /bin

ENTRYPOINT ["/bin/label_sync"]

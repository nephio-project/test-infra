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

FROM golang:1.22 AS builder
RUN git clone --depth 1 https://github.com/kubernetes-sigs/prow.git /opt/prow

WORKDIR /opt/prow
RUN CGO_ENABLED=0 go build -o /tmp/ ./cmd/generic-autobumper/...

FROM gcr.io/distroless/static-debian12@sha256:262ae336f8e9291f8edc9a71a61d5d568466edc1ea4818752d4af3d230a7f9ef

COPY --from=builder /tmp/generic-autobumper /
CMD ["/generic-autobumper"]

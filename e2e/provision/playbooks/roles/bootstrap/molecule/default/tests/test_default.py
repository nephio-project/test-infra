#   Copyright (c) 2023 The Nephio Authors.
#
#   Licensed under the Apache License, Version 2.0 (the "License"); you may
#   not use this file except in compliance with the License. You may obtain
#   a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#   WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#   License for the specific language governing permissions and limitations
#   under the License.
#


def test_gtp5g_load(host):
    cmd = host.run("modinfo gtp5g")
    assert cmd.succeeded

def test_kind_creation(host):
    kind = host.docker("kind-control-plane")

    assert kind.is_running
    destinations = host.check_output(
        "docker inspect \
--format '{{range .Mounts }}{{.Destination}}{{\"\\n\"}}{{end}}' \
kind-control-plane"
    )
    assert "/var/run/docker.sock" in destinations
    sources = host.check_output(
        "docker inspect \
--format '{{range .Mounts }}{{.Source}}{{\"\\n\"}}{{end}}' \
kind-control-plane"
    )
    assert "/var/run/docker.sock" in sources

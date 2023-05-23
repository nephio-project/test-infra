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


def test_kind_clusters_creation(host):
    cmd = host.run("sudo kind get clusters")
    assert cmd.succeeded
    assert cmd.rc == 0
    assert "gitea-k8s" in cmd.stdout
    assert "mgmt-k8s" in cmd.stdout


def test_gitea_cluster_creation(host):
    kind = host.docker("gitea-k8s-control-plane")

    assert kind.is_running


def test_mgmt_cluster_mounted_docker_host_sock(host):
    kind = host.docker("mgmt-k8s-control-plane")

    assert kind.is_running
    destinations = host.check_output(
        "docker inspect \
--format '{{range .Mounts }}{{.Destination}}{{\"\\n\"}}{{end}}' \
mgmt-k8s-control-plane"
    )
    assert "/var/run/docker.sock" in destinations
    sources = host.check_output(
        "docker inspect \
--format '{{range .Mounts }}{{.Source}}{{\"\\n\"}}{{end}}' \
mgmt-k8s-control-plane"
    )
    assert "/var/run/docker.sock" in sources

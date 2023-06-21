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


def test_kernel_parameters_validation(host):
    params = {
        "fs.inotify.max_user_watches": "524288",
        "fs.inotify.max_user_instances": "512",
        "kernel.keys.maxkeys": "500000",
        "kernel.keys.maxbytes": "1000000",
    }
    for param, value in params.items():
        cmd = host.run("sysctl -n %s" % param)
        assert cmd.succeeded
        assert cmd.stdout.rstrip() == value


def test_kind_cluster_creation(host):
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


def test_gitea_namespace_creation(host):
    got = host.check_output("kubectl get namespaces")

    assert "gitea" in got


def test_gitea_secrets_creation(host):
    got = host.check_output(
        "kubectl get secrets -A \
-o jsonpath='{range .items[*]}{.metadata.name}{\" \"}{end}'"
    )

    assert "gitea-postgresql" in got
    assert "git-user-secret" in got


def _check_k8s_deployment(host, deployment, namespace):
    assert host.run(
        "kubectl get deployments -n %s %s" % (namespace, deployment)
    ).succeeded
    assert host.run(
        "kubectl rollout status deployment -n %s %s" % (namespace, deployment)
    ).succeeded


def test_resource_backend_deployments_creation(host):
    _check_k8s_deployment(host, "resource-backend-controller", "backend-system")


def test_metallb_deployments_creation(host):
    _check_k8s_deployment(host, "controller", "metallb-system")


def test_cert_manager_deployments_creation(host):
    for deployment in [
        "cert-manager",
        "cert-manager-cainjector",
        "cert-manager-webhook",
    ]:
        _check_k8s_deployment(host, deployment, "cert-manager")


def test_gitea_deployments_creation(host):
    _check_k8s_deployment(host, "gitea-memcached", "gitea")


def test_cluster_api_deployments_creation(host):
    expected = {
        "capd-system": ["capd-controller-manager"],
        "capi-kubeadm-bootstrap-system": ["capi-kubeadm-bootstrap-controller-manager"],
        "capi-kubeadm-control-plane-system": [
            "capi-kubeadm-control-plane-controller-manager"
        ],
        "capi-system": ["capi-controller-manager"],
    }
    for namespace, deployments in expected.items():
        for deploy in deployments:
            _check_k8s_deployment(host, deploy, namespace)

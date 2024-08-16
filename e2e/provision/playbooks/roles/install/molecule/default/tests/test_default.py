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


def _check_k8s_deployment(host, deployment, namespace):
    assert host.run(
        "kubectl get deployments -n %s %s" % (namespace, deployment)
    ).succeeded
    assert host.run(
        "kubectl rollout status deployment -n %s %s" % (namespace, deployment)
    ).succeeded


def test_config_management_deployments_creation(host):
    expected = {
        "config-management-monitoring": ["otel-collector"],
        "config-management-system": [
            "config-management-operator",
            "reconciler-manager",
        ],
    }
    for namespace, deployments in expected.items():
        for deploy in deployments:
            _check_k8s_deployment(host, deploy, namespace)


def test_porch_deployments_creation(host):
    expected = {
        "porch-system": [
            "function-runner",
            "porch-controllers",
            "porch-server",
        ],
    }
    for namespace, deployments in expected.items():
        for deploy in deployments:
            _check_k8s_deployment(host, deploy, namespace)


def test_nephio_webui_deployments_creation(host):
    _check_k8s_deployment(host, "nephio-webui", "nephio-webui")


def test_nephio_system_deployments_creation(host):
    _check_k8s_deployment(host, "nephio-controller", "nephio-system")


def test_resource_group_system_deployments_creation(host):
    _check_k8s_deployment(
        host, "resource-group-controller-manager", "resource-group-system"
    )


def test_network_config_deployments_creation(host):
    _check_k8s_deployment(host, "network-config-controller", "network-config")


def test_repositories_creation(host):
    expected = [
        "catalog-workloads-free5gc",
        "catalog-infra-capi",
        "catalog-nephio-core",
        "catalog-nephio-optional",
        "oai-core-packages",
        "catalog-workloads-oai-ran",
    ]
    got = host.check_output(
        "kubectl get repositories -o \
jsonpath='{range .items[*]}{.status.conditions[*].ready.true}{.metadata.name}{\"\\n\"}{end}'"
    )
    for repository in expected:
        assert repository in got


def _check_api_resources(host, expected):
    for group, resources in expected.items():
        got = host.check_output(
            "kubectl api-resources --output=name --api-group=" + group
        )
        for resource in resources:
            assert resource + "." + group in got


def test_api_resources_created_for_nephio(host):
    expected = {
        "config.nephio.org": ["networks"],
        "infra.nephio.org": [
            "clustercontexts",
            "networkconfigs",
            "repositories",
            "tokens",
            "workloadclusters",
        ],
        "req.nephio.org": [
            "capacities",
            "datanetworknames",
            "datanetworks",
            "interfaces",
        ],
        "workload.nephio.org": [
            "amfdeployments",
            "smfdeployments",
            "upfdeployments",
        ],
    }
    _check_api_resources(host, expected)


def test_api_resources_created_for_porch(host):
    expected = {
        "config.porch.kpt.dev": [
            "packagerevs",
            "packagevariants",
            "packagevariantsets",
            "repositories",
        ],
        "porch.kpt.dev": [
            "functions",
            "packagerevisionresources",
            "packagerevisions",
            "packages",
        ],
    }
    _check_api_resources(host, expected)

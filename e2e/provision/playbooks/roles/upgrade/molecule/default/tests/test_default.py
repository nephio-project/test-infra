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


def _contains_new_version(host, file):
    assert host.file("/tmp/kpt-pkg/" + file).contains("v1.0.1")


def test_porch_dev_upgrade(host):
    _contains_new_version(host, "porch-dev/Kptfile")


def test_nephio_controllers_upgrade(host):
    for file in [
        "Kptfile",
        "app/controller/deployment-token-controller.yaml",
        "app/controller/deployment-controller.yaml",
    ]:
        _contains_new_version(host, "nephio-controllers/" + file)


def test_configsync_upgrade(host):
    _contains_new_version(host, "configsync/Kptfile")


def test_network_config_upgrade(host):
    for file in [
        "Kptfile",
        "app/controller/deployment-controller.yaml",
    ]:
        _contains_new_version(host, "network-config/" + file)


def test_nephio_webui_upgrade(host):
    for file in [
        "Kptfile",
        "deployment.yaml",
    ]:
        _contains_new_version(host, "nephio-webui/" + file)

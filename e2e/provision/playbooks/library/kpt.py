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

import os
import subprocess

from ansible.module_utils.basic import AnsibleModule

__metaclass__ = type

DOCUMENTATION = """
---
module: kpt

short_description: >
  Module for managing kpt command from ansible tasks.
description:
  - A module for managing kpt instructions from ansible tasks.
options:
    repo_uri:
        description:
          - URI of a git repository containing 1 or more packages as
            subdirectories.
        required: false
        type: str
    pkg_path:
        description:
          - Path to remote subdirectory containing Kubernetes resource
            configuration files or directories.
        required: false
        type: str
    version:
        description:
          - A git tag, branch, ref or commit for the remote version of the
            package to fetch. Defaults to the default branch of the repository.
        required: false
        type: str
        default: None
    local_dest_directory:
        description:
          - The local directory to write the package to.
        required: false
        default: .
        type: str
    strategy:
        description:
          - Defines which strategy should be used to update the package.
        required: false
        type: str
        choices:
          - resource-merge
          - fast-forward
          - force-delete-replace
    for_deployment:
        description:
           - (Experimental) indicates if the fetched package is a deployable
             instance that will be deployed to a cluster.
        required: false
        type: bool
    directory:
        description:
          - Directory of the kpt package.
        required: false
        default: .
        type: str
    diff_type:
        description:
          - The type of changes.
        required: false
        default: local
        type: str
        choices:
          - local
          - remote
          - combined
          - 3way
    diff_tool:
        description:
          - Command line diffing tool for showing the changes.
        required: false
        default: diff
        type: str
    diff_tool_opts:
        description:
          - Commandline options to use with the command line diffing tool.
        required: false
        type: str
    allow_exec:
        description:
          - Allow executable binaries to run as function.
        required: false
        type: str
    image_pull_policy:
        description:
          - If the image should be pulled before rendering the package(s).
        required: false
        type: str
    output:
        description:
           - If specified, the output resources are written to provided
             location, if not specified, resources are modified in-place.
        required: false
        type: str
    results_dir:
        description:
           - Path to a directory to write structured results.
        required: false
        type: str
    force:
        description:
           - Forces the inventory values to be updated, even if they are
             already set.
        required: false
        type: bool
    inventory_id:
        description:
           - Inventory identifier for the package.
        required: false
        type: str
    name:
        description:
           - The name for the ResourceGroup resource that contains the
             inventory for the package.
        required: false
        type: str
    namespace:
        description:
           - The namespace for the ResourceGroup resource that contains the
             inventory for the package.
        required: false
        type: str
    rg_file:
        description:
           - The name used for the file created for the ResourceGroup CR.
        required: false
        type: str
    dry_run:
        description:
           - It true, kpt will validate the resources in the package and print
             which resources will be applied and which resources will be
             pruned, but no resources will be changed.
        required: false
        type: bool
    field_manager:
        description:
          - Identifier for the **owner** of the fields being applied.
        required: false
        type: str
        default: kubectl
    force_conflicts:
        description:
          - Force overwrite of field conflicts during apply due to different
            field managers.
        required: false
        type: bool
    install_resource_group:
        description:
          - Install the ResourceGroup CRD into the cluster if it isn't already
            available.
        required: false
        type: bool
    inventory_policy:
        description:
          - Determines how to handle overlaps between the package being
            currently applied and existing resources in the cluster.
        required: false
        type: str
        choices:
          - strict
          - adopt
    prune_propagation_policy:
        description:
          - The propagation policy that should be used when pruning resources
        required: false
        type: str
        choices:
          - Background
          - Foreground
          - Orphan
    prune_timeout:
        description:
          - The threshold for how long to wait for all pruned resources to be
            deleted before giving up.
        required: false
        type: str
    reconcile_timeout:
        description:
          - The threshold for how long to wait for all resources to reconcile
            before giving up.
        required: false
        type: str
    server_side:
        description:
          - Perform the apply operation server-side rather than client-side.
        required: false
        type: bool
    show_status_events:
        description:
          - The output will include the details on the reconciliation status
            for all resources.
        required: false
        type: bool
    context:
        description:
          - The name of the kubeconfig context to use
        required: false
        type: str
    command:
        description:
          - The command and subcommand to be executed.
        required: true
        choices:
          - pkg-get
          - pkg-tree
          - pkg-diff
          - pkg-update
          - fn-render
          - live-init
          - live-apply

requirements:
    - kpt >= 1.0.0-beta.32

author:
    - Victor Morales (@electrocucaracha)
"""  # noqa: F841

EXAMPLES = r"""
- name: Fetch nephio-system package
  kpt:
    repo_uri: https://github.com/nephio-project/nephio-packages.git
    pkg_path: nephio-system
    version: @nephio-system/v6
    local_dest_directory: /opt/nephio-system
    command: pkg-get

- name: Get nephio-system package content
  kpt:
    directory: /opt/nephio-system/
    command: pkg-tree
"""  # noqa: F841

RETURN = r"""
rc:
    description: The command return code (0 means success)
    returned: always
    type: int
cmd:
    description: The command executed by the task
    returned: always
    type: str
stdout:
    description: The command standard output
    returned: changed
    type: str
stdout_lines:
    description: A list of strings, each containing one item per line from the
                 original output.
    returned: changed
    type: str
stderr:
    description: Output on stderr
    returned: changed
    type: str
stderr_lines:
    description: A list of strings, each containing one item per line from the
                 original error.
    returned: changed
    type: str
"""  # noqa: F841


class KptClient:
    def __init__(self, module) -> None:
        self._module = module
        self._kpt_cmd_path = "/usr/local/bin/kpt"

    def _run(self, cmd, changed=True, cwd=None):
        result = dict(changed=False, rc=0, cmd=" ".join(cmd))
        try:
            kpt_result = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
            result["changed"] = changed
            result["stdout"] = kpt_result.stdout
            result["stdout_lines"] = kpt_result.stdout.splitlines()
        except subprocess.CalledProcessError as kptexc:
            result["rc"] = kptexc.returncode
            result["stderr"] = kptexc.stderr
            result["stderr_lines"] = kpt_result.stderr.splitlines()
            self._module.fail_json(msg="Failed to fetch the package", **result)

        self._module.exit_json(**result)

    # Show resources in the current directory.
    def pkg_tree(self, directory, **kwargs):
        cmd = [self._kpt_cmd_path, "pkg", "tree"]
        if directory:
            cmd.append(directory)
        self._run(cmd, False)

    # Fetch a package from a git repo.
    def pkg_get(
        self,
        repo_uri,
        pkg_path,
        local_dest_directory,
        version,
        strategy,
        for_deployment,
        **kwargs
    ):
        cmd = [self._kpt_cmd_path, "pkg", "get"]
        cmd.append(
            "{}/{}{}".format(
                repo_uri,
                pkg_path,
                "@" + version if version else "",
            )
        )
        if local_dest_directory:
            cmd.append(local_dest_directory)
        if for_deployment:
            cmd.append("--for-deployment")
        if strategy and strategy in [
            "resource-merge",
            "fast-forward",
            "force-delete-replace",
        ]:
            cmd.extend(["--strategy", strategy])

        result = dict(changed=False, rc=0, cmd=" ".join(cmd))

        dest = (
            local_dest_directory
            if local_dest_directory
            else "./" + pkg_path.split("/")[-1]
        )
        if not os.path.exists(dest):
            self._run(cmd)
        self._module.exit_json(**result)

    # Show differences between a local package and upstream.
    def pkg_diff(
        self, pkg_path, version, diff_type, diff_tool, diff_tool_opts, **kwargs
    ):
        cmd = [self._kpt_cmd_path, "pkg", "diff"]
        if pkg_path:
            cmd.append(
                "{}{}".format(
                    pkg_path,
                    "@" + version if version else "",
                )
            )
            cmd.append(pkg_path)
        if diff_type and diff_type in ["local", "remote", "combined", "3way"]:
            cmd.extend(["--diff-type", diff_type])
        if diff_tool:
            cmd.extend(["--diff-tool", diff_tool])
        if diff_tool_opts:
            cmd.extend(["--diff-tool-opts", diff_tool_opts])
        self._run(cmd, False)

    # Apply upstream package updates.
    def pkg_update(self, pkg_path, version, strategy, **kwargs):
        cmd = [self._kpt_cmd_path, "pkg", "update"]
        if pkg_path:
            cmd.append(
                "{}{}".format(
                    pkg_path,
                    "@" + version if version else "",
                )
            )
        if strategy and strategy in [
            "resource-merge",
            "fast-forward",
            "force-delete-replace",
        ]:
            cmd.extend(["--strategy", strategy])
        self._run(cmd, cwd=os.path.dirname(pkg_path))

    # Render a package.
    def fn_render(
        self, pkg_path, allow_exec, image_pull_policy, output, results_dir, **kwargs
    ):
        cmd = [self._kpt_cmd_path, "fn", "render"]
        if pkg_path:
            cmd.append(pkg_path)
        if allow_exec:
            cmd.extend(["--allow-exec", allow_exec])
        if image_pull_policy:
            cmd.extend(["--image-pull-policy", image_pull_policy])
        if output:
            cmd.extend(["--output", output])
        if results_dir:
            cmd.extend(["--results-dir", results_dir])
        self._run(cmd, False)

    # Initialize a package with the information needed for inventory tracking.
    def live_init(
        self, pkg_path, force, inventory_id, name, namespace, rg_file, context, **kwargs
    ):
        cmd = [self._kpt_cmd_path, "live", "init"]
        if pkg_path:
            cmd.append(pkg_path)
        if force:
            cmd.extend(["--force", force])
        if inventory_id:
            cmd.extend(["--inventory-id", inventory_id])
        if name:
            cmd.extend(["--name", name])
        if namespace:
            cmd.extend(["--namespace", namespace])
        if rg_file:
            cmd.extend(["--rg-file", rg_file])
        if context:
            cmd.extend(["--context", context])
        self._run(cmd)

    # Apply a package to the cluster (create, update, prune).
    def live_apply(
        self,
        pkg_path,
        dry_run,
        field_manager,
        force_conflicts,
        install_resource_group,
        inventory_policy,
        output,
        prune_propagation_policy,
        prune_timeout,
        reconcile_timeout,
        server_side,
        show_status_events,
        context,
        **kwargs
    ):
        cmd = [self._kpt_cmd_path, "live", "apply"]
        if pkg_path:
            cmd.append(pkg_path)
        if dry_run:
            cmd.extend(["--dry-run", dry_run])
        if field_manager:
            cmd.extend(["--field-manager", field_manager])
        if force_conflicts:
            cmd.extend(["--force-conflicts", force_conflicts])
        if install_resource_group:
            cmd.extend(["--install-resource-group", install_resource_group])
        if inventory_policy:
            cmd.extend(["--inventory-policy", inventory_policy])
        if output:
            cmd.extend(["--output", output])
        if prune_propagation_policy:
            cmd.extend(["--prune-propagation-policy", prune_propagation_policy])
        if prune_timeout:
            cmd.extend(["--prune-timeout", prune_timeout])
        if reconcile_timeout:
            cmd.extend(["--reconcile-timeout", reconcile_timeout])
        if server_side:
            cmd.extend(["--server-side", server_side])
        if show_status_events:
            cmd.extend(["--show-status-events", show_status_events])
        if context:
            cmd.extend(["--context", context])
        self._run(cmd, False)


def main():
    module_args = dict(
        repo_uri=dict(type="str", required=False),
        pkg_path=dict(type="str", required=False),
        version=dict(type="str", required=False),
        local_dest_directory=dict(type="str", required=False),
        strategy=dict(type="str", required=False),
        for_deployment=dict(type="bool", required=False),
        directory=dict(type="str", required=False),
        diff_type=dict(type="bool", required=False),
        diff_tool=dict(type="str", required=False),
        diff_tool_opts=dict(type="str", required=False),
        allow_exec=dict(type="str", required=False),
        image_pull_policy=dict(type="str", required=False),
        output=dict(type="str", required=False),
        results_dir=dict(type="str", required=False),
        force=dict(type="bool", required=False),
        inventory_id=dict(type="str", required=False),
        name=dict(type="str", required=False),
        namespace=dict(type="str", required=False),
        rg_file=dict(type="str", required=False),
        dry_run=dict(type="bool", required=False),
        field_manager=dict(type="str", required=False),
        force_conflicts=dict(type="bool", required=False),
        install_resource_group=dict(type="bool", required=False),
        inventory_policy=dict(type="str", required=False),
        prune_propagation_policy=dict(type="str", required=False),
        prune_timeout=dict(type="str", required=False),
        reconcile_timeout=dict(type="str", required=False),
        server_side=dict(type="bool", required=False),
        show_status_events=dict(type="bool", required=False),
        context=dict(type="str", required=False),
        command=dict(type="str", required=True),
    )
    module = AnsibleModule(argument_spec=module_args, supports_check_mode=False)

    client = KptClient(module)
    functions = {
        "pkg-get": client.pkg_get,
        "pkg-tree": client.pkg_tree,
        "pkg-diff": client.pkg_diff,
        "pkg-update": client.pkg_update,
        "fn-render": client.fn_render,
        "live-init": client.live_init,
        "live-apply": client.live_apply,
    }
    functions[module.params["command"]](**module.params)


if __name__ == "__main__":
    main()

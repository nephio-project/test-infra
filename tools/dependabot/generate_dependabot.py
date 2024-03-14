# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2024 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################

import os

def generate_dependabot_config(root_dir):
    output = """
# SPDX-license-identifier: Apache-2.0
##############################################################################
# Copyright (c) 2024 The Nephio Authors.
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Apache License, Version 2.0
# which accompanies this distribution, and is available at
# http://www.apache.org/licenses/LICENSE-2.0
##############################################################################
#
# This file is generated, do not edit it manually
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: daily
    open-pull-requests-limit: 99
"""

    for foldername, _, filenames in os.walk(root_dir):
        for filename in filenames:
            if filename == 'go.mod':
                print(f"Found go.mod in {os.path.abspath(foldername)}")
                rel_path = os.path.relpath(os.path.abspath(foldername)).replace("./", "/")
                ecosystem = "gomod"
                interval = "daily"
                block = package_ecosystem(ecosystem, rel_path, interval)
                output += "\n" + block
            elif filename == 'Dockerfile':
                print(f"Found Dockerfile in {os.path.abspath(foldername)}")
                rel_path = os.path.relpath(os.path.abspath(foldername)).replace("./", "/")
                ecosystem = "docker"
                interval = "weekly"
                block = package_ecosystem(ecosystem, rel_path, interval)
                output += "\n" + block
            elif filename == 'package.json':
                print(f"Found package.json in {os.path.abspath(foldername)}")
                rel_path = os.path.relpath(os.path.abspath(foldername)).replace("./", "/")
                ecosystem = "npm"
                interval = "daily"
                block = package_ecosystem(ecosystem, rel_path, interval)
                output += "\n" + block

    output_file = ".github/dependabot.yml"

    with open(output_file, "w", encoding="utf-8") as file:
        print(f"*** Writing output to {output_file}")
        file.write(output)

def package_ecosystem(ecosystem, rel_path, interval):
    block = f"""
  - package-ecosystem: {ecosystem}
    directory: {rel_path}
    schedule:
      interval: {interval}
"""
    return block

root_directory = '.'

generate_dependabot_config(root_directory)

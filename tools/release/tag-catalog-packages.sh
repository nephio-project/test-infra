#!/bin/bash
set -e

# This script creates, updates, or deletes tags for the Nephio catalog repository.
# Make sure to keep it updated as we add/move/remove/rename packages in the catalog!
#
# In addition to the overall release tag, it creates individual Porch-compatible tags
# for all the KRM packages.
#
# We have decided that it's easiest to unify all packages around one version, the
# overall Nephio release version, e.g. v2.0.1. Thus if one package gets updated, we
# *don't* bump its individual version. Rather, this version will be updated together
# with all packages when we cut a Nephio release.

# Usage:
#
# You should run this script at a local clone of this repository:
#
#     https://github.com/nephio-project/catalog
#
# Make sure to set NEPHIO_VERSION when running it (or edit the default here):
#
#   NEPHIO_VERSION=v2.0.1 tag-catalog-packages.sh
#
# It will create/update your local tags. To push them to the GitHub, run:
#
#   git push --tags
#
# If you're updating existing tags, add "--force".
#
# Note that because tagging does not follow the usual merge process, you want to be
# very careful about updating or deleting existing tags on GitHub! Reconstructing
# deleted tags can be challenging.

# A note on what "Porch-compatible tags" means:
#
# When Porch sees a "revision" property for a package (for example in the upstream
# of a PackageVariant), it applies this to the referenced Repository. If it is a git
# repository, then the "revision" becomes a tag. The tag is expected to follow the
# *absolute* directory location of the package within the git repository, plus "/",
# plus the "revision". So that's what we're creating here.
#
# Note that a git-based Repository also has a "directory" property. This is *not*
# used for tags, which always require the *absolute* directory, as mentioned above.
# However, it is used for accessing the files. So, for example, the "package" property
# in the upstream of a PackageVariant will be *relative* to this directory.

NEPHIO_VERSION=${NEPHIO_VERSION:-v2.0.0}
NEPHIO_REMOTE=${NEPHIO_REMOTE:-origin}

function tag() {
    # Local
    git tag --force "$1"
}

# Unused right now, but here if you want to modify the script to delete tags
function untag() {
    # Local
    git tag --delete "$1" || true

    # Remote
    git push --delete "$NEPHIO_REMOTE" "$1" || true
}

# Overall release tag
tag "$NEPHIO_VERSION"

#
# Porch-compatible package tags
#

tag "distros/gcp/cc-rootsync/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/cert-manager/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/nephio-controllers/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/nephio-controllers/app/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/nephio-controllers/crd/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/nephio-webui/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/network-config/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/network-config/app/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/network-config/crd/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/porch/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/resource-backend/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/resource-backend/app/$NEPHIO_VERSION"
tag "distros/gcp/nephio-mgmt/resource-backend/crd/$NEPHIO_VERSION"

# Placeholder
#tag "distros/openshift/$NEPHIO_VERSION"

tag "distros/sandbox/cert-manager/$NEPHIO_VERSION"
tag "distros/sandbox/gitea/$NEPHIO_VERSION"
tag "distros/sandbox/metallb/$NEPHIO_VERSION"
tag "distros/sandbox/metallb-sandbox-config/$NEPHIO_VERSION"
tag "distros/sandbox/network/$NEPHIO_VERSION"
tag "distros/sandbox/repository/$NEPHIO_VERSION"

tag "infra/capi/cluster-capi/$NEPHIO_VERSION"
tag "infra/capi/cluster-capi-infrastructure-docker/$NEPHIO_VERSION"
tag "infra/capi/cluster-capi-kind/$NEPHIO_VERSION"
tag "infra/capi/cluster-capi-kind-docker-templates/$NEPHIO_VERSION"
tag "infra/capi/kindnet/$NEPHIO_VERSION"
tag "infra/capi/local-path-provisioner/$NEPHIO_VERSION"
tag "infra/capi/multus/$NEPHIO_VERSION"
tag "infra/capi/nephio-workload-cluster/$NEPHIO_VERSION"
tag "infra/capi/vlanindex/$NEPHIO_VERSION"

tag "infra/gcp/cc-cluster-gke-std-csr-cs/$NEPHIO_VERSION"
tag "infra/gcp/cc-repo-csr/$NEPHIO_VERSION"
tag "infra/gcp/nephio-blueprint-repo/$NEPHIO_VERSION"
tag "infra/gcp/nephio-workload-cluster-gke/$NEPHIO_VERSION"

tag "nephio/core/configsync/$NEPHIO_VERSION"
tag "nephio/core/nephio-operator/$NEPHIO_VERSION"
tag "nephio/core/porch/$NEPHIO_VERSION"
tag "nephio/core/workload-crds/$NEPHIO_VERSION"

tag "nephio/optional/flux-helm-controllers/$NEPHIO_VERSION"
tag "nephio/optional/network-config/$NEPHIO_VERSION"
tag "nephio/optional/resource-backend/$NEPHIO_VERSION"
tag "nephio/optional/rootsync/$NEPHIO_VERSION"
tag "nephio/optional/stock-repos/$NEPHIO_VERSION"
tag "nephio/optional/webui/$NEPHIO_VERSION"

tag "workloads/free5gc/free5gc-cp/$NEPHIO_VERSION"
tag "workloads/free5gc/free5gc-operator/$NEPHIO_VERSION"
tag "workloads/free5gc/pkg-example-amf-bp/$NEPHIO_VERSION"
tag "workloads/free5gc/pkg-example-smf-bp/$NEPHIO_VERSION"
tag "workloads/free5gc/pkg-example-upf-bp/$NEPHIO_VERSION"

tag "workloads/oai/oai-ran-operator/$NEPHIO_VERSION"
tag "workloads/oai/package-variants/$NEPHIO_VERSION"
tag "workloads/oai/pkg-example-cucp-bp/$NEPHIO_VERSION"
tag "workloads/oai/pkg-example-cuup-bp/$NEPHIO_VERSION"
tag "workloads/oai/pkg-example-du-bp/$NEPHIO_VERSION"
tag "workloads/oai/pkg-example-ue-bp/$NEPHIO_VERSION"

tag "workloads/tools/ueransim/$NEPHIO_VERSION"

#git push --tags --force

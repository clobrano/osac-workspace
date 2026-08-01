# Obtaining a pull secret and AAP license

**Read this before `cluster-tool boot` or running refresh.**

The `boot` command requires a **pull secret** for all deployment types. The **AAP license** is additionally required when running refresh to install VMaaS or CaaS. Place these files under the values directory for your deployment type inside `osac-installer/` (a subdirectory of the `osac` mono-repo — paths below are relative to `osac-installer/`, not the `osac` repo root or `osac-workspace`):

| Deployment type | Pull secret path | AAP license path |
|----------------|-----------------|-----------------|
| SNO (bare) | `values/vmaas-ci/pull-secret.json` | Not needed (but required when installing VMaaS or CaaS via refresh — see their rows) |
| VMaaS | `values/vmaas-ci/pull-secret.json` | `values/vmaas-ci/license.zip` |
| CaaS | `values/caas-ci/pull-secret.json` | `values/caas-ci/license.zip` |

**Do not commit pull secrets or license manifests.** The `osac` mono-repo's root `.gitignore` already excludes `*pull-secret.json` and `license.zip`; keep files on disk only in your local clone.

## Pull secret

A pull secret provides credentials for authenticated container registries (Quay.io, registry.redhat.io). Obtain one from the [Red Hat Hybrid Cloud Console](https://console.redhat.com/openshift/install/pull-secret).

Download the JSON file and place it at the path above (e.g., `values/vmaas-ci/pull-secret.json`).

## AAP license

The AAP bootstrap job requires a subscription manifest (`license.zip`). Obtain it from the [Red Hat Customer Portal](https://access.redhat.com/) under **Subscriptions > Subscription Allocations > Export Manifest**.

Place `license.zip` at the path above (e.g., `values/vmaas-ci/license.zip`).

For full details, see the [Helm Deployment Guide](https://github.com/osac-project/osac/blob/main/osac-installer/docs/helm-deployment-guide.md#requirements).

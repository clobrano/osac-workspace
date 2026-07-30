# OSAC Feature Dimensions

This file defines the cross-cutting dimensions that every OSAC PRD and design
document must address. Both the PRD (`/prd`) and design (`/design`) workflows
should consult this file during their ingest phases to ensure comprehensive
coverage.

## Services

Every feature applies to one or more OSAC services. The PRD must declare
which services are in scope, and the design must address service-specific
implementation differences.

| Service | Description |
|---------|-------------|
| **BMaaS** | Bare Metal as a Service — provisioning and lifecycle of physical machines |
| **CaaS** | Cluster as a Service — Kubernetes cluster provisioning via Hosted Control Planes |
| **VMaaS** | Virtual Machines as a Service — KubeVirt-based compute instances |
| **MaaS** | Model as a Service — AI model serving and inference platform |
| **Enclave** | Day 1/Day 2 operations, installation monitoring, wizard UI |

## Personas

OSAC has four canonical personas (defined in `osac-docs/personas.md`). Features
must specify what each affected persona can see and do. Use these exact names
in user stories and workflow descriptions.

| Persona | Role | Examples |
|---------|------|----------|
| **Cloud Provider Admin** | Works for the cloud provider. Handles tenant onboarding, sets quotas, manages global catalogs, is a super-user who can see all tenants. | Tenant onboarding, quota management, global template catalogs, resource allocation |
| **Cloud Infrastructure Admin** | Works for the cloud provider. Manages core infrastructure (network, firewall, compute, storage). Integrates control plane with local infrastructure. | Specify inventory backends, network classes, IP pools, storage tiers, DNS, integrate with Netris/VAST/ESI |
| **Tenant Admin** | Works for the tenant organization. Manages their org's config, users, IDP, quotas, and org-specific catalogs. Can only see their own organization. | Create networking objects, manage tenant resources, onboard users, control template visibility |
| **Tenant User** | Works for the tenant organization. Self-service provisions cloud resources, manages full lifecycle. Prefers click-ops but wants API/CLI for automation. | Order machines/clusters/VMs via catalog, manage instance lifecycle, view quota utilization |

## Cross-Cutting Dimensions

For each dimension below, the PRD should state what's in scope vs. explicitly
out of scope.

**PRD vs Design:** The PRD states which user-facing behaviors are affected
and why. The design document specifies how (CRD fields, conditions, reconcile
logic, AAP templates, installer changes).

### Tenant Onboarding

How does the feature interact with tenant provisioning?

- RBAC requirements (new roles, permissions, policy changes)
- IDP integration (authentication flows, identity provider considerations)
- Auto-provisioned resources during tenant creation
- Tenant isolation implications

### Inventory

Which inventory backend(s) does the feature use or affect?

- Does the feature add new inventory backends or extend existing ones?
- Which services consume the inventory data?

### Provisioning

What provisioning mechanism does the feature use?

- Which provisioning backend(s) are involved?
- Lifecycle stages affected (create, start, stop, restart, delete)
- Power management considerations (BMaaS)
- Cluster vs. ComputeInstance vs. bare metal provisioning differences

### Networking

Which networking backend(s) are involved?

- Is the integration through the OSAC networking API or a side-channel?
- Does the feature add or modify networking API resources?
- NetworkClass configuration requirements (Cloud Infrastructure Admin)
- PublicIP pool management

### Storage

Does the feature involve persistent storage for tenant workloads?

- Can tenants create persistent volumes on provisioned clusters?
- Can tenants select a storage tier when creating persistent volumes?
- Can tenants and admins see whether storage is ready on a given cluster?
- Does the feature affect how storage is provisioned or configured for tenants during onboarding?
- Are there storage prerequisites that must be in place before clusters are provisioned?

*Design document specifies: storage provider details, API fields, driver
installation, credential management.*

### Installation

Does the feature require new deployment prerequisites or configuration?

- Does an admin need to configure new infrastructure before using the feature (e.g., storage backend reachable from hub cluster)?
- Does the feature add new configuration options for operators or admins?
- Are there CI pipeline changes needed?

*Design document specifies: Helm chart values, `osac/osac-installer`
script changes.*

#### Enclave Wizard Pipeline

Any feature that adds or modifies Helm values in `osac-installer` must consider the Enclave Wizard pipeline. The Wizard renders configuration controls automatically from the Helm chart's JSON Schema — no custom UI code is needed for standard fields.

**Pipeline:** `osac-installer` schema change → enclave OSAC plugin picks up the change → Enclave Wizard UI renders the control.

**When it applies:** Any feature that adds installer Helm values that operators configure during deployment (e.g., DNS provider, storage backend, feature toggles).

**Schema-type-to-control mapping:**

| JSON Schema type | Wizard UI control | Example |
|------------------|-------------------|---------|
| `enum` | Dropdown | DNS provider: `route53`, `infoblox` |
| `boolean` | Checkbox | Enable bundled PostgreSQL |
| `string` (no enum) | Free text input | External hostname |
| `integer` / `number` | Numeric input | Worker node count |

The schema file is [`osac-installer/charts/osac/values.schema.json`](https://github.com/osac-project/osac-installer/blob/main/charts/osac/values.schema.json). Validation rules, default values, and descriptions come from the schema — the Wizard enforces them automatically.

**`/design:decompose` must produce three artifacts** when the pipeline applies:

1. **osac-installer story** — add the Helm value to `values.schema.json` with proper type, default, and description
2. **Enclave plugin task** — pick up the schema change and expose the parameter (Component: `Enclave`)
3. **Enclave UI task** — render the control in the Wizard, blocked-by the plugin task (Component: `Enclave`)

**Complex additions:** If the feature requires custom UI logic beyond proxying a Helm value (e.g., multi-step wizards, conditional fields, API calls), flag the UI task as needing design discussion — the schema-driven approach won't cover it.

### E2E Testing

What E2E test coverage does the feature require in osac-test-infra (bootstrapped at `osac-test-infra/`)?

- Which user-visible flows must work for this milestone (happy path, error paths, edge cases)?
- Which API surfaces need E2E coverage via pytest (Fulfillment API, CRDs, catalog/templates)?
- Are there cross-service test scenarios (e.g., provisioning + networking)?
- What test infrastructure is required (pytest fixtures, env/config, test tenants/organizations)?

### Documentation

What user-facing documentation does the feature require?

- What user-facing documentation is needed (user guides, API reference, architecture docs)?
- API reference may live in component subdirectories (e.g. `osac/fulfillment-service/`) rather than `osac-docs/` alone.
- Which persona workflows need documented?
- Are there docs repo updates needed (`osac-docs/`, `enhancement-proposals/`)?
- Is documentation in scope for this milestone or explicitly deferred?
- Does the feature change existing documented workflows that need updating?

### UI

What UI support does the feature require in the osac-ui web console (bootstrapped at `osac-ui/`)?

- Which persona workflows need UI support? (osac-ui maps Keycloak roles to provider/tenant admin/user — Cloud Infrastructure Admin may have no console today)
- Which UI views/pages are affected (list, detail, create, edit / lifecycle actions)?
- Is UI in scope for this milestone or explicitly deferred (API/CLI-only acceptable)?
- Does the feature require new UI components or extend existing ones in osac-ui?
- Which Fulfillment API resources and catalog entries need console representation? (osac-ui uses the Fulfillment Public API via proxy — not direct CRD access)

#### Enclave Wizard UI tasks

Cloud Infrastructure Admin UI work goes through the Enclave Wizard pipeline
documented in the [Installation > Enclave Wizard Pipeline](#enclave-wizard-pipeline)
section. When a feature adds installer Helm values, `/design:decompose` must
produce the three-artifact chain (installer schema → plugin task → UI task)
with the UI task blocked-by the plugin task. See that section for the
schema-type-to-control mapping and task templates.

#### Jira component conventions

When a feature requires UI work, add UI tasks to the feature's regular epics
(not a separate UI epic). Each UI task for an affected persona gets an extra
component so it appears in the right Jira filter:

| Persona | Components |
|---------|------------|
| Cloud Infrastructure Admin | Epic's components + `Enclave` |
| Cloud Provider Admin | Epic's components + `UI` |
| Tenant Admin | Epic's components + `UI` |
| Tenant User | Epic's components + `UI` |

Only create UI tasks for personas affected by the feature. The per-component
Jira filters track UI work across services (CaaS, BMaaS, VMaaS, Core,
Enclave, Connectivity&Fabric, Storage) using these component assignments.

## User-Facing Behavior

For each service in scope, identify which user-observable behaviors the feature
affects. The PRD states what users can do or see; the design document specifies
the API surfaces, field names, and resource schemas that implement those
behaviors.

- What new capabilities do users gain? (e.g., tenants can provision clusters with storage, admins can see storage readiness across tenants)
- What existing behaviors change? (e.g., cluster provisioning now includes automatic storage setup)
- Which personas are affected and how?
- Which user-facing resources are affected? (e.g., ClusterOrder, ComputeInstance, Tenant, VirtualNetwork, StorageClass)

## Milestone Scoping

When writing a PRD or design, explicitly declare:

- **Target milestone** (e.g., 0.1, 0.2)
- **What's NOT covered** — dimensions or capabilities deferred to a later milestone (e.g., "No Networking API integration in 0.1", "No Storage API in 0.1")
- **Known risks and gaps** — dependencies, DNS requirements, third-party onboarding, etc.
- **Upgrades** — OSAC does not currently support upgrades, so data migration and backward compatibility are not concerns at this stage. State this explicitly if applicable.

# Networking Design Alignment

## When This Rule Applies

This rule applies when working on any Jira issue that is networking-related. A task is networking-related if ANY of these are true:

- The Jira issue has component **Connectivity&Fabric**
- The task touches networking resources: VirtualNetwork, Subnet, SecurityGroup, ExternalIP, ExternalIPPool, ExternalIPAttachment, NATGateway, NetworkClass
- The task touches networking objects: NICs, ports, interfaces, network attachments, bridges, VLANs, routes, or any L2/L3 plumbing
- The task touches per-resource attachment types: ComputeNetworkAttachment, ClusterNetworkAttachment, BareMetalNetworkAttachment
- The task touches the renamed legacy resources: PublicIP, PublicIPPool, PublicIPAttachment
- The task involves fabric managers (Netris, Neutron), K8s managers (OVN-Kubernetes, CUDN LocalNet, EVPN, DPU), or the dispatcher that resolves NetworkClass to managers
- The task involves MetalLB, IPAddressPool, VIP allocation, or load balancer plumbing
- The task involves HostType or HostPool networking interfaces (fabric, management, storage, lifecycle roles)
- The task involves VirtualNetwork peering, VPC concepts, or cross-VN connectivity
- The task affects how VMs, clusters, or bare-metal instances connect to networks
- The task involves DNS, CIDR allocation, tenant isolation at the network level, DNAT/SNAT, or security rules
- The task involves network metering, bandwidth, or QoS

## Required Action

**Before writing any code or plan**, read the relevant networking design documents from `enhancement-proposals/enhancements/`. Start with the unified design, then read the service-specific design that applies:

### Document hierarchy (read in order of relevance)

| Document | Path | Scope |
|----------|------|-------|
| **Unified Networking Design** | `OSAC-1433-unified-networking/design.md` | Master design — resource model, NetworkClass, two-manager architecture, ExternalIP rename |
| **Unified Networking PRD** | `OSAC-1433-unified-networking/prd.md` | Requirements, user stories, gaps analysis |
| **Default Networking Design** | `OSAC-1433-default-networking/design.md` | Auto-provisioned networking for tenants who don't configure explicit networks |
| **Default Networking PRD** | `OSAC-1433-default-networking/prd.md` | Default networking requirements and acceptance criteria |
| **VMaaS Networking Design** | `OSAC-1435-vmaas-networking/design.md` | VM-specific: KubeVirt integration, OVN bridge, VM subnet attachment |
| **VMaaS Networking PRD** | `OSAC-1435-vmaas-networking/prd.md` | VMaaS networking requirements and acceptance criteria |
| **CaaS Networking Design** | `OSAC-1436-caas-networking/design.md` | Cluster-specific: HCP node networking, cluster-to-fabric integration |
| **CaaS Networking PRD** | `OSAC-1436-caas-networking/prd.md` | CaaS networking requirements and acceptance criteria |
| **BMaaS Networking Design** | `OSAC-1437-bmaas-networking/design.md` | Bare-metal-specific: BaremetalInstance, direct fabric attachment |
| **BMaaS Networking PRD** | `OSAC-1437-bmaas-networking/prd.md` | BMaaS networking requirements and acceptance criteria |
| **DNS API** | `dns-api/README.md` | DNS record management |

### Key design decisions to align with

These are non-negotiable architectural decisions from the merged designs:

1. **Two-manager model**: `fabricManager` (Netris/Neutron — handles ALL physical networking) + optional `k8sManager` (bridges VMs to fabric via OVN). Never conflate the two.
2. **VMs are part of the fabric**: VMs join the physical network through the K8s manager bridge. Once on the fabric, they are treated identically to bare-metal and cluster nodes.
3. **ExternalIP replaces PublicIP**: The rename clarifies that addresses are external to the VirtualNetwork, not necessarily internet-routable. Both names coexist during migration (see memory: `publicip-to-externalip-migration`).
4. **Infrastructure-agnostic subnets**: The same Subnet can host VMs, BM servers, and cluster nodes. No per-service-type subnet variants.
5. **Uniform API**: VirtualNetwork, Subnet, SecurityGroup, ExternalIP, NATGateway serve VMaaS, CaaS, and BMaaS identically — no service-specific resource types for networking.
6. **One NetworkClass per deployment**: Provider-level CRD, tenants never interact with it.
7. **Fabric manager handles isolation**: Tenant isolation, ACLs, IP allocation, DNAT, SNAT, and inter-subnet L3 routing are all fabric manager responsibilities.
8. **Direction separation**: ExternalIPAttachment = inbound (DNAT) only, NATGateway = outbound (SNAT) only. These must never overlap or be conflated.
9. **Multi-NIC primary designation**: When a resource has >1 network attachment, exactly one must be `primary: true`. The primary attachment designates the default gateway, DNAT target, and SNAT source.
10. **DHCP-based IP assignment**: All resource types receive IPs via DHCP (VMs from OVN DHCP, BM and CaaS agents from fabric DHCP). No static IP configuration.
11. **Pluggable managers via ConfigMap**: Each manager ships a ConfigMap declaring type + capabilities. Adding a new manager = deploy ConfigMap + Ansible role, no API changes required.
12. **Default networking auto-provisioning**: Tenant onboarding creates VN + IPv4 Subnet + IPv6 Subnet + SG + NATGateway (dual-stack from NetworkClass defaults). `DefaultNetworkingReady` condition gates tenant readiness.

### Per-resource attachment types

The designs define three distinct attachment types with different fields — do not mix them up:

| Type | Fields | Used by |
|------|--------|---------|
| `ComputeNetworkAttachment` | subnet, security_groups, `primary` | ComputeInstance (VMaaS) |
| `ClusterNetworkAttachment` | subnet, security_groups (singular, no `primary`) | Cluster (CaaS) |
| `BareMetalNetworkAttachment` | subnet, security_groups, `interface`, `primary` | BaremetalInstance (BMaaS) |

### Deletion ordering

The designs establish strict deletion ordering with phased requeue. Violating this order causes finalizer leaks and stuck resources:

1. Delete auto-provisioned ExternalIPAttachment → wait for removal
2. Delete auto-provisioned ExternalIP → wait for removal
3. Remove finalizer from parent resource (ComputeInstance/Cluster/BaremetalInstance)
4. Manually created ExternalIP/ExternalIPAttachment persist — tenant manages their lifecycle
5. Default networking resources persist — they are tenant-scoped and shared

### How to use

- Read the unified design first to understand the resource model
- Read the service-specific design (both design.md and prd.md) for the service your issue affects
- **During planning**: verify the plan aligns with both the PRD requirements and the design decisions. Flag any deviation before proceeding.
- **During implementation**: verify the code matches the resource names, field names, relationships, and constraints defined in the designs and PRDs. Re-check alignment after each significant change.
- **During review**: check that PRs don't introduce networking concepts, resource names, field semantics, or lifecycle behavior that contradict the designs or PRDs. Verify deletion ordering, attachment type usage, and manager responsibilities match the documented architecture.
- If a Jira issue's requirements conflict with these designs, flag the conflict before implementing

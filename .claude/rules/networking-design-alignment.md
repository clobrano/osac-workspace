# Networking Design Alignment

## When This Rule Applies

This rule applies when working on any Jira issue that is networking-related. A task is networking-related if ANY of these are true:

- The Jira issue has component **Connectivity&Fabric**
- The task touches networking resources: VirtualNetwork, Subnet, SecurityGroup, ExternalIP, ExternalIPPool, ExternalIPAttachment, NATGateway, NetworkClass
- The task touches networking objects: NICs, ports, interfaces, network attachments, bridges, VLANs, routes, or any L2/L3 plumbing
- The task touches the renamed legacy resources: PublicIP, PublicIPPool, PublicIPAttachment
- The task involves fabric managers (Netris, Neutron), K8s managers (OVN-Kubernetes), or network provisioning
- The task affects how VMs, clusters, or bare-metal instances connect to networks
- The task involves DNS, CIDR allocation, tenant isolation at the network level, DNAT/SNAT, or security rules

## Required Action

**Before writing any code or plan**, read the relevant networking design documents from `enhancement-proposals/enhancements/`. Start with the unified design, then read the service-specific design that applies:

### Document hierarchy (read in order of relevance)

| Document | Path | Scope |
|----------|------|-------|
| **Unified Networking Design** | `OSAC-1433-unified-networking/design.md` | Master design — resource model, NetworkClass, two-manager architecture, ExternalIP rename |
| **Unified Networking PRD** | `OSAC-1433-unified-networking/prd.md` | Requirements, user stories, gaps analysis |
| **Default Networking** | `OSAC-1433-default-networking/design.md` | Auto-provisioned networking for tenants who don't configure explicit networks |
| **VMaaS Networking** | `OSAC-1435-vmaas-networking/design.md` | VM-specific: KubeVirt integration, OVN bridge, VM subnet attachment |
| **CaaS Networking** | `OSAC-1436-caas-networking/design.md` | Cluster-specific: HCP node networking, cluster-to-fabric integration |
| **BMaaS Networking** | `OSAC-1437-bmaas-networking/design.md` | Bare-metal-specific: BaremetalInstance, direct fabric attachment |
| **Networking UI** | `OSAC-1425-networking-ui-vmaas-scope/design.md` | UI for networking resources (VMaaS scope) |
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

### How to use

- Read the unified design first to understand the resource model
- Read the service-specific design only for the service your issue affects
- When implementing, verify your code matches the resource names, field names, and relationships defined in the designs
- When reviewing, check that PRs don't introduce networking concepts that contradict the designs
- If a Jira issue's requirements conflict with these designs, flag the conflict before implementing

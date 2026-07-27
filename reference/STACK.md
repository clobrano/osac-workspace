# Technology Stack

**Analysis Date:** 2026-07-27

## Languages

**Primary:**
- Go 1.26.3 - Used in `fulfillment-service`, `osac-operator`, and `bare-metal-fulfillment-operator`
- Python 3.13+ - Used in `osac-aap` for Ansible Automation Platform roles and playbooks (`osac-aap/pyproject.toml`)
- Python 3.14+ - Used in `fulfillment-service` for dev tooling (`fulfillment-service/pyproject.toml`)
- Python 3.11+ - Used in `osac-test-infra` for E2E tests (`osac-test-infra/pyproject.toml`)

**Secondary:**
- YAML - Kubernetes manifests, Helm charts, Ansible playbooks
- Protocol Buffers (proto3) - API definitions for gRPC services

## Runtime

**Environment:**
- Go 1.26.3 runtime for compiled services
- Python 3.14+ runtime for fulfillment-service dev tooling
- Python 3.13+ runtime for Ansible automation
- Python 3.11+ runtime for E2E tests (osac-test-infra)
- Kubernetes 1.31+ as deployment target (via Kind for testing, OpenShift for production)

**Package Manager:**
- Go modules for Go projects
- UV/pip for Python dependencies (`osac-aap/pyproject.toml`)

## Frameworks

**Core Services:**
- gRPC v1.82.1 - RPC framework for inter-service communication (`fulfillment-service/go.mod`)
- grpc-gateway v2.29.0 - HTTP/JSON to gRPC transcoding (`fulfillment-service/go.mod`)
- Buf v2 - Protocol Buffer management and code generation (`fulfillment-service/buf.yaml`)

**Web/API:**
- HTTP/2 support via `golang.org/x/net/http2` and `golang.org/x/net/http2/h2c`
- Prometheus HTTP handlers for metrics exposure

**Kubernetes:**
- controller-runtime v0.24.1 - Kubernetes operator development framework (`fulfillment-service/go.mod`, `osac-operator/go.mod`, `bare-metal-fulfillment-operator/go.mod`)
- Kubernetes client-go v0.36.2 - Official Kubernetes Go client (`fulfillment-service/go.mod`)
- kubevirt.io/api v1.8.4 - KubeVirt VM management (`osac-operator/go.mod`)
- multicluster-runtime v0.24.1 - Multi-cluster hub/remote operation (`osac-operator/go.mod`)
- OpenShift HyperShift API v0.0.0-20250331235933 - For cluster provisioning (`osac-operator/go.mod`)
- OVN-Kubernetes v0.0.0-20251211123925 - Advanced networking (`osac-operator/go.mod`)

**Testing:**
- Ginkgo v2.32.0 - BDD testing framework (same version across all repos)
- Gomega v1.42.1 - Assertion library
- Kind (Kubernetes-in-Docker) - Container-based Kubernetes clusters for integration tests (`fulfillment-service/internal/testing/kind.go`)

**Build/Dev:**
- Cobra v1.10.2 - CLI framework (`fulfillment-service/go.mod`)
- Make - Build orchestration
- Operator SDK v1.39.1 - Kubernetes operator tooling (`osac-operator/Makefile`)

**Ansible:**
- Ansible 11.4+ - Infrastructure automation platform (`osac-aap/pyproject.toml`)
- Ansible collections: amazon/aws, kubernetes/core, openstack/cloud - Infrastructure providers

## Key Dependencies

**Critical:**
- google.golang.org/protobuf v1.36.12 - Protocol Buffer runtime (`fulfillment-service/go.mod`)
- jackc/pgx/v5 v5.10.0 - PostgreSQL driver (`fulfillment-service/go.mod`)
- open-policy-agent/opa v1.18.2 - Authorization and policy evaluation (`fulfillment-service/go.mod`)
- golang-jwt/jwt v5.3.1 - JWT token handling (`fulfillment-service/go.mod`)

**Infrastructure:**
- prometheus/client_golang v1.23.2 - Prometheus metrics client (`fulfillment-service/go.mod`)
- jackc/pgerrcode - PostgreSQL error code handling (`fulfillment-service/go.mod`)
- golang-migrate/migrate v4.19.1 - Database migration tool (`fulfillment-service/go.mod`)

**Cloud/Infrastructure:**
- boto3/botocore - AWS SDK for Python (`osac-aap/pyproject.toml`)
- aiobotocore - Async AWS SDK (`osac-aap/pyproject.toml`)
- kubernetes - Python Kubernetes client (`osac-aap/pyproject.toml`)
- openstacksdk - OpenStack SDK (`osac-aap/pyproject.toml`)
- python-ironicclient - Ironic (bare metal service) client (`osac-aap/pyproject.toml`)
- python-esiclient - ESI (Emergence System Initiative) client (`osac-aap/pyproject.toml`)
- python-esileapclient - ESI LEAP (Location Elasticity and Provisioning) client (`osac-aap/pyproject.toml`)
- pydantic v2.11.3+ - Data validation framework (`osac-aap/pyproject.toml`)

**Networking:**
- envoyproxy/protoc-gen-validate - Protocol Buffer validation (`fulfillment-service/go.mod`)
- dnspython - DNS manipulation library (`osac-aap/pyproject.toml`)

**Development Utilities:**
- google/cel-go v0.29.2 - Common Expression Language for filtering and authorization (`fulfillment-service/go.mod`)
- go.uber.org/mock v0.6.0 - Mock code generation (`fulfillment-service/go.mod`)

## Configuration

**Environment:**
Services accept command-line flags rather than environment variables directly:
- Database URL: `--db-url` flag for PostgreSQL connection (`fulfillment-service/internal/database/database_flags.go`)
- gRPC Listener: `--grpc-listener-address` (default `localhost:8000`)
- HTTP Listener: `--http-listener-address` (default `localhost:8001`)
- Metrics Listener: `--metrics-listener-address` (default `localhost:8080`)
- Authentication type: `--grpc-authn-type` (guest or external)
- Tenancy logic: `--tenancy-logic` (guest, default, or serviceaccount)

**Build:**
- `buf.yaml` - Protocol Buffer linting and code generation configuration (`fulfillment-service/buf.yaml`)
- Makefile in each component - Build targets and container image management
- Containerfile (Podman/Docker) - Container image definitions

**Kubernetes Deployment:**
- Helm chart in `fulfillment-service/charts/service/` - Service deployment manifests
- Kustomize overlays in `fulfillment-service/manifests/` - Alternative deployment approach
  - Kind overlay for local testing

## Platform Requirements

**Development:**
- Go 1.26.3
- Python 3.14+ (fulfillment-service tooling), 3.13+ (osac-aap), 3.11+ (osac-test-infra)
- Kubernetes cluster (Kind for local testing) or access to OpenShift cluster
- PostgreSQL 15+ (container-based for local development)
- Protocol Buffer compiler (protoc) with Buf
- Docker or Podman for container operations
- Make and standard Unix tools

**Production:**
- OpenShift 4.x cluster (required for HyperShift and OVN-Kubernetes integration)
- PostgreSQL 15+ database
- Helm 3.x for deployment
- Keycloak for identity provider integration
- Prometheus for metrics collection (optional but recommended)

---

*Stack analysis: 2026-07-27*

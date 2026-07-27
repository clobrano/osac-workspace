# Testing Patterns

**Analysis Date:** 2026-07-27

## Test Framework

**Runner:**
- Ginkgo v2.32.0 (`github.com/onsi/ginkgo/v2`)
- Config: No explicit config file; configuration via environment variables and code

**Assertion Library:**
- Gomega (`github.com/onsi/gomega`)

**Run Commands:**
```bash
# Run unit tests only (excludes integration tests in it/)
ginkgo run -r internal

# Run specific package tests
ginkgo run internal/servers

# Run tests matching a name pattern
ginkgo run -r internal --focus="CreateCluster"

# Verbose output
ginkgo run -v internal/servers

# Skip tests matching pattern
ginkgo run -r internal --skip="database"

# Run integration tests (requires kind cluster and /etc/hosts entries)
ginkgo run it

# Preserve kind cluster for debugging
IT_KEEP_KIND=true ginkgo run it

# Run only setup phase
IT_KEEP_KIND=true ginkgo run --label-filter=setup it

# Use kustomize instead of Helm for integration tests
IT_DEPLOY_MODE=kustomize ginkgo run it

# Run all tests including integration
ginkgo run -r
```

## Test File Organization

**Location:**
- Unit tests: Co-located with source files in same package
- Integration tests: Separate `it/` directory at project root
- Test utilities: `internal/testing/` package with shared fixtures

**Naming:**
- Unit test files: `*_test.go` (e.g., `auth_context_test.go`)
- Suite setup files: `*_suite_test.go` (e.g., `auth_suite_test.go`)
- Integration test files: `it_*.go` (e.g., `it_access_test.go`)

**Structure:**
```
fulfillment-service/
├── internal/
│   ├── auth/
│   │   ├── auth_context.go
│   │   ├── auth_context_test.go
│   │   ├── auth_suite_test.go
│   │   └── ...
│   ├── servers/
│   │   ├── clusters_server.go
│   │   ├── clusters_server_test.go
│   │   ├── servers_suite_test.go
│   │   └── ...
│   └── testing/
│       ├── database_server.go
│       ├── tool.go
│       └── ...
├── it/
│   ├── it_suite_test.go
│   ├── it_access_test.go
│   └── ...
```

## Test Structure

**Suite Organization:**

```go
// In auth_suite_test.go
func TestAuth(t *testing.T) {
    RegisterFailHandler(Fail)
    RunSpecs(t, "Auth package")
}

var logger *slog.Logger

var _ = BeforeSuite(func() {
    var err error
    logger, err = logging.NewLogger().
        SetLevel(slog.LevelDebug.String()).
        SetWriter(GinkgoWriter).
        Build()
    Expect(err).ToNot(HaveOccurred())
})
```

**Individual Test Patterns:**

```go
// In auth_context_test.go
var _ = Describe("Subject inside context", func() {
    It("Returns the same subject that was added", func() {
        subject := &Subject{}
        ctx := ContextWithSubject(context.Background(), subject)
        extracted := SubjectFromContext(ctx)
        Expect(extracted).To(BeIdenticalTo(subject))
    })

    It("Panics if there is no subject", func() {
        ctx := context.Background()
        Expect(func() {
            SubjectFromContext(ctx)
        }).To(PanicWith("failed to get subject from context"))
    })
})
```

**Test Patterns:**
- Setup: `BeforeEach` for test-local setup, `BeforeSuite` for package-wide setup
- Teardown: `DeferCleanup()` for cleanup operations (called in reverse order)
- Assertions: Gomega matchers with fluent `Expect(value).To(Matcher)`
- Grouping: `Describe` blocks for test suites, `It` blocks for individual tests
- Nesting: `Describe` blocks can be nested for logical organization

## Mocking

**Framework:** `go.uber.org/mock` (uber-go/mock)

**Patterns:**

```go
// In source file (interface definition)
//go:generate mockgen -destination=attribution_logic_mock.go -package=auth . AttributionLogic
type AttributionLogic interface {
    DetermineAssignedCreators(ctx context.Context) (collections.Set[string], error)
}

// Generated mock is created in attribution_logic_mock.go
// Use in tests with gomock.Controller
```

**Mock Usage in Tests:**

```go
ctrl := gomock.NewController(t)
defer ctrl.Finish()

mockAttribution := auth.NewMockAttributionLogic(ctrl)
mockAttribution.EXPECT().
    DetermineAssignedCreators(gomock.Any()).
    Return(someSet, nil).
    Times(1)

// Pass mock to code under test
server, err := NewClustersServer().
    SetLogger(logger).
    SetAttributionLogic(mockAttribution).
    Build()
```

**What to Mock:**
- External service interfaces (auth logic, tenancy logic)
- Storage layer interfaces (DAO, database)
- Token sources (file, script, static)
- Infrastructure dependencies (Kubernetes client, OPA)

**What NOT to Mock:**
- Concrete business logic implementations
- Value types (strings, numbers, protobuf messages)
- Standard library types
- Context (use real context.Background())

## Fixtures and Factories

**Test Data:**

```go
// Builder pattern for test proto messages
request := publicv1.ClustersListRequest_builder{}.Build()

// Helper to create test subjects
subject := &Subject{
    ID:           "test-user",
    Type:         SubjectTypeUser,
    Authenticated: true,
}
```

**Location:**
- Shared test utilities: `internal/testing/` (e.g., `DatabaseServer`, `Tool`)
- Package-local test data: Defined inline in test files
- Database setup: `dao.CreateTables[T]()` creates schema dynamically

**Common Fixtures:**

```go
// In servers_suite_test.go - package-wide setup
var (
    logger      *slog.Logger
    server      *DatabaseServer
    attribution auth.AttributionLogic
    tenancy     auth.TenancyLogic
)

// In test BeforeEach
ctx := context.Background()
db := server.MakeDatabase()
pool, err := pgxpool.New(ctx, db.MakeURL())
tm, err := database.NewTxManager().
    SetLogger(logger).
    SetPool(pool).
    Build()
tx, err := tm.Begin(ctx)
ctx = database.TxIntoContext(ctx, tx)
err = dao.CreateTables[*privatev1.Cluster](ctx)
```

## Coverage

**Requirements:** No explicit coverage targets enforced, but tests are comprehensive

**View Coverage:**
- Manual: Run `ginkgo` with `-cover` flag (not commonly used in this project)
- Unit test coverage typically checked in CI/CD pipeline (not documented in CLAUDE.md)

## Linting

**fulfillment-service:**
- Go + proto lint: `uv run dev.py lint` (runs Go linter and `buf lint`)
- Proto only: `buf lint`
- Python only: `uv run ruff check`
- Pre-commit hooks run `buf lint` (proto) and Go lint automatically

**osac-operator:**
- Go lint: `make lint` (golangci-lint)

**osac-test-infra:**
- Python lint: `make lint` (ruff check + ruff format --check)
- Pre-commit: `pre-commit run --all-files` (yamllint, ansible-lint, standard hooks)

## Test Types

**Unit Tests:**
- Scope: Individual functions/methods within a package
- Location: `internal/*/` directories
- Approach: Isolated, use mocks for dependencies, test single behavior per case
- Command: `ginkgo run -r internal`
- Example: `auth_context_test.go` tests context insertion and extraction in isolation

**Integration Tests:**
- Scope: Multiple components working together, requires infrastructure
- Location: `it/` directory at project root
- Approach: Full kind cluster with PostgreSQL, Keycloak, gRPC/REST endpoints
- Setup: Environment variables (IT_KEEP_KIND, IT_DEPLOY_MODE, Debug)
- Command: `ginkgo run it`
- Infrastructure requirements:
  - Kind cluster named `fulfillment-service-it`
  - `/etc/hosts` entries for DNS resolution:
    - `127.0.0.1 keycloak.keycloak.svc.cluster.local`
    - `127.0.0.1 fulfillment-api.osac.svc.cluster.local`
    - `127.0.0.1 fulfillment-internal-api.osac.svc.cluster.local`
  - Keycloak deployment for auth
  - PostgreSQL for data storage
  - Helm/Kustomize for application deployment
- Example: `it_access_test.go` tests API access control across public/private endpoints with real clients

**E2E Tests (osac-test-infra):**
- Framework: pytest with pytest-xdist (parallel execution, default 4 workers)
- Location: `osac-test-infra/tests/` (separate repo)
- Test suites: `vmaas/` (ComputeInstance), `caas/` (ClusterOrder), `storage/` (tenant storage), `catalog/` (CatalogItem)
- Client abstractions: `tests/core/` (GRPCClient, K8sClient, OsacCLI, polling helpers)
- Session fixtures: gRPC client, K8s client, CLI wrapper, JWT tokens (`tests/conftest.py`)
- Two-kubeconfig design: hub cluster (CRs) + workload cluster (VMs via `OSAC_VM_KUBECONFIG`)
- Run commands:

  ```bash
  cd osac-test-infra
  uv sync
  make test                                    # All suites (parallel, 4 workers)
  make test-vmaas                              # VMaaS suite
  make test-caas                               # CaaS suite
  make test-storage                            # Storage suite
  TEST=test_compute_instance_lifecycle make test-vmaas  # Single test filter
  uv run pytest tests/vmaas/ -v --tb=short -n 0        # Sequential (debugging)
  ```

- Lint: `make lint` (ruff check + ruff format --check)
- Dependencies: pytest>=8.0, pytest-xdist>=3.0, pyyaml>=6.0, websocket-client>=1.6

**osac-operator Tests:**
- Framework: Ginkgo + Gomega with envtest (real etcd + kube-apiserver)
- Unit tests: `make test` (runs `go test` excluding `test/integration/`, with coverage)
- Integration tests: `make test-integration` (runs test + test-kustomize + test-smoke)
- Kustomize validation: `make test-kustomize` (catches missing files in kustomization.yaml)
- Smoke test: `make test-smoke` (creates kind cluster `osac-test`, applies CRDs, verifies)
- Kind integration: `make test-integration-kind` (`go test ./test/integration/ -v -ginkgo.v`)
- Lint: `make lint` (golangci-lint)
- Clean up: `kind delete cluster --name osac-test`

## Common Patterns

**Async Testing:**

```go
It("Handles async operations", func() {
    done := make(chan bool)

    go func() {
        // async work
        done <- true
    }()

    Eventually(done).Should(Receive())
})

// Or use Ginkgo's built-in async support
Eventually(func() error {
    // poll this
    return err
}).Should(Succeed())
```

**Error Testing:**

```go
It("Returns not found error", func() {
    _, err := client.Get(ctx, req)
    Expect(err).To(MatchError(&dao.ErrNotFound{}))
})

It("Panics on missing context", func() {
    Expect(func() {
        SubjectFromContext(context.Background())
    }).To(PanicWith("failed to get subject from context"))
})

It("Fails on invalid build", func() {
    server, err := NewClustersServer().
        // missing required fields
        Build()
    Expect(err).To(MatchError("logger is mandatory"))
    Expect(server).To(BeNil())
})
```

**Database Testing Pattern:**

```go
BeforeEach(func() {
    ctx = context.Background()
    db := server.MakeDatabase()
    defer db.Close()

    pool, err := pgxpool.New(ctx, db.MakeURL())
    Expect(err).ToNot(HaveOccurred())
    DeferCleanup(pool.Close)

    tm, err := database.NewTxManager().
        SetLogger(logger).
        SetPool(pool).
        Build()
    Expect(err).ToNot(HaveOccurred())

    tx, err := tm.Begin(ctx)
    Expect(err).ToNot(HaveOccurred())
    DeferCleanup(func() {
        err := tm.End(ctx, tx)
        Expect(err).ToNot(HaveOccurred())
    })
    ctx = database.TxIntoContext(ctx, tx)

    // Create tables dynamically
    err = dao.CreateTables[*privatev1.Cluster](ctx)
    Expect(err).ToNot(HaveOccurred())
})
```

**Client Testing (Integration):**

```go
It("Works with real gRPC client", func() {
    ctx := context.Background()

    // Get connection (public user auth)
    client := publicv1.NewClustersClient(tool.UserConn())

    // Make request using proto builder
    req := publicv1.ClustersListRequest_builder{}.Build()
    resp, err := client.List(ctx, req)

    Expect(err).ToNot(HaveOccurred())
    Expect(resp).ToNot(BeNil())
})
```

## Test Configuration

**Environment Variables (Integration Tests):**
- `IT_KEEP_KIND=true` - Preserve kind cluster after tests
- `IT_KEEP_SERVICE=true` - Keep application deployment after tests
- `IT_DEPLOY_MODE=kustomize` - Use kustomize instead of Helm
- `Debug=true` - Enable debugger in container image

**Suite Setup Pattern:**

```go
type Config struct {
    KeepKind    bool   `envconfig:"keep_kind" default:"false"`
    KeepService bool   `envconfig:"keep_service" default:"false"`
    DeployMode  string `envconfig:"deploy_mode" default:"helm"`
    Debug       bool   `envconfig:"debug" default:"false"`
}

var _ = BeforeSuite(func() {
    err := envconfig.Process("IT", &config)
    Expect(err).ToNot(HaveOccurred())
})
```

---

*Testing analysis: 2026-07-27*

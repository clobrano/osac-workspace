# Protocol Buffer Conventions

Proto definitions live in `osac/fulfillment-service`. Read [`osac/fulfillment-service/docs/API.md`](../../osac/fulfillment-service/docs/API.md) before adding or modifying any `.proto` file — it is the authoritative source for all API conventions (object structure, naming, services, request/response patterns, REST transcoding, enums, conditions, references, and documentation requirements).

OSAC follows [Kubernetes API conventions](https://github.com/kubernetes/community/blob/main/contributors/devel/sig-architecture/api-conventions.md) adapted for protobuf.

## Workflow

- Always run `buf lint` from `osac/fulfillment-service/` before committing proto changes
- Regenerate code by running `buf generate` from `osac/fulfillment-service/` after proto changes
- `SERVICE_SUFFIX` lint rule is intentionally excluded in `buf.yaml`

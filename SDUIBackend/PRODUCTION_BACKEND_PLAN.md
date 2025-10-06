# Production-Ready SDUI Backend Plan

## Vision
Build a resilient Go service that powers PestGenie’s technician application with personalised server-driven UI payloads, secure synchronisation APIs, and operational tooling ready for Cloud Run deployment.

## Guiding Principles
- **Reliability:** Graceful degradation, retries, health checks, and observability.
- **Security:** Secret management via Google Secret Manager, principle of least privilege, audit-ready logging.
- **Maintainability:** Clear separation of layers (transport, domain, persistence), comprehensive tests, documentation, automated CI/CD.
- **Scalability:** Stateless compute on Cloud Run, backing store per environment, feature-flag friendly architecture for rapid SDUI iteration.

## Milestones & Deliverables

### 1. Configuration & Secrets (Week 1)
- Establish configuration package supporting hierarchy (env vars, secret manager, defaults).
- Implement typed config structs (server, datastore, telemetry, auth).
- Integrate Secret Manager client with optional local fallback (.env). Handle rotation gracefully.
- Unit tests for config loading/validation.

### 2. Core Domain Foundations (Week 1-2)
- Define domain models for technicians, routes, screen variants, sync payloads.
- Introduce repository interfaces (`internal/domain/repository`) with in-memory adapter for dev and stub Cloud SQL/Firestore adapter.
- Implement domain services: `ScreenService`, `SyncService`, `NotificationService` (interfaces + base logic).
- Add deterministic test data fixtures.

### 3. Transport Layer Enhancements (Week 2)
- Refine chi router with middleware stack: structured logging (zerolog), request ID, panic recovery, metrics (OpenTelemetry), auth context stub.
- Provide `/healthz` (liveness) and `/readyz` (readiness) endpoints.
- Implement API versioning (`/v1`, future `/v2`).
- Introduce consistent API error format (RFC 7807 JSON) and response helpers.

### 4. Persistence & Data Flows (Week 2-3)
- Decide data store (initial: Firestore). Abstract via repository interfaces; support in-memory + Firestore implementations.
- Implement data access for routes, screens, sync queues. Batch operations, idempotent updates.
- Add caching layer (optional) for SDUI templates.
- Unit/integration tests using Firestore emulator (documented in README).

### 5. Feature Completion (Week 3)
- SDUI endpoint fetches templates from persistence, merges technician/route context, returns canonical schema.
- Sync endpoints persist uploads, trigger pub/sub or task queue stub for async processing.
- Device registration stores tokens and enqueues notifications pipeline.
- Add input validation (ozzo-validation or similar) + tests.

### 6. Observability & Operations (Week 3-4)
- Integrate OpenTelemetry export (stdout for dev, Cloud Trace for prod) + structured logging.
- Metrics: request latency, error counts, queue length, template cache hit rate.
- Cloud Logging correlation IDs, severity levels.
- Document runbooks (latency, error response handling, secret rotation).

### 7. CI/CD & Release Management (Week 4)
- GitHub Actions workflow: lint (golangci-lint), gofmt check, unit tests, build docker image.
- Deploy workflow (manual approval) to Cloud Run with Cloud Build. Manage service account & workload identity.
- Artifact tagging and SBOM (slsa-framework/slsa-github-generator optional).

### 8. Documentation & Handover (Week 4)
- Update README with local dev, tests, deployment, troubleshooting.
- ADRs for key decisions (datastore choice, auth approach).
- Onboarding playbook for new contributors.

## Work Breakdown Structure

1. **Config & Secrets**
   - `internal/config/config.go`: load, validate.
   - `internal/secret/manager.go`: fetch secrets, memoize.
   - Tests under `internal/config`.

2. **Domain Layer**
   - `internal/domain/models/*.go`: technician, route, screen, sync.
   - `internal/domain/services/*.go`: screen, sync, notification.
   - `internal/domain/mocks/*.go`: for tests.

3. **Persistence**
   - `internal/store/firestore/*`: adapters.
   - `internal/store/memory/*`: local.
   - Shared interfaces.

4. **Transport**
   - `internal/http/router.go`: composer.
   - Middleware packages for logging, auth, metrics.
   - Error response utilities.

5. **Observability**
   - `internal/telemetry/metrics.go` / `tracing.go`.
   - Logging config, correlation IDs.

6. **DevOps**
   - `.github/workflows/backend-ci.yml` & `backend-deploy.yml`.
   - `Makefile` or taskfile for commands.
   - Dockerfile already present (review for instrumentation).

## Risk Mitigation
- **Datastore choice**: start with Firestore emulator; design repository interfaces to swap Cloud SQL later.
- **Secret management**: fallback to local `.env` for dev; ensure secret fetch is cached.
- **Testing coverage**: enforce via CI threshold; integrate go test with race detector in pipeline.
- **Operational support**: provide dashboards (Cloud Monitoring) and alerting hooks (document metrics names).

## Definition of Done
- All endpoints backed by persistence and validation.
- Config/secrets, logging, metrics integrated.
- Unit tests + integration smoke tests passing; CI green.
- Docker image runs locally; Cloud Run deployment verified.
- Documentation and onboarding notes complete.


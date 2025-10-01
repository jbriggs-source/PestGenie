# AGENTS.md — Repo Guidance for Coding Agents

> This document tells coding agents how to read, modify, build, test, and deploy this project.  
> Stack: **iOS (SwiftUI)** client • **Go** backend • **Google Cloud Platform (GCP)** infra.

---

## 0) Prime Directives

1. **Plan before you change**  
   - Always produce a brief plan first: affected files, approach, risks, tests to add.  
   - Ask for approval for cross-cutting changes.

2. **Local first, safe by default**  
   - Run locally and pass tests before proposing commits.  
   - Never create or commit secrets. Use placeholders and document where secrets come from.

3. **Small, reviewable diffs**  
   - Prefer small, incremental PRs with complete tests and migration notes.

4. **Idempotent & stateless ops**  
   - Design code changes so retries are safe. Avoid hidden state in scripts.

5. **Citations**  
   - Reference file paths and line ranges you used for decisions or code generation.

---

## 1) Repository Layout (current)

```
/                                          # repo root
├─ PestGenie/                              # SwiftUI iOS app sources (views, managers, SDUI engine)
├─ PestGenieTests/                         # XCTest unit tests
├─ PestGenieUITests/                       # UI test targets
├─ fastlane/                               # iOS automation
├─ scripts/                                # build/test helpers (bash)
├─ SDUIBackend/                            # Go Cloud Run backend skeleton
│  ├─ cmd/server/                          # main.go entry
│  └─ internal/                            # handlers, services, middleware, models
├─ SDUI_API_CONTRACT.md                    # iOS↔backend contract & personalization rules
├─ documentation *.md                      # architecture, security, guides
├─ .codex/AGENTS.md                        # this file (agent guidance)
└─ README.md                               # high-level overview
```

**Agents:** Run `ls` before assuming structure. Align new code or automation with the actual folders above.

---

## 2) Environments & Secrets

- **Envs:** `DEV`, `STAGING`, `PROD`  
- **Secrets:**  
  - **Local:** never commit secrets. Use `.env.sample` → `.env` (ignored).  
  - **Runtime:** **GCP Secret Manager**. The server reads secrets at startup (or via env injection).  
- **Common Vars (server):**
  - `PORT` (default 8080)
  - `DB_URL` (Cloud SQL Postgres or local Postgres)
  - `JWT_AUDIENCE`, `JWT_ISSUER`, `OAUTH_CLIENT_ID`
  - `GCP_PROJECT_ID`, `GCP_REGION`
  - `OTEL_EXPORTER_OTLP_ENDPOINT` (optional), `OTEL_RESOURCE_ATTRIBUTES`

**Agents:** Do not generate or hard-code secrets. Use placeholders like `YOUR_VALUE_HERE` and document expected source (Secret Manager or `.env`).

---

## 3) Build / Run / Test

### iOS (SwiftUI)

- **Preferred scripts**  
  ```bash
  ./scripts/build.sh --build      # debug build
  ./scripts/build.sh --test       # unit + UI tests bundle
  ```
- **Direct xcodebuild (fallback)**  
  ```bash
  xcodebuild \
    -project PestGenie.xcodeproj \
    -scheme PestGenie \
    -destination 'platform=iOS Simulator,name=iPhone 15'
  ```
- **Lint/Format**  
  SwiftLint is referenced across docs; run `swiftlint lint` once the tool is installed locally.

**Networking**  
- Use `URLSession` within `PestGenie/Core/Services` patterns.  
- Decode using `Codable`.  
- Tokens stay in Keychain via `SecurityManager`; do not use `UserDefaults` for secrets.  
- Base URLs should remain configurable (scripts/docs show how to swap environments).

### Go (SDUI backend)

- **Local run**
  ```bash
  cd SDUIBackend
  go run ./cmd/server
  ```
- **Unit tests**
  ```bash
  cd SDUIBackend
  go test ./...
  ```
- **Dependencies**  
  When fetching new modules, run `GOCACHE=$(pwd)/.cache go mod tidy` (network access may be required outside the sandbox).

**Agents:** The Go service is currently a skeleton. Flesh out data access/config before wiring the app to live endpoints.

---

## 4) GCP Deployment Model

- **Runtime:** Cloud Run (containerized Go API)
- **Data:** Cloud SQL (Postgres) or Firestore (confirm in code)
- **Secrets:** Secret Manager
- **Async:** Pub/Sub (events), Cloud Tasks (scheduled/async jobs)
- **Artifacts:** Container Registry (GAR)
- **Observability:** Cloud Logging + Cloud Monitoring; OpenTelemetry traces

**Deploy (example)**  
```bash
gcloud builds submit --tag gcr.io/$GCP_PROJECT_ID/server:$(git rev-parse --short HEAD)
gcloud run deploy api   --image gcr.io/$GCP_PROJECT_ID/server:$(git rev-parse --short HEAD)   --project $GCP_PROJECT_ID --region $GCP_REGION   --allow-unauthenticated   --set-secrets DB_URL=DB_URL:latest   --set-env-vars GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_REGION=$GCP_REGION
```

**Agents:** Always produce a deployment plan first; do not execute remote deploys unless explicitly asked.

---

## 5) API Contract & Personalisation

- **Source of truth:** `SDUI_API_CONTRACT.md` (root). It documents SDUI schemas, sync endpoints, and the personalization tokens exchanged between the SwiftUI client and the Go service. Keep it in sync with any feature work.
- **Personalisation:** The app expects route- and user-specific payloads. Query params such as `userId`, `routeId`, `serviceDate`, `deviceModel`, and `appVersion` should influence the JSON returned. The iOS client injects tokens like `user.name`, `route.alertSummary`, etc., which server templates should honour.

**Agents:** When adding new endpoints or tokens:
1. Update `SDUI_API_CONTRACT.md` with request/response examples and token rules.
2. Implement Go handlers/services under `SDUIBackend/internal/...` with unit tests.
3. Update Swift models/renderers in `PestGenie/SDUI*` and add corresponding tests in `PestGenieTests`.

---

## 6) Coding Conventions

### SwiftUI (iOS)
- **Architecture:** MVVM; smallest viable feature modules.  
- **State:** Prefer `@State`, `@StateObject`, `@EnvironmentObject` judiciously; avoid singletons.  
- **Styling:** Reusable components; accessibility first; dark mode aware.  
- **Networking:** API client injected (protocol-oriented); test with mocks.  
- **Errors:** Human-readable + underlying diagnostics for logs.

### Go (Cloud Run backend)
- **Layout:** `SDUIBackend/cmd/server` + `SDUIBackend/internal/...`. Keep handlers thin; move personalization/domain logic into dedicated services (e.g., `internal/sdui`).  
- **HTTP:** Uses **chi**. Follow context-aware patterns (`context.Context`), return JSON with explicit status codes.  
- **Persistence:** Not implemented yet—introduce a data layer (Firestore/Cloud SQL) under `internal` when requirements land.  
- **Config:** Read from env (PORT, GCP project, etc.); validate on startup.  
- **Errors:** Wrap with `%w`; return structured JSON (RFC 7807 style) once error helpers exist.  
- **Telemetry:** Plan for OpenTelemetry + structured logs; include correlation IDs (`middleware/Correlation`).

---

## 7) Testing Strategy

- **iOS:** XCTest for units; snapshot or UI tests where feasible.  
- **Go:** `go test ./...`, table-driven tests, `httptest` for handlers, mocks for external services.  
- **Contract tests:** Validate server responses against `SDUI_API_CONTRACT.md` examples (JSON schema / token expectations).  
- **Smoke tests:** `ops/` scripts to hit health checks and one real endpoint.

**Agents:** Always add/adjust tests with any change that alters behavior.

---

## 8) CI/CD (suggested)

- On PR: lint, build, run tests (iOS & Go), generate coverage, comment summary.  
- On merge to `main`: build container, deploy to **STAGING**, run smoke, then manual promotion to **PROD**.

**Agents:** Provide minimal workflow files when missing (GitHub Actions recommended).

---

## 9) Security & Privacy

- **iOS:** Tokens in Keychain; no PII in logs; use ATS; pin base URLs per env.  
- **Go:** Input validation; auth middleware; least-privilege IAM; CORS configured; rate limiting if public.  
- **GCP:** Service accounts per service; Secret Manager for secrets; VPC where appropriate.

**Agents:** Never include real keys/tokens. Use placeholders and document the source.

---

## 10) Observability

- **Tracing:** OpenTelemetry (HTTP server + DB + outbound HTTP).  
- **Logging:** Structured JSON; include request IDs and user/context IDs where appropriate.  
- **Metrics:** Basic process + HTTP metrics; surface key business KPIs.

---

## 11) Git Workflow

- **Branches:** `feature/<short-desc>`, `fix/<short-desc>`, `chore/<short-desc>`.  
- **Conventional Commits:** `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`.  
- **PR Template:** Include summary, screenshots (iOS), risks, test plan, rollout plan.

**Definition of Done**
- Code + tests + docs updated
- Local tests pass
- No broken lint
- For server changes: migration story is clear (forward/backward-compatible if needed)

---

## 12) Typical Agent Tasks (recipes)

### A) Deliver personalised SDUI screen
1. Update `SDUI_API_CONTRACT.md` with the new component/tokens.  
2. Extend `SDUIBackend/internal/sdui/service.go` (or supporting domain package) to hydrate the screen for the given `userId`/`routeId`.  
3. Update Swift renderers or JSON samples in `PestGenie/` as needed.  
4. Add Go tests (`go test ./...`) and Swift tests in `PestGenieTests`.

### B) Add/adjust SwiftUI feature
1. Locate the feature files under `PestGenie/` (or create a focused module).  
2. Wire view models to existing managers (`Core/Services`).  
3. If SDUI-driven, update the JSON descriptors (`PestGenie/*.json`) and contract file.  
4. Run `./scripts/build.sh --test` to ensure coverage.

### C) Extend sync endpoint
1. Document payload change in `SDUI_API_CONTRACT.md`.  
2. Modify handlers in `SDUIBackend/internal/sync/handler.go` and supporting models.  
3. Add Go unit tests (table driven) and run `go test ./...`.  
4. Update Swift data managers (e.g., `Core/Data`, `Core/Services`) plus tests.

---

## 13) Agent Do/Don’t

**Do**
- Ask for confirmation before schema changes or third-party additions.  
- Keep changes isolated per PR.  
- Provide fallback/rollback notes.

**Don’t**
- Don’t invent secrets or service accounts.  
- Don’t bypass tests to “make it work”.  
- Don’t change CI/CD deploy targets without instruction.

---

## 14) Quick Commands (cheat sheet)

```bash
# Go backend (SDUI)
cd SDUIBackend
go run ./cmd/server
go test ./...

# iOS build/test helpers
./scripts/build.sh --build
./scripts/build.sh --test

# SwiftLint (install separately)
swiftlint lint

# Docker (backend)
docker build -t sdui:dev -f SDUIBackend/Dockerfile SDUIBackend
docker run -p 8080:8080 sdui:dev
```

---

## 15) Open Questions for Humans
- Confirm long-term data store for technician routes (Cloud SQL vs Firestore) and ownership of route assignment feeds.  
- Confirm Go persistence + framework expectations (chi chosen; need direction on DB layer, migrations, config source).  
- Confirm CI provider/tooling (scripts + fastlane exist; need canonical pipeline).  
- Confirm observability targets (OTLP endpoint, sampling strategy, log schema).  
- Confirm rollout plan for SDUI personalization (how route communications are sourced, who curates tokens).

Agents should request clarification before proceeding if any of the above are ambiguous.

---

**End of AGENTS.md**

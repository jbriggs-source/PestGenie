# SDUI Screen & Sync API Contract

This document captures the data contracts that the PestGenie iOS client expects when consuming server‑driven UI (SDUI) configurations and when exchanging data with the synchronization APIs. All paths and structures are derived from the current codebase.

## 1. Screen Delivery Contract

### 1.1 Transport & Versioning
- SDUI screens are JSON payloads that deserialize into `SDUIScreen` with a required `version` integer and a root `component` (`PestGenie/SDUI.swift:5`).
- The client supports versions 1–5; higher versions fall back to a compatibility message via `SDUIVersionManager` (`PestGenie/SDUI+Utilities.swift:430`). Always include the lowest compatible version to avoid rendering failure.

### 1.2 Component Schema
Each node in the component tree conforms to `SDUIComponent` (`PestGenie/SDUI.swift:81`). Common fields:
- `id`: string identifier (auto-generated if missing, but servers should supply stable IDs).
- `children`: array of child components for container types.
- `itemView`: required template object for `list` types; rendered once for each `Job` in the route (`PestGenie/SDUIRenderer.swift:309`).
- `key`: binds display text to a property on the current `Job` (see §1.3).
- `text` / `label`: static strings or templates (allowing `{{variable}}` substitution).
- Styling tokens such as `padding`, `spacing`, `foregroundColor`, `backgroundColor`, `cornerRadius`, `font`, `fontWeight`, `borderWidth`, `shadowRadius`, `opacity`, `rotation`, and `scale` (`PestGenie/SDUI.swift:108` & `PestGenie/SDUI+Utilities.swift:180`).
- Interaction fields including `actionId`, `destination`, `isPresented`, `animation`, and `transition` (`PestGenie/SDUI.swift:160`, `PestGenie/SDUI.swift:700`).
- Input bindings use `valueKey` plus control-specific attributes like `placeholder`, `minValue`, `maxValue`, `step`, `options`, and `selectionMode` (`PestGenie/SDUI.swift:125`).

### 1.3 Data Binding
- `SDUIDataResolver` maps `key` values to the active job (`PestGenie/SDUI+Utilities.swift:11`). Supported keys include `customerName`, `address`, `scheduledDate`, `scheduledTime`, `status`, `notes`, `pinnedNotes`, and status booleans (`isActive`, `isCompleted`, etc.).
- Template strings like `"Welcome {{user.email}}"` resolve against `RouteViewModel.textFieldValues` (`PestGenie/SDUI+Utilities.swift:38`).
- For input components, the server must provide unique `valueKey` strings. The client composes these with the job UUID (or `global`) to persist field state (`PestGenie/SDUI+Utilities.swift:23`, `PestGenie/SDUI+ComponentRenderers.swift:214`).

### 1.4 Actions & Navigation
- `actionId` strings map to closures injected from the host view. The default mappings are `startJob`, `completeJob`, and `skipJob` (`PestGenie/SDUIContentView.swift:46`). Provide these identifiers in button components to trigger route workflows.
- `navigationLink` requires `destination`; currently it renders a placeholder text but establishes the contract for future screen transitions (`PestGenie/SDUIRenderer.swift:187`).
- Modal components (`alert`, `actionSheet`) must include `isPresented` keys that correspond to boolean bindings maintained by `RouteViewModel.presentationStates` (`PestGenie/SDUIRenderer.swift:205`).

### 1.5 Conditional Rendering & Lists
- `conditional` components hide children when the referenced job property is empty (`PestGenie/SDUIRenderer.swift:332`). Use this to surface optional content like pinned notes.
- `list` components iterate over the route array. The item template renders with `context.currentJob` set to each job, allowing `key` lookups and action targeting (e.g., JSON sample in `PestGenie/TechnicianScreen.json`).

### 1.6 Validation Rules
`SDUIErrorHandler.validateComponent` returns user-friendly errors when configuration is invalid (`PestGenie/SDUI+Utilities.swift:336`). Notable server responsibilities:
- Provide `children` for container types.
- Supply `itemView` for lists.
- Include `options` for pickers/segmented controls.
- Keep slider/stepper ranges valid (`minValue < maxValue`).
- Ensure images specify either `imageName` (SF Symbol/local asset) or `url`.
- Progress values must be 0.0–1.0.

### 1.7 Advanced Components
- Weather, chemical, and equipment component types route to specialized renderers (`PestGenie/SDUIRenderer.swift:274`, `PestGenie/SDUI+ComponentRenderers.swift:247`). When emitting these types, include domain-specific metadata documented in `WeatherSDUIComponents.swift` and related files.
- Animations use `{ "animation": { "type": "spring", "duration": 0.4 } }` and transitions `{ "transition": { "type": "slide" } }` (`PestGenie/SDUI.swift:700`, `PestGenie/SDUI+Utilities.swift:240`).

### 1.8 Personalization (User & Device Awareness)
- The client pre-seeds global template values via `RouteViewModel.setSDUIValue` so that payloads can tailor UI copy and visibility per authenticated technician (`PestGenie/RouteViewModel.swift:407`, `PestGenie/MainDashboardView.swift:3478`). Tokens currently set include:
  - `user.name`, `user.email`, `user.profileImageURL`
  - `todayJobsCompleted`, `weekJobsCompleted`, `activeStreak`
  - `lastSync`, `profileCompleteness`
- Template strings can reference these values with `{{user.name}}` substitutions inside any `text` field (`PestGenie/SDUI+Utilities.swift:38`).
- To create user-specific layouts, send dedicated screens or compose conditionals that cleanly map to role, certification, or territory values. The backend should populate additional tokens such as `user.role`, `user.region`, and per-route flags (e.g. `route.hasEmergencyJob`) so the JSON can adapt to each technician’s assigned day.
- Device metadata is surfaced the same way. The client will populate `device.model`, `device.osVersion`, `device.locale`, and `device.hasLiDAR` before rendering; your payload can drive responsive layout decisions using `conditional` blocks or by selecting screen variants per device class.
- Screen delivery services should accept `userId`, `routeId` (or service date), `deviceModel`, and `appVersion` query parameters so the backend can select the correct, user-specific screen variant. Cache personalized payloads per `(userId, serviceDate)` and invalidate when routes are reassigned or communications change.
- Personalized content (customer communications, compliance alerts) should also be delivered through SDUI components keyed to the assigned route. For example, include `notifications` arrays in the screen payload that render as list sections using the technician’s schedule.

## 2. Synchronization API Contract

### 2.1 Transport
- All sync requests target `https://api.pestgenie.com/v1` (`PestGenie/NetworkMonitor.swift:108`). Replace with the production base URL for your deployment.
- JSON payloads use ISO 8601 for dates (`APIService.uploadJob` encoder, `PestGenie/NetworkMonitor.swift:128`). Responses should follow the same convention.

### 2.2 Upload Endpoints
The client batches pending entities and posts them individually. Expected endpoints and payloads:

| Entity | Endpoint | Payload Schema |
| --- | --- | --- |
| Job | `POST /jobs` | `JobUploadData` (`PestGenie/SyncManager.swift:522`) – includes `id`, `customerName`, `address`, `scheduledDate`, `status` |
| Photo | `POST /jobs/{jobId}/photos` | JPEG multipart upload (`PestGenie/NetworkMonitor.swift:150`) |
| Chemical | `POST /chemicals` | `ChemicalUploadData` with inventory & compliance attributes (`PestGenie/SyncManager.swift:552`) |
| Chemical Treatment | `POST /chemical-treatments` | `ChemicalTreatmentUploadData` containing dosage, weather, and compliance fields (`PestGenie/SyncManager.swift:591`) |
| Device Token | `POST /devices/register` | `DeviceRegistration` with APNs token & bundle ID (`PestGenie/NetworkMonitor.swift:210`) |

Responses should mirror `UploadResponse` (`success`, `jobId`, optional `serverId`) or `PhotoUploadResponse` for photo uploads (`PestGenie/SyncManager.swift:566`). Non-2xx responses are treated as `APIError.serverError` and will be retried.

### 2.3 Download Endpoint
- `GET /updates?since=<ISO8601>` returns `ServerUpdates` (`PestGenie/NetworkMonitor.swift:171`, `PestGenie/SyncManager.swift:538`). The payload must include arrays for `jobs`, `routes`, `chemicals`, and `chemicalTreatments`. Each element mirrors the corresponding `*UpdateData` structure with server IDs and `lastModified` timestamps for conflict resolution.

### 2.4 Conflict Handling & Offline Queue
- Entities carry `syncStatus` and `lastModified` fields in Core Data (`PestGenie/PersistenceController.swift:4`, `PestGenie/SyncManager.swift:566`). Servers should honor optimistic concurrency via `lastModified` to prevent data loss.
- The route view model accumulates `pendingActions` when offline and replays them once `NetworkMonitor` reports connectivity (`PestGenie/RouteViewModel.swift:66`, `PestGenie/SDUIContentView.swift:36`). Exposed endpoints must be idempotent so that retries or duplicate submissions do not corrupt state.

### 2.5 Authentication Headers
- The app currently relies on Google Sign-In tokens stored in the keychain (`PestGenie/Core/Services/AuthenticationManager.swift:185`). Extend `APIService` to attach bearer tokens or session cookies consistent with your backend’s auth—today’s stub does not inject headers, so the backend should initially accept requests authenticated by network layer policies or mutual trust while token plumbing is added.

### 2.6 Error Semantics
- Timeouts and network unavailability map to `APIError` cases (`PestGenie/NetworkMonitor.swift:232`). Return actionable HTTP status codes with JSON bodies to help operators diagnose issues. The app logs failures and marks entities as `failed` for future retries.

## 3. Example Screen Payload

```json
{
  "version": 1,
  "component": {
    "type": "list",
    "itemView": {
      "type": "vstack",
      "children": [
        {
          "type": "hstack",
          "children": [
            {
              "type": "vstack",
              "children": [
                { "type": "text", "key": "customerName", "font": "headline" },
                { "type": "text", "key": "address", "font": "subheadline" },
                { "type": "text", "key": "scheduledTime", "font": "caption" }
              ]
            },
            { "type": "spacer" },
            { "type": "text", "key": "status", "font": "caption", "color": "statusColor" }
          ]
        },
        {
          "type": "conditional",
          "conditionKey": "pinnedNotes",
          "children": [
            { "type": "text", "key": "pinnedNotes", "font": "caption", "color": "red" }
          ]
        },
        {
          "type": "hstack",
          "children": [
            { "type": "button", "label": "Start", "actionId": "startJob" },
            { "type": "button", "label": "Complete", "actionId": "completeJob" },
            { "type": "button", "label": "Skip", "actionId": "skipJob" }
          ]
        }
      ]
    }
  }
}
```

This sample (bundled in `PestGenie/TechnicianScreen.json`) exercises list rendering, conditional content, and action mapping.

---
This contract provides the baseline for backend engineers implementing SDUI payload services and synchronization endpoints compatible with the existing iOS client.

## 4. Go + Cloud Run Service Guide

The following playbook outlines how to stand up a Go-based SDUI backend on Cloud Run that serves personalized screens and sync endpoints.

### 4.1 Prerequisites
- Google Cloud project with billing enabled.
- `gcloud` CLI ≥ 460.0, authenticated with `gcloud auth login` and target project set via `gcloud config set project <PROJECT_ID>`.
- Go 1.22 SDK for local development.

### 4.2 Project Skeleton
1. Create a new module:
   ```bash
   mkdir pestgenie-sdui && cd pestgenie-sdui
   go mod init github.com/your-org/pestgenie-sdui
   go get
   ```
2. Add a basic service layout:
   ```text
   cmd/
     server/main.go        # entry point
   internal/
     sdui/renderer.go      # screen selection logic
     sync/handlers.go      # upload/update handlers
     middleware/auth.go    # Google ID token verification
     models/models.go      # payload structs aligned with SDUI contract
   static/screens/*.json   # optional cached templates
   ```

### 4.3 Implement Handlers
- Define response structs that mirror the client contract (`SDUIScreen`, `ServerUpdates`, `JobUploadData`, etc.) so marshalled JSON matches exactly what the Swift app expects.
- Expose endpoints such as:
  - `GET /v1/screens/{screenId}` → returns personalized `SDUIScreen` based on `userId`, `deviceModel`, `appVersion` query params.
  - `GET /v1/updates` → implements the sync feed (`ServerUpdates`).
  - `POST /v1/jobs`, `POST /v1/chemicals`, `POST /v1/chemical-treatments`, `POST /v1/devices/register` → accept uploads from `APIService`.
- Add middleware that validates Google Sign-In ID tokens supplied as `Authorization: Bearer <token>` (use `google.golang.org/api/idtoken`). fallback to unauthenticated mode if you are still wiring auth.
- For personalized screens, create a resolver that loads a base template (from Firestore, Cloud Storage, or local JSON) and applies token replacements on the server (e.g. inject `user.role`, collapse sections flagged for unsupported devices).

### 4.4 Local Testing
1. Run the service locally with `go run ./cmd/server`.
2. Use `curl` or [HTTPie](https://httpie.io/) to verify endpoints respond with valid JSON.
3. Optionally, add contract tests that deserialize the JSON back into the Swift types using a shared schema or `quicktype`-generated tests.

### 4.5 Containerization
- Cloud Run accepts either Dockerfiles or buildpacks. Quickstart Dockerfile:
  ```Dockerfile
  FROM golang:1.22 AS builder
  WORKDIR /src
  COPY go.mod go.sum ./
  RUN go mod download
  COPY . .
  RUN CGO_ENABLED=0 GOOS=linux go build -o /srv/app ./cmd/server

  FROM gcr.io/distroless/base-debian12
  COPY --from=builder /srv/app /app
  ENV PORT=8080
  ENTRYPOINT ["/app"]
  ```
- Build and test locally: `docker build -t sdui-service .` then `docker run -p 8080:8080 sdui-service`.

### 4.6 Deploy to Cloud Run
1. Submit build & deploy:
   ```bash
   gcloud builds submit --tag gcr.io/$PROJECT_ID/pestgenie-sdui
   gcloud run deploy pestgenie-sdui \
     --image gcr.io/$PROJECT_ID/pestgenie-sdui \
     --platform managed \
     --region us-central1 \
     --allow-unauthenticated   # toggle off once auth is enforced
   ```
2. Capture the service URL output; this becomes the new `APIService.baseURL` in the iOS app.

### 4.7 Configure Environment & Secrets
- Use `gcloud run services update pestgenie-sdui --set-env-vars FIRESTORE_PROJECT=$PROJECT_ID` to inject configuration.
- Store secrets (API keys, weather integration tokens) in Secret Manager and mount them as environment variables with `--update-secrets`.
- Enable required Google APIs (Firestore, Cloud Logging, Cloud Trace) for observability.

### 4.8 Observability & Scaling
- Cloud Run provides automatic scaling. Configure min/max instances (`--min-instances`, `--max-instances`) based on expected screen request volume.
- Export metrics to Cloud Monitoring; add structured logging via `log/slog` in Go so you can trace per-user screen generation.

### 4.9 Wire Up the iOS Client
- Update `APIService` with the Cloud Run base URL and attach Google ID tokens from `AuthenticationManager` to each request.
- Add a new fetch path for SDUI screens (e.g. `GET /v1/screens/technician-home?userId=...`) and replace the local JSON loader in `SDUIContentView.loadScreen()` with a network fetch plus on-disk cache fallback.
- For device-specific requests, include headers such as `X-Device-Model`, `X-Device-OS`, and `X-App-Version`—`UIDevice` can provide the values.
- Implement exponential backoff (Cloud Run has request quotas) and respect HTTP 304 to leverage caching for unchanged layouts.

### 4.10 Continuous Delivery
- Automate builds with Cloud Build triggers tied to your Git repo (Dockerfile or Go source changes).
- Use Cloud Deploy or GitHub Actions to promote from staging → production Cloud Run services.
- Add integration tests that spin up a preview Cloud Run revision and run a subset of iOS UI tests against it using TestFlight or simulator pipelines.

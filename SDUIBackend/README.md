# SDUI Backend (Go + Docker)

This service emits server-driven UI (SDUI) payloads and synchronisation endpoints for the PestGenie iOS application. It is designed to run locally with Docker Desktop and deploy to Google Cloud Run without modification.

## Prerequisites

- Go 1.22+ (for local `go run` / testing)
- Docker Desktop (latest stable)
- Make sure `go.mod` / `go.sum` are up to date (`GOCACHE=$(pwd)/.cache go mod tidy`)

## Run locally with Docker

1. **Build the image**
   ```bash
   cd SDUIBackend
   docker build -t pestgenie-sdui:dev .
   ```
2. **Start a container**
   ```bash
 docker run --rm -p 8080:8080 pestgenie-sdui:dev
  ```
  Services are now available at `http://localhost:8080`.

3. **Test endpoints**
  ```bash
  curl http://localhost:8080/healthz
  curl 'http://localhost:8080/v1/screens/technician-home?userId=demo&routeId=route-001'
  ```

4. **Interactive docs**
   Open [http://localhost:8080/swagger](http://localhost:8080/swagger) in a browser to explore and test every endpoint via Swagger UI. The OpenAPI document is served from `/swagger/doc.json`.

Docker Desktop will display the container in its UI; stop it there or with `Ctrl+C` in the terminal.

## Deploy to Google Cloud Run

The same image can be built with Cloud Build and deployed to Cloud Run:
```bash
gcloud builds submit --tag gcr.io/$PROJECT_ID/pestgenie-sdui SDUIBackend
gcloud run deploy pestgenie-sdui \
  --image gcr.io/$PROJECT_ID/pestgenie-sdui \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated
```

Once deployed, point the iOS client to the Cloud Run URL (or proxy through Firebase Hosting).

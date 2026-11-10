# Ecological Data Integration
The repository will contain the code used to develop the platform

## Platform prototype

The initial Python modular monolith is in [`PLATFORM/`](PLATFORM/). See the
[installation and startup instructions](PLATFORM/README.md),
[architecture and requirement ownership](PLATFORM/docs/architecture/initial_skeleton.md),
and [verification record](PLATFORM/docs/development/verification.md).

From the repository root, start the local stack with:

```powershell
cd PLATFORM
Copy-Item .env.example .env
docker compose up --build -d
```

The API exposes `/health`, `/health/ready`, and `/docs`. Scientific workflows are
reserved for later increments. The existing repository licence remains in effect.

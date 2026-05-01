# Backend

This directory contains the **backend** code for Uni‑Dash Reborn.

## Documentation

The detailed documentation lives in the `docs/` sub‑directory:

- [General backend overview](docs/readme.md)
- [Setup instructions](docs/readme_for_backend_setup.md)

Feel free to open the files above for more information.

Start local dev stack
docker compose -p unidash-dev -f docker-compose.dev.yml up -d --build

Watch logs
docker compose -p unidash-dev -f docker-compose.dev.yml logs -f

Stop it
docker compose -p unidash-dev -f docker-compose.dev.yml down --remove-orphans

Stop and wipe volumes too (if you want clean local state)
docker compose -p unidash-dev -f docker-compose.dev.yml down --remove-orphans -v
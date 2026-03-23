# Alembic guide — backend

Small reference for common Alembic workflows used in this project.

Prerequisites
- Activate the project's virtualenv from the repository root (or `backend`):

```bash
source /home/edith/Documents/Uni-Dash_Reborn/.venv/bin/activate
cd backend
```

- Alembic configuration and DB URL are in `backend/alembic/env.py` and the `.env` loaded by it.

Inspect DB vs migration state
- Show the current revision recorded in the database:

```bash
alembic current
```

- List migration heads present in the source tree:

```bash
alembic heads
```

- Show full revision history (verbose):

```bash
alembic history --verbose
```

Autogenerate a migration
- Create an autogeneraged migration (ALWAYS review the generated file before applying):

```bash
alembic revision --autogenerate -m "Describe change"
# then inspect alembic/versions/<rev>_*.py and adjust as needed
```

- Apply the migration to the database:

```bash
alembic upgrade head
```

Handling multiple heads or conflicts
- If Alembic complains about "Multiple heads are present":
  - Option A — merge the heads into a single branch revision, then autogenerate on top:

```bash
alembic merge -m "merge heads" <head1> <head2>  # produces a merge revision
# Then create new revisions from that single head as needed
```

  - Option B — create a revision that explicitly uses a chosen head as parent (some Alembic versions accept `--head`):

```bash
alembic revision -m "changes based on chosen head" --head <chosen_head_rev>
```

  - Option C (use with caution) — stamp the DB to a revision to resolve mismatch without running migrations:

```bash
alembic stamp <revision>
# e.g. `alembic stamp head` marks DB as at latest migration without applying DDL
```

Notes and best practices
- Always inspect generated migration files in `alembic/versions/` before running `alembic upgrade`.
- Prefer creating small, focused migrations rather than huge auto-generated ones.
- If your Alembic version does not support `--empty` or `--head` flags, create a revision without autogenerate and edit the file manually.
- When adding new models/tables, remember to update any application code that depends on the schema and write tests where appropriate.

Quick troubleshooting
- "Target database is not up to date" on `alembic upgrade`: run `alembic heads` and `alembic current` to find mismatch; merge or stamp as appropriate.
- If migrations fail against production DB, DO NOT force upgrades — create a safe rollback migration or consult your DBA.

Example flow (common):

```bash
# 1) Activate venv and go to backend
source /home/edith/Documents/Uni-Dash_Reborn/.venv/bin/activate
cd backend

# 2) Autogenerate migration
alembic revision --autogenerate -m "Add broadcasts table and unidash_broadcast_id"

# 3) Review and edit the new file in alembic/versions/

# 4) Apply migration
alembic upgrade head
```

If you'd like, I can also generate a concrete migration file for the `Broadcast` table (or run the merge/stamp commands) — tell me which option you prefer.

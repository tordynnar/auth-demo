# FastAPI + nginx + Keycloak (oauth2-proxy) demo

A minimal stack showing a FastAPI app put behind nginx and protected by Keycloak.
Authentication and the group-membership rule are handled by **oauth2-proxy**; the
authenticated username is passed to FastAPI as an HTTP header, and FastAPI itself
contains no auth logic.

```
Browser ──> nginx ──auth_request──> oauth2-proxy <──OIDC──> Keycloak
   :80           │                       (group gate)        :8080
                 └──> FastAPI  (reads X-Forwarded-Preferred-Username header)
```

## Components

| Service       | Role                                                                 |
|---------------|----------------------------------------------------------------------|
| `nginx`       | Public entrypoint (`:80`). Delegates auth via `auth_request`.        |
| `oauth2-proxy`| Runs the OIDC login flow, enforces group membership, sets username header. |
| `app`         | FastAPI. `GET /` returns `{"username": ...}` from the header.       |
| `keycloak`    | Identity provider (`:8080`). Realm/users/groups imported on startup. |

## Run

```bash
docker compose up --build -d
# Keycloak takes ~30s to import the realm and become ready:
docker compose logs -f keycloak   # wait for "Running the server" / "started"
```

Then open <http://localhost/>.

## Sample users

| User  | Password | Group         | Result                         |
|-------|----------|---------------|--------------------------------|
| alice | password | `/app-users`  | Allowed — page shows her name  |
| bob   | password | `/other-group`| Denied (403) at oauth2-proxy   |

- Keycloak admin console: <http://localhost:8080> (user `admin`, password `admin`).
- The gated group is `/app-users` (set via `OAUTH2_PROXY_ALLOWED_GROUPS`).

## Try it

**Happy path** — open <http://localhost/> in a browser, log in as `alice` / `password`.
You'll be redirected back and see:

```json
{"username": "alice"}
```

**Denied path** — in a fresh/incognito window, log in as `bob` / `password`.
oauth2-proxy returns a 403 because `bob` is not in `/app-users`; the request never reaches FastAPI.

**Unauthenticated** — confirm the app is not publicly reachable:

```bash
curl -i http://localhost/        # 302 redirect to /oauth2/start (not a 200)
```

## How the username reaches the app

1. oauth2-proxy resolves the identity from the Keycloak token and (with
   `--set-xauthrequest`) exposes `X-Auth-Request-Preferred-Username` on the auth subrequest.
2. nginx captures it (`auth_request_set`) and forwards it as `X-Forwarded-Preferred-Username`.
3. FastAPI reads that header in `app/main.py`.

## Notes

This is a **demo, not production**:

- Everything is plain HTTP (`KC_HTTP_ENABLED=true`, `OAUTH2_PROXY_COOKIE_SECURE=false`,
  realm `sslRequired: none`). Put TLS in front for anything real.
- Secrets are inlined in `docker-compose.yml` and the realm export in cleartext for convenience.
- Keycloak runs in `start-dev` mode with an in-memory DB; data resets on `docker compose down`.

## Teardown

```bash
docker compose down
```

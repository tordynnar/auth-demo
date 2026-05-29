# FastAPI + nginx + Keycloak (oauth2-proxy) demo

A minimal stack showing a FastAPI app put behind nginx and protected by Keycloak.
Authentication and the group-membership rule are handled by **oauth2-proxy**; the
authenticated username is passed to FastAPI as an HTTP header, and FastAPI itself
contains no auth logic.

```
Browser ─TLS─> nginx ──auth_request──> oauth2-proxy <──OIDC──> Keycloak
  :443            │                       (group gate)     TLS :8443
                  └──> FastAPI  (reads X-Forwarded-Preferred-Username header)
```

Traffic to the browser is HTTPS (a self-signed cert terminated at both nginx and
Keycloak). The in-network backchannel between oauth2-proxy and Keycloak stays on
plain HTTP — it never leaves Docker's isolated network.

## Components

| Service       | Role                                                                 |
|---------------|----------------------------------------------------------------------|
| `nginx`       | Public entrypoint (`:443`, with `:80` → `:443` redirect). Terminates TLS, delegates auth via `auth_request`. |
| `oauth2-proxy`| Runs the OIDC login flow, enforces group membership, sets username header. |
| `app`         | FastAPI. `GET /` returns `{"username": ...}` from the header.       |
| `keycloak`    | Identity provider (HTTPS `:8443`). Realm/users/groups imported on startup. |

## Run

```bash
./generate-certs.sh          # one-time: creates a self-signed cert in ./certs
docker compose up --build -d
# Keycloak takes ~30s to import the realm and become ready:
docker compose logs -f keycloak   # wait for "started"
```

Then open <https://localhost/>. The cert is self-signed, so your browser will warn
("Your connection is not private") — click through (Advanced → Proceed) to continue.

## Sample users

| User  | Password | Group         | Result                         |
|-------|----------|---------------|--------------------------------|
| alice | password | `/app-users`  | Allowed — page shows her name  |
| bob   | password | `/other-group`| Denied (403) at oauth2-proxy   |

- Keycloak admin console: <https://localhost:8443> (user `admin`, password `admin`).
- The gated group is `/app-users` (set via `OAUTH2_PROXY_ALLOWED_GROUPS`).

## Try it

**Happy path** — open <https://localhost/> in a browser, log in as `alice` / `password`.
You'll be redirected back and see:

```json
{"username": "alice"}
```

**Denied path** — in a fresh/incognito window, log in as `bob` / `password`.
oauth2-proxy returns a 403 because `bob` is not in `/app-users`; the request never reaches FastAPI.

**From the command line** (`-k` accepts the self-signed cert):

```bash
curl -kI http://localhost/       # 301 redirect to https://localhost/
curl -k  https://localhost/      # 302 to the Keycloak login (not publicly reachable)
```

## How the username reaches the app

1. oauth2-proxy resolves the identity from the Keycloak token and (with
   `--set-xauthrequest`) exposes `X-Auth-Request-Preferred-Username` on the auth subrequest.
2. nginx captures it (`auth_request_set`) and forwards it as `X-Forwarded-Preferred-Username`.
3. FastAPI reads that header in `app/main.py`.

## Notes

This is a **demo, not production**:

- TLS uses a **self-signed** cert, so browsers and clients must be told to trust it
  (click through the warning, or `curl -k`). For real use, issue a cert from a trusted
  CA (e.g. Let's Encrypt) and serve on a real hostname.
- The realm keeps `sslRequired: none` so the in-network HTTP backchannel works; a real
  deployment would tighten this and run the backchannel over TLS too.
- Secrets (client secret, cookie secret) are inlined in `docker-compose.yml` and the
  realm export in cleartext for convenience.
- Keycloak runs in `start-dev` mode with an in-memory DB; data resets on `docker compose down`.

## Teardown

```bash
docker compose down
```

from fastapi import FastAPI, Request

app = FastAPI(title="Username Demo")


@app.get("/")
def whoami(request: Request):
    # The username is injected by nginx (sourced from oauth2-proxy/Keycloak).
    # This app holds no auth logic of its own — it trusts the upstream header.
    username = (
        request.headers.get("x-forwarded-preferred-username")
        or request.headers.get("x-forwarded-user")
        or "unknown"
    )
    return {"username": username}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}

# Local STOOGE authentication

The browser uses the address you opened for Keycloak. Each address must appear
in both Keycloak's client redirect/origin settings and the APIs' `JWTAUTHORITY`
issuer allowlist. Otherwise login can succeed but API requests return 401.
The APIs fetch signing keys through Docker's internal Keycloak address, so
validation does not depend on the host's changing LAN address.

With the initialized stack running, enable localhost and loopback access:

```powershell
./set-local-auth.ps1
docker compose up -d
```

To add a LAN address too, provide all desired origins:

```powershell
./set-local-auth.ps1 -Origins http://localhost:8080,http://127.0.0.1:8080,http://172.32.252.85:8080
docker compose up -d
```

The script preserves existing addresses and data. Re-running it is safe.
It does not reset the realm, users, or credentials. Use PowerShell 7.3 or newer
so JSON arguments are passed intact to Docker. A plain `docker compose restart`
does not reload environment changes; use `up -d`.

Keycloak starts with its prebuilt configuration (`--optimized`). The web
container waits for Keycloak's readiness health check on initial deployment,
avoiding login requests during bootstrap. Readiness cannot prevent transient
errors during a later manual restart of Keycloak; refresh after it is healthy.
The authentication proxy also refreshes Keycloak's address through Docker DNS,
so replacing that container does not leave it pointing to an old container IP.

Verify both localhost and the LAN address: the discovery endpoint at
`/auth/realms/openrmf/.well-known/openid-configuration` should report an issuer
matching the address used, login should load, and a signed-in request to
`/api/read/artifact/systems` should succeed. API `/healthz` alone does not test
token validation.

Run `./test-local-auth.ps1` to check both loopback names, or pass the same
`-Origins` list as above to include LAN access. It checks the actual login form,
five authenticated APIs, all 17 health routes, and rejection of unauthenticated
requests. Set `STOOGE_VERIFY_USERNAME` and `STOOGE_VERIFY_PASSWORD`, or use the
initial administrator credentials already saved in `.env`.

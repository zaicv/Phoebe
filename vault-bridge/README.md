# Vault Bridge

Tiny authenticated HTTP bridge for serving video files from a local/external drive over Tailscale.

## Security Defaults
- `Authorization: Bearer <token>` is required on every request.
- Only `GET` is allowed (`POST/PUT/PATCH/DELETE` return `405`).
- Bridge refuses to start if the configured root is writable by the current process.
- Symlink escapes outside the configured root are skipped.

## Generate Token

```bash
openssl rand -hex 32
```

Use that value as `--token`, then paste the same value into Phoebe Settings -> Vault Bridge -> API token.

## Run (Recommended)

```bash
python3 server.py --root "/Volumes/MyDrive/Videos" --token "<your-random-token>" --host "100.x.y.z" --port 8787
```

Use your machine's Tailscale IP for `--host` so the bridge is only reachable via Tailscale.

If you intentionally want to run against a writable root (not recommended), add:

```bash
--allow-writable-root
```

## API

- `GET /health`
- `GET /library?path=<relativePath>`
- `GET /search?q=<term>&path=<relativePath>`
- `GET /video/<id>/meta`
- `GET /video/<id>/stream` (Range supported)
- `GET /video/<id>/download`

All endpoints require:

```http
Authorization: Bearer <token>
```

## Tests

```bash
python3 -m unittest test_server.py
```

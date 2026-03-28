# Vault Bridge

Tiny authenticated HTTP bridge for serving video files from a local/external drive over Tailscale.

## Run

```bash
python3 server.py --root "/Volumes/MyDrive/Videos" --token "change-me" --host "100.x.y.z" --port 8787
```

Use your machine's Tailscale IP for `--host` so the bridge is only reachable via Tailscale.

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

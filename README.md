# VLESS + XHTTP

## Overview

Bash scripts for Xray `vless` + `xhttp` setups:

- `vless_xhttp_nginx.sh` deploys Xray behind Nginx with TLS.
- `vless_xhttp_reality.sh` deploys Xray with Reality.
- `vless_xhttp_uuid.sh` adds new client UUIDs and prints links and QR codes for existing ones.

Script behavior:

- Scripts are configured through environment variables.
- `-h` or `--help` prints supported overrides.
- Installer scripts generate `UUID` automatically if it is not provided.
- `vless_xhttp_uuid.sh` auto-generates a UUID only for `add`.

## Quick start

### Nginx + TLS

```bash
DOMAIN=example.com EMAIL=admin@example.com ./vless_xhttp_nginx.sh
```

Optional example with explicit UUID:

```bash
UUID=11111111-1111-1111-1111-111111111111 \
DOMAIN=example.com \
EMAIL=admin@example.com \
./vless_xhttp_nginx.sh
```

### Reality

```bash
DOMAIN=example.com SNI=vk6-9.vkuser.net ./vless_xhttp_reality.sh
```

Optional example with explicit UUID:

```bash
UUID=11111111-1111-1111-1111-111111111111 \
DOMAIN=example.com \
SNI=vk6-9.vkuser.net \
./vless_xhttp_reality.sh
```

### UUID helper

Generate and add a new client UUID:

```bash
./vless_xhttp_uuid.sh add
```

Add a specific UUID:

```bash
./vless_xhttp_uuid.sh add 11111111-1111-1111-1111-111111111111
```

Print the link and QR code for an existing UUID:

```bash
./vless_xhttp_uuid.sh show 11111111-1111-1111-1111-111111111111
```

If the public hostname cannot be inferred from Nginx config, pass `DOMAIN` explicitly:

```bash
DOMAIN=example.com ./vless_xhttp_uuid.sh show 11111111-1111-1111-1111-111111111111
```

## Configuration

All scripts use environment variables instead of CLI flags. Common overrides include:

- `UUID`: client UUID
- `DOMAIN`: public hostname
- `XHTTP_PATH`: XHTTP path
- `XHTTP_MODE`: XHTTP mode
- `CLIENT_FINGERPRINT`: fingerprint in the generated `vless://` URL
- `PROFILE_NAME`: label prefix after `#`
- `QR_TYPE`: `qrencode` output type

To see the full override list for each script:

```bash
./vless_xhttp_nginx.sh --help
./vless_xhttp_reality.sh --help
./vless_xhttp_uuid.sh --help
```

## Notes

- Run the scripts directly on the target server.
- They use standard Xray and Nginx paths unless overridden through environment variables.
- `vless_xhttp_uuid.sh` modifies the live Xray config and restarts the configured Xray service on `add`.

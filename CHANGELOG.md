# Changelog

## 0.20.0-railway.1 (2026-11-24)

- First release of the Railway template: RustiCal v0.20.0 (`ghcr.io/lennart-k/rustical:0.20.0@sha256:37384724395ef84f0a44791aa5c2dafdd140bf8df0dc34b8864a206df6c67354`).
- Admin user created on first boot from `ADMIN_USERNAME` / generated `ADMIN_PASSWORD`, before the port opens.
- README: Deploy on Railway button (template code `rustical`).
- SQLite database on the `/var/lib/rustical` volume; health check `/ping`; non-zero exit on unexpected stops.

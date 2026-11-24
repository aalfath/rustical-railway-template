[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/rustical?utm_medium=integration&utm_source=button&utm_campaign=rustical)

# RustiCal on Railway

Railway template for [RustiCal](https://github.com/lennart-k/rustical) **v0.20.0**, a small CalDAV and CardDAV server for calendars, tasks and contacts, with a web UI and per-device app tokens.

## What it deploys

One service, built from this repo's `Dockerfile`:

- `FROM ghcr.io/lennart-k/rustical:0.20.0@sha256:37384724395ef84f0a44791aa5c2dafdd140bf8df0dc34b8864a206df6c67354` (official image, pinned by version and digest)
- a static BusyBox (the upstream image has no shell) and `app/start.sh`, which
  - listens on Railway's `PORT` and sizes the thread pool to the service's CPU limit,
  - creates the admin user from `ADMIN_USERNAME` / `ADMIN_PASSWORD` **before** the web server starts (and re-applies the password on every boot, so changing the variable changes the password),
  - exits non-zero if RustiCal stops unexpectedly, so Railway restarts it.
- a volume at `/var/lib/rustical` holding the SQLite database (`db.sqlite3`): calendars, contacts, users and app tokens.
- health check: `GET /ping`.

It runs comfortably on Railway's Free plan (0.5 GB RAM): idle memory is a few MB.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ADMIN_USERNAME` | `admin` | Login name of the first user. No `:`, `$` or spaces. |
| `ADMIN_PASSWORD` | `${{secret(32)}}` | Generated. Used for the web UI only; it is re-applied on every boot. |
| `PORT` | `4000` | Port RustiCal listens on. |

Other settings use RustiCal's own environment variables (`RUSTICAL_<SECTION>__<KEY>`, see the [configuration docs](https://lennart-k.github.io/rustical/installation/configuration/)), for example OpenID Connect (`RUSTICAL_OIDC__…`).

## After deploying

1. Open the public URL and sign in with `ADMIN_USERNAME` and `ADMIN_PASSWORD` (Variables tab).
2. Create a calendar or address book, then create an **app token** for each phone or desktop client. Clients log in with the user name and the app token, not the password.
3. Client URLs: `https://YOUR-DOMAIN/caldav`, `https://YOUR-DOMAIN/carddav` (Apple Calendar and Home Assistant: `/caldav-compat`). DAVx5 can use the Nextcloud login flow; Apple devices can download a configuration profile from the app-token page.

More users: open the service's shell (`railway ssh`) and run `rustical principals create <name> --password`.

## Updates

Version bumps land on this repo's `main` branch. Railway then shows an "update available" notice on projects deployed from the template, and you choose when to apply it. Read `CHANGELOG.md` first: breaking changes are listed at the top of each entry. Back up the volume (or use the web UI's export) before applying an update.

## Licence

RustiCal is AGPL-3.0 (© Lennart Kämmle). The files in this repo are wrapper code for deploying it.

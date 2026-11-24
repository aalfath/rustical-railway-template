# RustiCal for Railway: the official image, pinned by version and digest,
# plus a static BusyBox (the upstream image is FROM scratch and has no shell)
# and a small start script.
FROM busybox:1.37.0-musl@sha256:f6a95d611e0a8780fabdb2aec43e31275b2720dfefa3e41b16835bfc42454478 AS busybox

FROM ghcr.io/lennart-k/rustical:0.20.0@sha256:37384724395ef84f0a44791aa5c2dafdd140bf8df0dc34b8864a206df6c67354

COPY --from=busybox /bin/busybox /bin/busybox
RUN ["/bin/busybox", "--install", "-s", "/bin"]
COPY app/start.sh /usr/local/bin/start.sh
RUN chmod 755 /usr/local/bin/start.sh && mkdir -p /var/lib/rustical /tmp && chmod 1777 /tmp

ENV RUSTICAL_DATA_STORE__SQLITE__DB_URL=/var/lib/rustical/db.sqlite3
EXPOSE 4000

ENTRYPOINT ["/usr/local/bin/start.sh"]

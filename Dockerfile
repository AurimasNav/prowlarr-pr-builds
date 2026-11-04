# The linuxserver.io Prowlarr image the cluster already runs, with Prowlarr itself swapped for
# the pull-request build (same paths, same s6 service, same /config layout).
FROM ghcr.io/linuxserver/prowlarr:3.0.0-develop@sha256:e2382127fec5c61ca6b6eb528fd4dcf8a8255ef2957ca334d782dbaf46d4c0c7

RUN rm -rf /app/prowlarr/bin && mkdir -p /app/prowlarr/bin
COPY Prowlarr/ /app/prowlarr/bin/
# Updates come from new images, as in the base image.
RUN rm -rf /app/prowlarr/bin/Prowlarr.Update

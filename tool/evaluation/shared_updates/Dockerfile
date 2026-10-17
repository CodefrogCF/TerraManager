# Evaluation image only; the production Dockerfile does not copy these tools.
FROM dart:3.13.4 AS build
WORKDIR /src
COPY deploy/server/pubspec.yaml deploy/server/pubspec.lock ./
RUN dart pub get --enforce-lockfile
COPY lib/ lib/
COPY tool/evaluation/shared_updates/ tool/evaluation/shared_updates/
RUN dart build cli --target=tool/evaluation/shared_updates/lab_server.dart --output=/out/lab

# The evaluation runtime intentionally retains coreutils for scratch permissions.
# Use process/container measurements, not this image's disk size, for comparisons.
FROM dart:3.13.4
WORKDIR /srv
COPY --from=build /out/lab/bundle/ /opt/lab/
COPY tool/evaluation/shared_updates/web/ /srv/web/
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/opt/lab/bin/lab_server"]


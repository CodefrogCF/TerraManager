# syntax=docker/dockerfile:1
FROM --platform=linux/arm64 dart:3.13.4 AS build
WORKDIR /src

# Keep the server's dependency graph independent of the Flutter SDK.
COPY deploy/server/pubspec.yaml deploy/server/pubspec.lock ./
RUN dart pub get --enforce-lockfile
COPY bin/create_admin.dart bin/shared_server.dart bin/
COPY lib/core/database/ lib/core/database/
COPY lib/core/qr/qr_id_generator.dart lib/core/qr/qr_id_generator.dart
COPY lib/core/qr/qr_validator.dart lib/core/qr/qr_validator.dart
COPY lib/features/backup/ lib/features/backup/
COPY lib/features/feedings/application/feeding_reminder_service.dart lib/features/feedings/application/feeding_reminder_service.dart
COPY lib/features/feedings/domain/feeding_reminder_state.dart lib/features/feedings/domain/feeding_reminder_state.dart
COPY lib/shared_server/ lib/shared_server/
RUN dart build cli --target=bin/shared_server.dart --output=/out/server \
    && dart build cli --target=bin/create_admin.dart --output=/out/admin

FROM --platform=linux/arm64 dart:3.13.4
COPY --from=build /out/server/bundle/ /opt/server/
COPY --from=build /out/admin/bundle/ /opt/admin/
COPY deploy/healthcheck.dart /opt/healthcheck.dart
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/opt/server/bin/shared_server"]

# syntax=docker/dockerfile:1

FROM dart:3.13.4 AS build
WORKDIR /src

# Keep the server's dependency graph independent of the Flutter SDK.
COPY deploy/server/pubspec.yaml deploy/server/pubspec.lock ./
RUN dart pub get --enforce-lockfile

COPY bin/create_admin.dart bin/shared_server.dart bin/cleanup_media.dart bin/
COPY deploy/healthcheck.dart deploy/healthcheck.dart

COPY lib/core/database/ lib/core/database/
COPY lib/core/qr/qr_id_generator.dart lib/core/qr/qr_id_generator.dart
COPY lib/core/qr/qr_validator.dart lib/core/qr/qr_validator.dart
COPY lib/features/backup/ lib/features/backup/
COPY lib/features/feedings/application/feeding_reminder_service.dart lib/features/feedings/application/feeding_reminder_service.dart
COPY lib/features/feedings/domain/ lib/features/feedings/domain/
COPY lib/shared_server/ lib/shared_server/

RUN dart build cli --target=bin/shared_server.dart --output=/out/server \
    && dart build cli --target=bin/create_admin.dart --output=/out/admin \
    && dart build cli --target=bin/cleanup_media.dart --output=/out/media \
    && dart build cli --target=deploy/healthcheck.dart --output=/out/healthcheck

# Minimal production image.
#
# The Dart image is only used above as a compiler. The released container
# contains the AOT binaries and the small set of runtime libraries provided
# by the official Dart image.
FROM scratch

COPY --from=build /runtime/ /

COPY --from=build /out/server/bundle/ /opt/server/
COPY --from=build /out/admin/bundle/ /opt/admin/
COPY --from=build /out/media/bundle/ /opt/media/
COPY --from=build /out/healthcheck/bundle/ /opt/healthcheck/

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["/opt/server/bin/shared_server"]
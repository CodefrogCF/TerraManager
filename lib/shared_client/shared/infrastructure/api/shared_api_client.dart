import 'package:terramanager/shared_client/changes/application/shared_refresh_controller.dart';
import 'package:terramanager/shared_client/changes/application/shared_change_stream.dart';
import 'package:terramanager/shared_client/changes/application/shared_sync_controller.dart';
import 'package:terramanager/shared_client/changes/domain/shared_event_source_port.dart';
import 'package:terramanager/shared_client/changes/infrastructure/shared_event_source_stub.dart'
    if (dart.library.js_interop) 'package:terramanager/shared_client/changes/infrastructure/shared_event_source_web.dart';
import 'package:terramanager/shared_client/administration/accounts/infrastructure/api/shared_accounts_api.dart';
import 'package:terramanager/shared_client/administration/audit/infrastructure/api/shared_audit_api.dart';
import 'package:terramanager/shared_client/animals/infrastructure/api/shared_animals_api.dart';
import 'package:terramanager/shared_client/authentication/infrastructure/api/shared_authentication_api.dart';
import 'package:terramanager/shared_client/backups/infrastructure/api/shared_backups_api.dart';
import 'package:terramanager/shared_client/changes/infrastructure/api/shared_changes_api.dart';
import 'package:terramanager/shared_client/boxes/infrastructure/api/shared_boxes_api.dart';
import 'package:terramanager/shared_client/care_history/infrastructure/api/shared_care_history_api.dart';
import 'package:terramanager/shared_client/feedings/infrastructure/api/shared_feedings_api.dart';
import 'package:terramanager/shared_client/media/infrastructure/api/shared_media_api.dart';
import 'package:terramanager/shared_client/settings/infrastructure/api/shared_settings_api.dart';
import 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_transport.dart';

export 'package:terramanager/shared_client/authentication/domain/shared_session.dart';
export 'package:terramanager/shared_client/backups/domain/shared_backup_file.dart';
export 'package:terramanager/shared_client/changes/infrastructure/api/shared_changes_api.dart'
    show SharedChangeQuery;
export 'package:terramanager/shared_client/shared/infrastructure/api/shared_api_exception.dart';

/// Composes feature API operations over one authenticated, transient transport.
class SharedApiClient extends SharedApiTransport
    with
        SharedAuthenticationApi,
        SharedChangesApi,
        SharedSettingsApi,
        SharedAccountsApi,
        SharedAuditApi,
        SharedBoxesApi,
        SharedAnimalsApi,
        SharedFeedingsApi,
        SharedCareHistoryApi,
        SharedMediaApi,
        SharedBackupsApi {
  SharedApiClient(
    super.origin,
    super.client, {
    this.eventSource,
    this.syncNow,
    this.syncRandom,
  });
  final DateTime Function()? syncNow;
  final double Function()? syncRandom;
  final SharedEventSourcePort? eventSource;
  late final changeStream = SharedChangeStream(
    origin.resolve('/api/v1/changes/events'),
    eventSource ?? createSharedEventSource(),
  );

  /// A terminal authenticated stream event expires this tab's transient session.
  void expireStreamSession() {
    changeStream.stop(clearReceived: true);
    sessionState = null;
    notifyListeners();
  }

  late final refresh = SharedRefreshController(
    queryChanges: queryChanges,
    now: syncNow,
  );
  late final synchronization = SharedSyncController(
    refresh: refresh,
    stream: changeStream,
    onAuthenticationRequired: expireStreamSession,
    now: syncNow,
    random: syncRandom,
  );

  @override
  Future<SharedChangeQuery> queryChanges({String? since}) async {
    final owner = session;
    final response = await super.queryChanges(since: since);
    // Cookies are shared across tabs. A different audience can mean another
    // tab changed the signed-in account. Never decode an opaque cursor.
    if (response.body?['reason'] == 'foreign_cursor' &&
        identical(owner, session)) {
      await restoreSession();
    }
    return response;
  }

  /// Media IDs are immutable within an epoch; restore may reuse those IDs.
  /// A tab-local number invalidates image provider keys without exposing cursors.
  @override
  Uri mediaUrl(int mediaId) {
    final url = super.mediaUrl(mediaId);
    final generation = refresh.mediaGeneration;
    return generation == 0
        ? url
        : url.replace(queryParameters: {'tm_epoch': '$generation'});
  }

  @override
  void close() {
    synchronization.dispose();
    changeStream.dispose();
    refresh.dispose();
    super.close();
  }
}

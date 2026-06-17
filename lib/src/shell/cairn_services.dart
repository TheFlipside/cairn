import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_package_repository.dart';
import 'package:cairn/src/health/health_repository.dart';
import 'package:cairn/src/profile/profile.dart';
import 'package:cairn/src/profile/profile_store.dart';
import 'package:cairn/src/query/health_query_service.dart';
import 'package:cairn/src/storage/health_ingest_service.dart';
import 'package:cairn/src/storage/jsonl_omh_file_store.dart';
import 'package:cairn/src/sync/flutter_secure_token_store.dart';
import 'package:cairn/src/sync/http_nextcloud_auth.dart';
import 'package:cairn/src/sync/nextcloud_sync_coordinator.dart';
import 'package:cairn/src/sync/nextcloud_sync_target.dart';
import 'package:cairn/src/sync/sync_journal.dart';
import 'package:cairn/src/sync/webdav_nextcloud_sync_target.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The app's shared, app-lifetime services, built once and owned by the shell.
///
/// Holds the single [http.Client] used by auth + WebDAV (closed in [dispose]),
/// the local cache, the profile store, the read-path query service, the sync
/// coordinator, and the health-store reader.
final class CairnServices {
  /// Creates a services holder. Prefer [create].
  CairnServices({
    required this.client,
    required this.store,
    required this.profileStore,
    required this.profile,
    required this.query,
    required this.coordinator,
    required this.repository,
  });

  /// Resolves the on-device stores and wires the services together.
  static Future<CairnServices> create() async {
    final client = http.Client();
    final store = await JsonlOmhFileStore.appDocuments();
    final journalStore = await JsonSyncJournalStore.appSupport();
    final profileStore = JsonProfileStore(root: store.root);
    return CairnServices(
      client: client,
      store: store,
      profileStore: profileStore,
      profile: ValueNotifier(await profileStore.read()),
      query: OmhHealthQueryService(store: store),
      coordinator: NextcloudSyncCoordinator(
        auth: HttpNextcloudAuth(client: client),
        tokenStore: FlutterSecureTokenStore(),
        localRoot: store.root,
        journalStore: journalStore,
        targetFactory: (credentials) => WebDavNextcloudSyncTarget(
          credentials: credentials,
          client: client,
        ),
      ),
      repository: HealthPackageRepository(),
    );
  }

  /// One HTTP client shared by auth + WebDAV.
  final http.Client client;

  /// The local OMH cache.
  final JsonlOmhFileStore store;

  /// The synced user-profile store.
  final JsonProfileStore profileStore;

  /// The current user profile, app-wide reactive source of truth. Settings
  /// updates it on save so the Home BMI card recomputes without a refresh.
  final ValueNotifier<Profile> profile;

  /// The read-path query service over [store].
  final HealthQueryService query;

  /// The Nextcloud connect + sync coordinator.
  final NextcloudSyncCoordinator coordinator;

  /// The OS health-store reader (for manual refresh/ingest).
  final HealthRepository repository;

  /// Bumped after every ingest so all data screens reload immediately when new
  /// readings land in the cache (the read-path analogue of [profile]).
  final ValueNotifier<int> dataRevision = ValueNotifier(0);

  Future<String?>? _refreshInFlight;

  /// Reads new data from the OS health store into the cache, bumps
  /// [dataRevision] so screens reload, then pushes to Nextcloud if connected.
  /// Returns a user-facing error message, or `null` on success.
  ///
  /// Concurrent calls (e.g. the Home button and a Sleep pull-to-refresh) are
  /// coalesced into a single run, so ingest/sync never overlap.
  Future<String?> refresh() {
    return _refreshInFlight ??= _runRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<String?> _runRefresh() async {
    try {
      final granted = await repository.requestAuthorization(
        HealthMetric.values.toSet(),
      );
      await HealthIngestService(
        repository: repository,
        store: store,
      ).ingest(granted);
    } on Exception catch (error) {
      return 'Could not read health data: $error';
    }
    // New local data is on disk → refresh the screens even if the upload fails.
    dataRevision.value++;
    try {
      if (await coordinator.isConnected()) await coordinator.syncNow();
    } on NextcloudSyncException catch (error) {
      return 'Saved locally; sync failed: ${error.message}';
    } on Exception catch (error) {
      return 'Saved locally; sync failed: $error';
    }
    return null;
  }

  /// Releases the shared HTTP client and the notifiers.
  void dispose() {
    profile.dispose();
    dataRevision.dispose();
    client.close();
  }
}

import 'package:cairn/src/health/health_package_repository.dart';
import 'package:cairn/src/health/health_repository.dart';
import 'package:cairn/src/profile/profile.dart';
import 'package:cairn/src/profile/profile_store.dart';
import 'package:cairn/src/query/health_query_service.dart';
import 'package:cairn/src/storage/jsonl_omh_file_store.dart';
import 'package:cairn/src/sync/flutter_secure_token_store.dart';
import 'package:cairn/src/sync/http_nextcloud_auth.dart';
import 'package:cairn/src/sync/nextcloud_sync_coordinator.dart';
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

  /// Releases the shared HTTP client and the profile notifier.
  void dispose() {
    profile.dispose();
    client.close();
  }
}

import 'dart:async';

import 'package:cairn/src/dashboard/connect_nextcloud_page.dart';
import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_package_repository.dart';
import 'package:cairn/src/storage/health_ingest_service.dart';
import 'package:cairn/src/storage/jsonl_omh_file_store.dart';
import 'package:cairn/src/sync/flutter_secure_token_store.dart';
import 'package:cairn/src/sync/http_nextcloud_auth.dart';
import 'package:cairn/src/sync/nextcloud_sync_coordinator.dart';
import 'package:cairn/src/sync/nextcloud_sync_target.dart';
import 'package:cairn/src/sync/sync_journal.dart';
import 'package:cairn/src/sync/webdav_nextcloud_sync_target.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// The app's home screen.
///
/// In v1 this reads the local Open mHealth cache and renders the in-app
/// dashboard (DESIGN.md §9, read/display path A). For now it is a placeholder
/// that — in debug builds only — exposes a manual harness for the Phase
/// 1/2/3 on-device exit checks: read & persist health, then sync to Nextcloud
/// (DESIGN.md §15). It is not product UI.
class DashboardPage extends StatefulWidget {
  /// Creates the dashboard page.
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _status = '';
  bool _running = false;
  String _connection = 'Nextcloud: checking…';
  String _syncStatus = '';
  bool _syncing = false;

  /// One HTTP client shared by auth + WebDAV for this screen's lifetime,
  /// closed in [dispose] so sockets aren't leaked across syncs.
  final http.Client _httpClient = http.Client();
  Future<NextcloudSyncCoordinator>? _coordinatorFuture;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      unawaited(_refreshConnection());
    }
  }

  @override
  void dispose() {
    _httpClient.close();
    super.dispose();
  }

  /// Builds the coordinator once and caches it. Auth and the WebDAV target
  /// share [_httpClient]. Debug harness only; product wiring lands in Phase 4.
  Future<NextcloudSyncCoordinator> _coordinator() async {
    return _coordinatorFuture ??= () async {
      final store = await JsonlOmhFileStore.appDocuments();
      final journalStore = await JsonSyncJournalStore.appSupport();
      return NextcloudSyncCoordinator(
        auth: HttpNextcloudAuth(client: _httpClient),
        tokenStore: FlutterSecureTokenStore(),
        localRoot: store.root,
        journalStore: journalStore,
        targetFactory: (credentials) => WebDavNextcloudSyncTarget(
          credentials: credentials,
          client: _httpClient,
        ),
      );
    }();
  }

  Future<void> _refreshConnection() async {
    final coordinator = await _coordinator();
    final credentials = await coordinator.currentCredentials();
    if (!mounted) return;
    setState(() {
      _connection = credentials == null
          ? 'Nextcloud: not connected'
          : 'Nextcloud: ${credentials.loginName}@${credentials.server.host}';
    });
  }

  Future<void> _readAndPersist() async {
    // Debug-only: never read, persist, or log health data in release builds.
    assert(kDebugMode, 'read-health harness is debug-only');
    if (!kDebugMode) return;
    setState(() {
      _running = true;
      _status = 'Authorising…';
    });

    final lines = <String>[];
    try {
      final repository = HealthPackageRepository();
      final granted = await repository.requestAuthorization(
        HealthMetric.values.toSet(),
      );
      final store = await JsonlOmhFileStore.appDocuments();
      final ingest = HealthIngestService(repository: repository, store: store);
      final results = await ingest.ingest(granted);

      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 31));
      for (final result in results) {
        final onDisk = await store.readRange(
          metric: result.metric,
          from: from,
          to: now,
        );
        final line =
            '${result.metric.name}: +${result.dataPointCount} written, '
            '${onDisk.length} on disk';
        lines.add(line);
        debugPrint(line);
      }
      for (final metric in HealthMetric.values) {
        if (!granted.contains(metric)) {
          final line = '${metric.name}: not granted';
          lines.add(line);
          debugPrint(line);
        }
      }
    } on Exception catch (error) {
      lines.add('error: $error');
    }

    if (!mounted) return;
    setState(() {
      _running = false;
      _status = lines.join('\n');
    });
  }

  Future<void> _connect() async {
    final coordinator = await _coordinator();
    if (!mounted) return;
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ConnectNextcloudPage(coordinator: coordinator),
      ),
    );
    if (connected ?? false) {
      await _refreshConnection();
    }
  }

  Future<void> _disconnect() async {
    final coordinator = await _coordinator();
    await coordinator.disconnect();
    if (!mounted) return;
    setState(() => _syncStatus = '');
    await _refreshConnection();
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _syncStatus = 'Syncing…';
    });
    try {
      final coordinator = await _coordinator();
      if (!await coordinator.isConnected()) {
        _setSync('Connect a Nextcloud first.');
        return;
      }
      final report = await coordinator.syncNow();
      final parts = <String>[
        '${report.pushed.length} pushed, ${report.skipped} up to date',
        if (report.hasConflicts)
          '⚠ ${report.conflicts.length} conflict copies on server',
        ...report.errors,
      ];
      _setSync(parts.join('\n'));
    } on NextcloudSyncException catch (error) {
      _setSync('Sync failed: ${error.message}');
    } on http.ClientException catch (error) {
      // Surface only the message, not the full URL (which carries the path).
      _setSync('Sync failed: ${error.message}');
    } on Exception catch (error) {
      _setSync('Sync failed: $error');
    }
  }

  void _setSync(String message) {
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncStatus = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cairn')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Cairn'),
              if (kDebugMode) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _running ? null : _readAndPersist,
                  child: const Text('Read & persist (debug)'),
                ),
                const SizedBox(height: 8),
                Text(_status, textAlign: TextAlign.center),
                const Divider(height: 48),
                Text(_connection, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _syncing ? null : _connect,
                      child: const Text('Connect'),
                    ),
                    OutlinedButton(
                      onPressed: _syncing ? null : _disconnect,
                      child: const Text('Disconnect'),
                    ),
                    FilledButton(
                      onPressed: _syncing ? null : _syncNow,
                      child: const Text('Sync now'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_syncStatus, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

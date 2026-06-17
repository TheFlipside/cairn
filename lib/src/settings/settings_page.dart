import 'dart:async';

import 'package:cairn/l10n/app_localizations.dart';
import 'package:cairn/src/dashboard/connect_nextcloud_page.dart';
import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/onboarding/setup_guide_page.dart';
import 'package:cairn/src/profile/profile.dart';
import 'package:cairn/src/settings/locale_controller.dart';
import 'package:cairn/src/shell/cairn_services.dart';
import 'package:cairn/src/storage/health_ingest_service.dart';
import 'package:cairn/src/sync/nextcloud_sync_target.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Product settings: Nextcloud connection + manual sync, the profile editor
/// (height + date of birth for BMI), the app-language picker, and a debug-only
/// developer section.
class SettingsPage extends StatefulWidget {
  /// Creates the settings page.
  const SettingsPage({
    required this.services,
    required this.localeController,
    super.key,
  });

  /// Shared app services.
  final CairnServices services;

  /// The app-wide locale source, edited by the language picker.
  final LocaleController localeController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _height = TextEditingController();
  bool _connLoaded = false;
  String? _account; // login@host when connected, null otherwise
  String _syncStatus = '';
  String _debugStatus = '';
  Profile _profile = Profile.empty();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _height.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final credentials = await widget.services.coordinator.currentCredentials();
    if (!mounted) return;
    final profile = widget.services.profile.value;
    setState(() {
      _connLoaded = true;
      _account = credentials == null
          ? null
          : '${credentials.loginName}@${credentials.server.host}';
      _profile = profile;
      _height.text = profile.heightCm == null
          ? ''
          : profile.heightCm!.toStringAsFixed(0);
    });
  }

  Future<void> _connect() async {
    final connected = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ConnectNextcloudPage(coordinator: widget.services.coordinator),
      ),
    );
    if (connected ?? false) await _load();
  }

  Future<void> _disconnect() async {
    await widget.services.coordinator.disconnect();
    if (!mounted) return;
    setState(() => _syncStatus = '');
    await _load();
  }

  Future<void> _syncNow() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _syncing = true;
      _syncStatus = l10n.settingsSyncing;
    });
    String status;
    try {
      if (!await widget.services.coordinator.isConnected()) {
        status = l10n.settingsConnectFirst;
      } else {
        final report = await widget.services.coordinator.syncNow();
        final conflicts = report.hasConflicts
            ? ' · ${l10n.settingsSyncConflicts(report.conflicts.length)}'
            : '';
        status =
            '${l10n.settingsSyncResult(report.pushed.length, report.skipped)}'
            '$conflicts';
      }
    } on NextcloudSyncException catch (e) {
      // NextcloudSyncException.message is a controlled, non-sensitive string.
      status = l10n.settingsSyncFailed(e.message);
    } on Exception catch (e) {
      // Unexpected/untyped error → generic message; never echo the raw cause.
      debugPrint('Sync failed: $e');
      status = l10n.settingsSyncFailedGeneric;
    }
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _syncStatus = status;
    });
  }

  Future<void> _saveHeight() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final text = _height.text.trim();
    double? value;
    if (text.isNotEmpty) {
      // Accept a comma decimal separator (German keypads) before parsing.
      final parsed = double.tryParse(text.replaceAll(',', '.'));
      // Reject non-finite (`Infinity`/`NaN` parse) and implausible heights;
      // a non-finite value would also crash the JSON encoder on write.
      if (parsed == null || !parsed.isFinite || parsed < 30 || parsed > 300) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.settingsHeightInvalid)),
        );
        return;
      }
      value = parsed;
    }
    // Construct directly (not copyWith) so a blank field clears the height.
    final next = Profile(
      heightCm: value,
      dateOfBirth: _profile.dateOfBirth,
    );
    await widget.services.profileStore.write(next);
    // The shell (and the notifier it owns) may be gone after the await.
    if (!mounted) return;
    widget.services.profile.value = next; // notify Home's BMI card
    setState(() => _profile = next);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          value == null ? l10n.settingsHeightCleared : l10n.settingsHeightSaved,
        ),
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _profile.dateOfBirth ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    final next = _profile.copyWith(dateOfBirth: picked);
    await widget.services.profileStore.write(next);
    if (!mounted) return;
    widget.services.profile.value = next; // notify Home's BMI card
    setState(() => _profile = next);
  }

  void _selectLocale(String? code) {
    unawaited(
      widget.localeController.setLocale(code == null ? null : Locale(code)),
    );
  }

  Future<void> _ingestDebug() async {
    setState(() => _debugStatus = 'Reading…');
    final lines = <String>[];
    try {
      final repo = widget.services.repository;
      final granted = await repo.requestAuthorization(
        HealthMetric.values.toSet(),
      );
      final results = await HealthIngestService(
        repository: repo,
        store: widget.services.store,
      ).ingest(granted);
      for (final r in results) {
        lines.add('${r.metric.name}: +${r.dataPointCount}');
      }
      widget.services.dataRevision.value++; // reload screens like a refresh
    } on Exception catch (e) {
      lines.add('error: $e');
    }
    if (!mounted) return;
    setState(() => _debugStatus = lines.join('\n'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dob = _profile.dateOfBirth;
    final connectionText = !_connLoaded
        ? l10n.settingsConnChecking
        : (_account ?? l10n.settingsConnNotConnected);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.settingsNextcloud, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(connectionText),
                  if (_syncStatus.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(_syncStatus, style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _syncing ? null : _connect,
                        child: Text(l10n.actionConnect),
                      ),
                      OutlinedButton(
                        onPressed: _syncing ? null : _disconnect,
                        child: Text(l10n.settingsActionDisconnect),
                      ),
                      FilledButton(
                        onPressed: _syncing ? null : _syncNow,
                        child: Text(l10n.settingsActionSyncNow),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.settingsProfile, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.settingsProfileDesc, style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _height,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.settingsHeightLabel,
                            suffixText: 'cm',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _saveHeight,
                        child: Text(l10n.actionSave),
                      ),
                    ],
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.settingsDob),
                    subtitle: Text(
                      dob == null
                          ? l10n.settingsDobNotSet
                          : '${dob.year}-${_two(dob.month)}-${_two(dob.day)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _pickDob,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.settingsLanguage, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<String?>(
                value: widget.localeController.value?.languageCode,
                isExpanded: true,
                underline: const SizedBox.shrink(),
                onChanged: _selectLocale,
                items: [
                  // The null value is the "follow system" sentinel; it is left
                  // implicit because avoid_redundant_argument_values forbids a
                  // literal `value: null`.
                  DropdownMenuItem<String?>(
                    child: Text(l10n.settingsLanguageSystem),
                  ),
                  const DropdownMenuItem<String?>(
                    value: 'en',
                    child: Text('English'),
                  ),
                  const DropdownMenuItem<String?>(
                    value: 'de',
                    child: Text('Deutsch'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(l10n.settingsHelp, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.settingsHelpGuideTitle),
              subtitle: Text(l10n.settingsHelpGuideSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const SetupGuidePage(),
                ),
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            Text(l10n.settingsDeveloper, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _ingestDebug,
              child: Text(l10n.settingsDevIngest),
            ),
            if (_debugStatus.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_debugStatus, style: theme.textTheme.bodySmall),
              ),
          ],
        ],
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}

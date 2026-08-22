import 'package:cairn/l10n/app_localizations.dart';
import 'package:cairn/src/shell/sync_error_feedback.dart';
import 'package:cairn/src/sync/nextcloud_sync_target.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLocalizations en;
  late AppLocalizations de;

  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    de = await AppLocalizations.delegate.load(const Locale('de'));
  });

  test('every kind has a message in both languages', () {
    for (final kind in SyncErrorKind.values) {
      final error = NextcloudSyncException('technical detail', kind: kind);

      expect(error.localizedMessage(en), isNotEmpty, reason: '$kind in en');
      expect(error.localizedMessage(de), isNotEmpty, reason: '$kind in de');
    }
  });

  // The reported bug: the German UI showed English server-facing strings.
  test('the English diagnostic never reaches the German message', () {
    for (final kind in SyncErrorKind.values) {
      final error = NextcloudSyncException(
        'Login Flow v2 init failed',
        kind: kind,
      );

      expect(
        error.localizedMessage(de),
        isNot(contains('Login Flow v2')),
        reason: '$kind leaked its diagnostic',
      );
    }
  });

  test('a login failure is translated, not echoed', () {
    const error = NextcloudSyncException(
      'Login Flow v2 init failed',
      kind: SyncErrorKind.loginFailed,
      statusCode: 500,
    );

    expect(
      error.localizedMessage(en),
      'Nextcloud rejected the login. (HTTP 500)',
    );
    expect(
      error.localizedMessage(de),
      startsWith('Nextcloud hat die Anmeldung'),
    );
  });

  test('the status code is appended, so the user can quote it', () {
    const error = NextcloudSyncException(
      'PUT failed',
      kind: SyncErrorKind.serverRejected,
      statusCode: 507,
    );

    expect(error.localizedMessage(en), contains('507'));
  });

  test('a status-less failure carries no HTTP suffix', () {
    const error = NextcloudSyncException(
      'network error: no route to host',
      kind: SyncErrorKind.network,
    );

    expect(error.localizedMessage(en), 'Could not reach the server.');
  });

  // 401/403 arrive as a plain status on every endpoint, so the mapping is
  // driven by the code rather than by each throw site.
  test('an expired app password reads as access denied, whatever the kind', () {
    for (final status in [401, 403]) {
      final error = NextcloudSyncException(
        'PROPFIND failed',
        kind: SyncErrorKind.serverRejected,
        statusCode: status,
      );

      expect(error.localizedMessage(en), contains('Access denied'));
    }
  });

  test('a not-found already reads as such, so the 404 is not repeated', () {
    const error = NextcloudNotFoundException(
      '/Cairn/steps/2026/2026-06-14.jsonl',
    );

    expect(error.localizedMessage(en), 'The file was not found on the server.');
  });
}

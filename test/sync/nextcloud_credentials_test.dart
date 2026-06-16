import 'package:cairn/src/sync/nextcloud_credentials.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  NextcloudCredentials creds() => NextcloudCredentials(
    server: Uri.parse('https://cloud.example.com'),
    loginName: 'alice',
    appPassword: 's3cr3t',
  );

  test('toJson/fromJson round-trips', () {
    final restored = NextcloudCredentials.fromJson(creds().toJson());
    expect(restored.server, Uri.parse('https://cloud.example.com'));
    expect(restored.loginName, 'alice');
    expect(restored.appPassword, 's3cr3t');
  });

  test('webDavBase points at the account files endpoint', () {
    expect(
      creds().webDavBase,
      Uri.parse('https://cloud.example.com/remote.php/dav/files/alice/'),
    );
  });

  test('webDavBase preserves a sub-directory install path', () {
    final c = NextcloudCredentials(
      server: Uri.parse('https://example.com/nextcloud'),
      loginName: 'bob',
      appPassword: 'pw',
    );
    expect(
      c.webDavBase,
      Uri.parse('https://example.com/nextcloud/remote.php/dav/files/bob/'),
    );
  });

  test('constructor rejects a non-https server', () {
    expect(
      () => NextcloudCredentials(
        server: Uri.parse('http://cloud.example.com'),
        loginName: 'alice',
        appPassword: 'pw',
      ),
      throwsArgumentError,
    );
  });

  test('fromJson rejects a non-https server with a FormatException', () {
    expect(
      () => NextcloudCredentials.fromJson(const {
        'server': 'http://cloud.example.com',
        'login_name': 'alice',
        'app_password': 'pw',
      }),
      throwsFormatException,
    );
  });

  test('fromJson rejects a missing field', () {
    expect(
      () =>
          NextcloudCredentials.fromJson(const {'server': 'https://x.example'}),
      throwsFormatException,
    );
  });
}

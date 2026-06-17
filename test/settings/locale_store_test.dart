import 'dart:io';

import 'package:cairn/src/settings/locale_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('cairn_locale_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  LocaleStore store() =>
      LocaleStore(file: File(p.join(dir.path, 'preferences.json')));

  test('returns null when nothing is stored (follow system)', () async {
    expect(await store().read(), isNull);
  });

  test('round-trips a language code', () async {
    final s = store();
    await s.write('de');
    expect(await s.read(), 'de');
  });

  test('writing null clears the stored language', () async {
    final s = store();
    await s.write('de');
    await s.write(null);
    expect(await s.read(), isNull);
  });

  test('tolerates a corrupt preferences file', () async {
    final file = File(p.join(dir.path, 'preferences.json'))
      ..writeAsStringSync('{ not valid json');
    expect(await LocaleStore(file: file).read(), isNull);
  });
}

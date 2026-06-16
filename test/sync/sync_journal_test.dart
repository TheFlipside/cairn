import 'dart:io';

import 'package:cairn/src/sync/sync_journal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late JsonSyncJournalStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cairn_journal_test');
    store = JsonSyncJournalStore(
      file: File(p.join(tempDir.path, 'cairn', 'sync_journal.json')),
    );
  });
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('read returns an empty journal when the file is missing', () async {
    final journal = await store.read();
    expect(journal.files, isEmpty);
  });

  test('write then read round-trips entries', () async {
    final journal = SyncJournal.empty()
        .withEntry('Cairn/manifest.json', const RemoteFileState(size: 10))
        .withEntry(
          'Cairn/steps/2026/2026-06-14.jsonl',
          const RemoteFileState(size: 256, etag: 'abc'),
        );

    await store.write(journal);
    final read = await store.read();

    expect(read.files.length, 2);
    expect(read.files['Cairn/manifest.json']!.size, 10);
    final shard = read.files['Cairn/steps/2026/2026-06-14.jsonl']!;
    expect(shard.size, 256);
    expect(shard.etag, 'abc');
  });

  test('write leaves no temp file behind', () async {
    await store.write(
      SyncJournal.empty().withEntry('x', const RemoteFileState(size: 1)),
    );
    final dir = store.file.parent;
    final leftovers = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.tmp'),
    );
    expect(leftovers, isEmpty);
  });

  test('fromJson tolerates malformed entries', () {
    final journal = SyncJournal.fromJson(const {
      'files': {
        'good': {'size': 5, 'etag': 'e'},
        'bad': 'not-a-map',
      },
    });
    expect(journal.files.keys, ['good']);
    expect(journal.files['good']!.size, 5);
  });
}

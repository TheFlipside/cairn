import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Recorded state of one file the last time this device pushed it to Nextcloud.
@immutable
class RemoteFileState {
  /// Creates a recorded push state.
  const RemoteFileState({required this.size, this.etag});

  /// Restores from the JSON map written by [toJson].
  factory RemoteFileState.fromJson(Map<String, Object?> json) {
    final size = json['size'];
    final etag = json['etag'];
    return RemoteFileState(
      size: size is int ? size : 0,
      etag: etag is String ? etag : null,
    );
  }

  /// Byte length of the file when it was last pushed. A later size change is
  /// the cheap "needs push" signal for append-only shards.
  final int size;

  /// ETag the server returned for the last push, or `null` if none.
  final String? etag;

  /// Serialises to a JSON map.
  Map<String, Object?> toJson() => {
    'size': size,
    if (etag != null) 'etag': etag,
  };
}

/// The device-local record of what this device has already pushed, keyed by
/// remote path (e.g. `Cairn/steps/2026/2026-06-14.jsonl`).
///
/// **Never** part of the synced `/Cairn/` tree: it describes one device's push
/// progress and must not round-trip through Nextcloud (DESIGN.md §6).
@immutable
class SyncJournal {
  /// Creates a journal from [files] (remote path → last-pushed state).
  const SyncJournal(this.files);

  /// An empty journal (nothing pushed yet).
  factory SyncJournal.empty() => const SyncJournal({});

  /// Parses a journal map, tolerating missing or malformed entries.
  factory SyncJournal.fromJson(Map<String, Object?> json) {
    final files = <String, RemoteFileState>{};
    final raw = json['files'];
    if (raw is Map<String, Object?>) {
      raw.forEach((path, value) {
        if (value is Map<String, Object?>) {
          files[path] = RemoteFileState.fromJson(value);
        }
      });
    }
    return SyncJournal(files);
  }

  /// Remote path → last-pushed state.
  final Map<String, RemoteFileState> files;

  /// Returns a copy with [path] recorded as [state].
  SyncJournal withEntry(String path, RemoteFileState state) =>
      SyncJournal({...files, path: state});

  /// Serialises to the journal JSON object.
  Map<String, Object?> toJson() => {
    'files': {for (final e in files.entries) e.key: e.value.toJson()},
  };
}

/// Reads and writes a [SyncJournal] under the app-support directory, outside
/// the synced cache. Writes are atomic (temp file + rename).
final class JsonSyncJournalStore {
  /// Creates a store backed by [file].
  JsonSyncJournalStore({required this.file});

  /// Resolves the journal at `<app-support>/cairn/sync_journal.json`.
  static Future<JsonSyncJournalStore> appSupport() async {
    final support = await getApplicationSupportDirectory();
    return JsonSyncJournalStore(
      file: File(p.join(support.path, 'cairn', 'sync_journal.json')),
    );
  }

  /// The journal file (kept out of the synced `/Cairn/` tree).
  final File file;

  /// Reads the journal, returning an empty one if it is missing or corrupt.
  Future<SyncJournal> read() async {
    if (!file.existsSync()) return SyncJournal.empty();
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) {
        return SyncJournal.fromJson(decoded);
      }
    } on FormatException {
      // Corrupt journal → start fresh; the next push re-establishes state.
    } on FileSystemException {
      // Vanished between the check and the read → treat as empty.
    }
    return SyncJournal.empty();
  }

  /// Writes [journal] atomically (temp file + rename).
  Future<void> write(SyncJournal journal) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    final json = const JsonEncoder.withIndent('  ').convert(journal.toJson());
    await tmp.writeAsString(json, flush: true);
    await tmp.rename(file.path);
  }
}

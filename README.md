# Cairn

**A personal health-data aggregator that you own end to end.**

Cairn reads your wearable and phone health data from the platform's own health
store (Apple HealthKit / Android Health Connect), normalizes it into an open,
documented file format (Open mHealth / IEEE 1752.1, as sharded JSON Lines), and
syncs it into a **Nextcloud you control**. No central server, no proprietary
database, no vendor lock-in — the files in your Nextcloud are the single source
of truth.

It is deliberately aimed at privacy-conscious people and self-hosters who run
(or will happily run) their own Nextcloud. "Bring your own Nextcloud" is the
feature, not a barrier.

## Components

- **Mobile app** (Flutter, iOS + Android) — reads the health store, writes OMH
  files, syncs over WebDAV. The only writer. *(MIT)*
- **Nextcloud web app** (PHP + Vue, *planned*) — an optional, read-only second
  frontend over the same files. *(AGPL-3.0-or-later — Nextcloud app store)*

## Status

Early development. The repository currently contains the project foundation:
Flutter scaffold, architecture skeleton, and documentation. See the phased plan
in [docs/DESIGN.md §15](docs/DESIGN.md).

## Documentation

- [docs/DESIGN.md](docs/DESIGN.md) — full design and rationale (source of truth).
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) — set up a dev environment from
  scratch (Flutter and the future Nextcloud app).
- [CHANGELOG.md](CHANGELOG.md) — notable changes.

## License

The mobile app and the OMH file format are released under the
[MIT License](LICENSE). The future Nextcloud web app will ship from its own
subtree under AGPL-3.0-or-later (it links AGPL Nextcloud server code); see
[docs/DEVELOPMENT.md §5](docs/DEVELOPMENT.md).

## Not a medical device

Cairn aggregates and visualizes data. It makes no diagnostic, treatment, or
clinical claims.

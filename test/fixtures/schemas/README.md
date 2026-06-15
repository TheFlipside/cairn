# Vendored JSON Schemas (test fixtures)

These JSON Schema files are vendored so Cairn's tests can validate every emitted
OMH datapoint **offline**, against the authoritative schemas, with no network
access (DESIGN.md §13 — "the format is the product's durability guarantee").

## Sources & licensing

Both upstreams are **Apache-2.0** (see `omh/LICENSE`, `ieee/LICENSE`), which is
compatible with this MIT project. Attribution is preserved per the license.

- `omh/` — base measures + utility schemas from
  [openmhealth/schemas](https://github.com/openmhealth/schemas) (`main`):
  `heart-rate-1.0`, `step-count-3.0`, `body-weight-2.0`, `header`, `schema-id`,
  and their `$ref` dependencies.
- `ieee/` — IEEE 1752.1-2021 measures + utility schemas from
  [opensource.ieee.org/omh/1752](https://opensource.ieee.org/omh/1752) (`main`):
  `physical-activity-1.0`, `sleep-episode-1.0`, and their `$ref` dependencies.

## Local modification (changes per Apache-2.0 §4)

OpenMHealth's `*-1.x.json` files are **"latest-minor" redirect stubs** whose body
is a bare filename (e.g. `unit-value-1.x.json` contains the text
`unit-value-1.0.json`), not JSON. A standard JSON-Schema validator cannot follow
them. Each such stub here has been **resolved in place** to the concrete target
schema's content, so the offline `RefProvider` can load every `$ref` by filename.
No schema semantics were changed. The IEEE files use concrete `*-1.0.json` refs
and are unmodified.

The Cairn-authored `cairn:sleep-stage` schema is **not** here — it lives with the
source at `lib/src/omh/schemas/cairn/sleep-stage-1.0.json` (it ships as part of
the format) and is loaded directly by tests.

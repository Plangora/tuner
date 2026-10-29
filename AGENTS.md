# Project conventions

## Changelog and release notes

- Update `CHANGELOG.md` whenever adding a feature, fixing a bug or changing
  user-visible behavior. Include the entry with the implementation rather
  than leaving it until release time.
- Follow the existing newest-first format, with Added, Changed and Fixed
  sections as needed. Describe the effect on users in plain language;
  omit empty categories and routine internal refactoring.
- Put changes in the top **Unreleased** version section, matching the full
  `version:` in `pubspec.yaml`, including its build number. If that version
  is already released, choose the next version/build before adding a new
  Unreleased section; do not rewrite released entries for new changes.
- When preparing a release, review that section against the changes since
  the previous tag, replace Unreleased with the release date and use its
  entries for release notes. Follow `docs/DISTRIBUTION.md`; release tags
  use `v<version>+<build>`.
- Historical entries must distinguish git evidence from confirmed store
  publication dates. Do not invent release dates or claim unverified
  device testing.

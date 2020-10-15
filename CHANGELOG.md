# CHANGELOG

## 0.0.4 - Unreleased
### Fixed
- Use QA location codes in qa/dev environments
- Better handling of date fields (including seasons and month abbreviations)
- Fix bug in logger when no location is attached to record
- Improve handling of missing 853 fields in records
- Lowercase all field names for 853 chronologies

## 0.0.3 - 2020-10-01
### Fixed
- Cleaned up parsing of holding field (863/866) objects

## 0.0.2 - 2020-09-22
### Added
- Added rubocop for linting and linted all files
### Fixed
- Better locations error handling
- Improved parsing of 853/863 fields
- Updated nypl_core_util and loaded deployment helper class from there

## 0.0.1 - 2020-09-17
### Added
- Initial commit containing basic structure and location parser
- Added supporting documentation and unit test suite
- Added integration with check-in card data

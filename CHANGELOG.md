# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- Install `unzip` in the production image build stage so `bin/fetch-crsqlite` can extract downloaded cr-sqlite archives.
- Report missing `curl` or `unzip` prerequisites explicitly in `bin/fetch-crsqlite`.
- Run Debian package installation noninteractively during image builds.

# Before distributing a binary

- Build a reviewed source revision on the target distribution and record its commit and build options.
- Test the packaged executable, desktop metadata, artwork, profile continuity and notification behavior with synthetic accounts.
- Verify the installed component notices and individual licences. Supply the complete corresponding source, checksums and required dependency sources alongside the binary; see [source delivery](docs/release/CORRESPONDING-SOURCE.md).
- Publish no profiles, credentials, signing material or build logs containing local data.

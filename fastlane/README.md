fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android listing

```sh
[bundle exec] fastlane android listing
```

Upload Play Store listing text and graphics (no binary)

### android internal

```sh
[bundle exec] fastlane android internal
```

Upload a production AAB to the internal testing track

### android closed

```sh
[bundle exec] fastlane android closed
```

Upload a production AAB to closed testing (alpha)

### android production

```sh
[bundle exec] fastlane android production
```

Upload a production AAB to the production track and send for review

### android testing

```sh
[bundle exec] fastlane android testing
```

Upload a production AAB to internal and closed testing

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).

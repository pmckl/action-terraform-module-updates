# action-terraform-module-update

## Introduction

The purpose of this actions is to run within pull-requests to check if is there an update any module used by your terraform code.

Wherever there is an update available, it will add a PR comment, with the available new versions.
If you keep updating your PR, the above mention comment will be updated, so it wont spam your pr with many comments.

### Usage
```yaml
---
name: pull-request

on:
  pull_request:
    branches:
      - main
      - master

jobs:
  release:
    name: pull-request
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - uses: pmckl/action-terraform-module-updates
        with:
          directory: |
            /test-module-updates
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE)

# rbrownwsws/wolfi-rclone

A [Wolfi](https://github.com/wolfi-dev/os) package of [rclone](https://rclone.org/) built with [melange](https://github.com/chainguard-dev/melange)

## Using this package with `apko`

```yaml
contents:
  keyring:
    - https://packages.wolfi.dev/os/wolfi-signing.rsa.pub
    # Add my signing key
    - https://rbrownwsws.github.io/wolfi-rclone/rbrownwsws.github.io-wolfi-rclone.rsa.pub
  repositories:
    - https://packages.wolfi.dev/os
    # Add my package repo (you can choose your own tag)
    - "@myrepo https://rbrownwsws.github.io/wolfi-rclone"
  packages:
    - wolfi-base
    - ca-certificates-bundle
    # Tell apko to get rclone from the tagged repo
    - rclone@myrepo

entrypoint:
  command: /bin/sh -l
```

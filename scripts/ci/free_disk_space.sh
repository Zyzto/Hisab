#!/usr/bin/env bash
# Reclaim runner disk before an Android build.
#
# Flutter's Android build needs substantial temporary disk space. The
# toolchains removed here are shipped in the GitHub runner image for other
# ecosystems and are not used by this project. The Android SDK and NDK remain.
set -euo pipefail

before=$(df --output=avail -m / | tail -1)

for path in \
  /usr/share/dotnet \
  /usr/share/swift \
  /opt/ghc \
  /usr/local/.ghcup \
  /usr/local/share/boost \
  /usr/local/share/powershell \
  /opt/hostedtoolcache/CodeQL \
  /opt/hostedtoolcache/Ruby \
  /opt/hostedtoolcache/go \
  /opt/hostedtoolcache/PyPy; do
  sudo rm -rf "$path" 2>/dev/null || true
done

sudo docker image prune --all --force >/dev/null 2>&1 || true

after=$(df --output=avail -m / | tail -1)
echo "Freed $(( after - before )) MB; ${after} MB now available on /"

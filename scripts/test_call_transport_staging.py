#!/usr/bin/env python
from __future__ import print_function

import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
with open(os.path.join(ROOT, "build_legacy.sh"), "r") as handle:
    source = handle.read()

# Execute the real preservation/cleanup section without building dependencies
# or an application. Input inside either output bundle used to be deleted here.
start = source.index('TDJSON_STAGED_PATH=""')
cleanup = 'rm -rf "$BUILD_ROOT" "$APP_NAME"'
end = source.index(cleanup, start) + len(cleanup)
section = source[start:end]
prefix = '''set -euo pipefail
cd "$1"
BUILD_ROOT="build-legacy"
APP_NAME="Telegraphica.app"
BUNDLED_TDLIB_CONFIG_SOURCE=""
BUNDLED_TDLIB_CREDENTIALS_SOURCE=""
ditto() { cp "$1" "$2"; }
'''
suffix = '''
if [ -n "${TELEGRAPHICA_MODERN_CALL_TRANSPORT_PATH:-}" ]; then
    printf '%s\\n' "$TELEGRAPHICA_MODERN_CALL_TRANSPORT_PATH" > staged-path.txt
    cp "$TELEGRAPHICA_MODERN_CALL_TRANSPORT_PATH" preserved.bin
fi
'''
payload = b"verified transport fixture\x00unchanged\xff"


def check_case(relative_path, missing=False):
    fixture = tempfile.mkdtemp(prefix="telegraphica-transport-staging-test-")
    staged_path = None
    try:
        input_path = os.path.join(fixture, relative_path)
        os.makedirs(os.path.dirname(input_path))
        sentinel = os.path.join(fixture, "build-legacy", "keep-before-validation.txt")
        if not os.path.isdir(os.path.dirname(sentinel)):
            os.makedirs(os.path.dirname(sentinel))
        with open(sentinel, "w") as handle:
            handle.write("old output")
        if not missing:
            with open(input_path, "wb") as handle:
                handle.write(payload)
        environment = dict(os.environ)
        for name in list(environment):
            if name.startswith("TELEGRAPHICA_"):
                del environment[name]
        environment["TELEGRAPHICA_MODERN_CALL_TRANSPORT_PATH"] = input_path
        # Override discovery so installed application dependencies are never
        # touched when this fixture runs on the legacy machine.
        tdjson_fixture = os.path.join(fixture, "tdjson-fixture.dylib")
        with open(tdjson_fixture, "wb") as handle:
            handle.write(b"tdjson fixture")
        environment["TELEGRAPHICA_TDJSON_PATH"] = tdjson_fixture
        environment["TELEGRAPHICA_TDJSON_MOUNTAIN_LION_PATH"] = tdjson_fixture
        process = subprocess.Popen(["/bin/bash", "-c", prefix + section + suffix,
                                    "transport-staging-test", fixture],
                                   env=environment, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE)
        stdout, stderr = process.communicate()
        if missing:
            assert process.returncode != 0, "missing transport was accepted"
            assert os.path.isfile(sentinel), "invalid input destroyed previous output"
            return
        assert process.returncode == 0, "staging failed: %r %r" % (stdout, stderr)
        with open(os.path.join(fixture, "preserved.bin"), "rb") as handle:
            assert handle.read() == payload, "transport bytes changed during staging"
        with open(os.path.join(fixture, "staged-path.txt"), "r") as handle:
            staged_path = handle.read().strip()
        assert staged_path != input_path, "transport was not preserved outside output"
        assert not os.path.exists(input_path), "fixture did not simulate output cleanup"
        assert not os.path.exists(staged_path), "EXIT trap left a staged transport file"
    finally:
        if staged_path and os.path.isfile(staged_path):
            os.remove(staged_path)
        shutil.rmtree(fixture)


check_case("build-legacy/Release/Telegraphica.app/Contents/Frameworks/TelegraphicaCallTransport.dylib")
check_case("Telegraphica.app/Contents/Frameworks/TelegraphicaCallTransport.dylib")
check_case("build-legacy/Release/Telegraphica.app/Contents/Frameworks/missing.dylib", missing=True)
print("Call transport staging regression checks passed.")

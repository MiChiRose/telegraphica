#!/usr/bin/env python
from __future__ import print_function

import os
import shutil
import tempfile

root = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
scanner_path = os.path.join(root, "scripts", "check_legacy_compat.py")
# Python 2.7 runpy clears its temporary module after returning a copy of the
# namespace, leaving returned functions with cleared globals. Keep the executed
# scanner's namespace alive for its helper functions throughout this probe.
scanner = {"__name__": "telegraphica_legacy_scanner_probe", "__file__": scanner_path}
with open(scanner_path, "rb") as handle:
    eval(compile(handle.read(), scanner_path, "exec"), scanner)
fixture_root = tempfile.mkdtemp(prefix="telegraphica-legacy-scanner-")
try:
    sources = os.path.join(fixture_root, "Sources")
    os.makedirs(sources)
    fixture = os.path.join(sources, "fixture.inc")
    with open(fixture, "w") as handle:
        handle.write('id view = [[NSVisualEffectView alloc] init];\n')
        handle.write('NSArray<NSString *> *items;\n')
        handle.write('id api_hash = @"fixture-secret-value";\n')
    scanner["ROOT"] = fixture_root
    errors = []
    scanner["check_sources"](errors)
    assert len(errors) == 3, "implementation includes must undergo API, compiler and secret checks: %r" % errors
    with open(fixture, "w") as handle:
        handle.write('id color = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];\n')
    errors = []
    scanner["check_sources"](errors)
    assert not errors, "legacy-safe implementation include should pass: %r" % errors
finally:
    shutil.rmtree(fixture_root)
print("Legacy implementation include scanner probe passed.")

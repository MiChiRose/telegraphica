#!/usr/bin/env python
from __future__ import print_function

import os
import runpy
import shutil
import tempfile

root = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))
scanner = runpy.run_path(os.path.join(root, "scripts", "check_legacy_compat.py"))
fixture_root = tempfile.mkdtemp(prefix="telegraphica-legacy-scanner-")
try:
    sources = os.path.join(fixture_root, "Sources")
    os.makedirs(sources)
    fixture = os.path.join(sources, "fixture.inc")
    with open(fixture, "w") as handle:
        handle.write('id view = [[NSVisualEffectView alloc] init];\n')
        handle.write('NSArray<NSString *> *items;\n')
        handle.write('id api_hash = @"fixture-secret-value";\n')
    scanner["check_sources"].__globals__["ROOT"] = fixture_root
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

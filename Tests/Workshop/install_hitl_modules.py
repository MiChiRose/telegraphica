#!/usr/bin/env python
from __future__ import print_function

import os
import plistlib
import shutil
import sys
import tempfile
from datetime import datetime


MODULES = (
    ("TicTacToe", "com.michirose.telegraphica.workshop.tictactoe"),
    ("Minesweeper", "com.michirose.telegraphica.workshop.minesweeper"),
    ("Checkers", "com.michirose.telegraphica.workshop.checkers"),
    ("Solitaire", "com.michirose.telegraphica.workshop.solitaire"),
)


def load_plist(path):
    if not os.path.exists(path):
        return {}
    try:
        if hasattr(plistlib, "load"):
            with open(path, "rb") as source:
                return plistlib.load(source)
        return plistlib.readPlist(path)
    except Exception:
        return {}


def write_plist(value, path):
    directory = os.path.dirname(path)
    fd, temporary_path = tempfile.mkstemp(prefix=".InstalledModules.", suffix=".tmp",
                                          dir=directory)
    os.close(fd)
    try:
        if hasattr(plistlib, "dump"):
            with open(temporary_path, "wb") as destination:
                plistlib.dump(value, destination)
        else:
            plistlib.writePlist(value, temporary_path)
        os.chmod(temporary_path, 0o600)
        os.rename(temporary_path, path)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def main():
    if len(sys.argv) != 3:
        print("usage: install_hitl_modules.py PRODUCTS_DIR APPLICATION_SUPPORT_DIR",
              file=sys.stderr)
        return 2

    products_dir = os.path.abspath(sys.argv[1])
    workshop_dir = os.path.join(os.path.abspath(sys.argv[2]), "Workshop")
    modules_dir = os.path.join(workshop_dir, "Modules")
    registry_path = os.path.join(workshop_dir, "InstalledModules.plist")
    if not os.path.isdir(modules_dir):
        os.makedirs(modules_dir, 0o700)

    root = load_plist(registry_path)
    records = root.get("modules") if isinstance(root, dict) else None
    if not isinstance(records, dict):
        records = {}

    for product_name, identifier in MODULES:
        source_bundle = os.path.join(products_dir, product_name + ".bundle")
        manifest_path = os.path.join(source_bundle, "Contents", "Resources",
                                     "WorkshopModule.plist")
        manifest = load_plist(manifest_path)
        version = manifest.get("version", "1.0.0")
        if not os.path.isdir(source_bundle):
            print("Missing Workshop bundle: " + source_bundle, file=sys.stderr)
            return 3

        version_dir = os.path.join(modules_dir, identifier, "Versions", version)
        destination_bundle = os.path.join(version_dir, identifier + ".bundle")
        if not os.path.isdir(version_dir):
            os.makedirs(version_dir, 0o700)
        if os.path.exists(destination_bundle):
            shutil.rmtree(destination_bundle)
        shutil.copytree(source_bundle, destination_bundle, symlinks=False)

        previous_record = records.get(identifier, {})
        previous_version = previous_record.get("active_version", "")
        if previous_version == version:
            previous_version = previous_record.get("previous_version", "")
        records[identifier] = {
            "active_version": version,
            "previous_version": previous_version,
            "disabled": False,
            "pending_removal": False,
            "remove_data": False,
            "installed_at": datetime.utcnow(),
            "manifest": manifest,
        }
        print("Installed HITL module: {0} {1}".format(identifier, version))

    write_plist({"schema_version": 1, "modules": records}, registry_path)
    print("Workshop HITL registry: " + registry_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())

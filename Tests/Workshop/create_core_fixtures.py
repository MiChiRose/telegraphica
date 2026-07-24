#!/usr/bin/env python3
"""Create isolated, short-lived Workshop packages for integration tests."""

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import pathlib
import plistlib
import shutil
import stat
import subprocess
import tempfile
from typing import Optional, Tuple
import zipfile


CATALOG_DOMAIN = b"TelegraphicaWorkshopCatalog/v1\0"
PACKAGE_DOMAIN = b"TelegraphicaWorkshopPackage/v1\0"
MODULE_ID = "com.michirose.telegraphica.workshop.tictactoe"


def run(*args: str, input_bytes: Optional[bytes] = None) -> bytes:
    return subprocess.run(
        args, input=input_bytes, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    ).stdout


def sign(key: pathlib.Path, domain: bytes, payload: bytes) -> str:
    signature = run("openssl", "dgst", "-sha256", "-sign", str(key),
                    input_bytes=domain + payload)
    return base64.b64encode(signature).decode("ascii")


def write_package(bundle: pathlib.Path, output: pathlib.Path) -> Tuple[str, int, int, int]:
    files = sorted(path for path in bundle.rglob("*") if path.is_file())
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            relative = f"{MODULE_ID}.bundle/{path.relative_to(bundle).as_posix()}"
            info = zipfile.ZipInfo(relative, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o755 if os.access(path, os.X_OK) else 0o644
            info.external_attr = mode << 16
            archive.writestr(info, path.read_bytes())
    payload = output.read_bytes()
    return (
        hashlib.sha256(payload).hexdigest(),
        len(payload),
        sum(path.stat().st_size for path in files),
        len(files),
    )


def patch_bundle(source: pathlib.Path, destination: pathlib.Path, version: str,
                 corrupt_manifest: bool = False) -> None:
    shutil.copytree(source, destination)
    info_path = destination / "Contents" / "Info.plist"
    manifest_path = destination / "Contents" / "Resources" / "WorkshopModule.plist"
    with info_path.open("rb") as stream:
        info = plistlib.load(stream)
    with manifest_path.open("rb") as stream:
        manifest = plistlib.load(stream)
    info["CFBundleShortVersionString"] = version
    info["CFBundleVersion"] = version
    manifest["version"] = version
    if corrupt_manifest:
        manifest["identifier"] = "com.example.invalid"
    with info_path.open("wb") as stream:
        plistlib.dump(info, stream, fmt=plistlib.FMT_XML, sort_keys=True)
    with manifest_path.open("wb") as stream:
        plistlib.dump(manifest, stream, fmt=plistlib.FMT_XML, sort_keys=True)


def package_record(bundle: pathlib.Path, output: pathlib.Path, version: str,
                   private_key: pathlib.Path) -> dict:
    digest, archive_size, unpacked_size, entry_count = write_package(bundle, output)
    description = f"{MODULE_ID}\n{version}\n{digest}".encode("utf-8")
    return {
        "path": str(output),
        "version": version,
        "sha256": digest,
        "archive_size": archive_size,
        "unpacked_size": unpacked_size,
        "entry_count": entry_count,
        "signature": sign(private_key, PACKAGE_DOMAIN, description),
    }


def entry_for_record(record: dict) -> dict:
    return {
        "id": MODULE_ID,
        "name": "Tic-Tac-Toe",
        "localized_name": {"en": "Tic-Tac-Toe", "ru": "Крестики-нолики"},
        "description": {"en": "Test module", "ru": "Тестовый модуль"},
        "version": record["version"],
        "api_version": 1,
        "minimum_app_version": "0.5.1",
        "minimum_os_version": "10.9",
        "architectures": ["x86_64"],
        "category": "games",
        "archive_size": record["archive_size"],
        "unpacked_size": record["unpacked_size"],
        "entry_count": record["entry_count"],
        "sha256": record["sha256"],
        "signature": {
            "key_id": "package-test",
            "algorithm": "rsa-pkcs1-sha256",
            "value": record["signature"],
        },
        "download_url": "https://example.com/module.zip",
        "icon_url": "https://example.com/icon.png",
        "changelog": {"en": "Test"},
        "permissions": ["module-data", "host-notifications"],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--products", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    args = parser.parse_args()
    if args.output.exists():
        shutil.rmtree(args.output)
    args.output.mkdir(parents=True)

    private_key = args.output / "private.pem"
    certificate_pem = args.output / "certificate.pem"
    certificate_der = args.output / "certificate.der"
    run(
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-sha256", "-nodes",
        "-days", "2", "-subj", "/CN=Telegraphica Workshop Tests/",
        "-keyout", str(private_key), "-out", str(certificate_pem),
    )
    run("openssl", "x509", "-in", str(certificate_pem), "-outform", "der",
        "-out", str(certificate_der))

    source_bundle = args.products / "TicTacToe.bundle"
    bundles = args.output / "bundles"
    bundles.mkdir()
    version_1_bundle = bundles / "v1.bundle"
    version_11_bundle = bundles / "v11.bundle"
    corrupt_bundle = bundles / "corrupt.bundle"
    patch_bundle(source_bundle, version_1_bundle, "1.0.0")
    patch_bundle(source_bundle, version_11_bundle, "1.1.0")
    patch_bundle(source_bundle, corrupt_bundle, "1.2.0", corrupt_manifest=True)

    package_1 = package_record(version_1_bundle, args.output / "module-1.0.0.zip",
                               "1.0.0", private_key)
    package_11 = package_record(version_11_bundle, args.output / "module-1.1.0.zip",
                                "1.1.0", private_key)
    package_bad = package_record(corrupt_bundle, args.output / "module-1.2.0-bad.zip",
                                 "1.2.0", private_key)

    payload = {
        "catalog_version": 1,
        "generated_at": "2026-01-01T00:00:00Z",
        "expires_at": "2036-01-01T00:00:00Z",
        "modules": [entry_for_record(package_1)],
    }
    payload_bytes = json.dumps(payload, ensure_ascii=False, separators=(",", ":"),
                               sort_keys=True).encode("utf-8")
    envelope = {
        "schema_version": 1,
        "key_id": "catalog-test",
        "algorithm": "rsa-pkcs1-sha256",
        "payload": base64.b64encode(payload_bytes).decode("ascii"),
        "catalog_signature": sign(private_key, CATALOG_DOMAIN, payload_bytes),
    }
    catalog_path = args.output / "WorkshopCatalog.json"
    catalog_path.write_text(json.dumps(envelope, indent=2) + "\n", encoding="utf-8")

    safe_zip = args.output / "safe.zip"
    with zipfile.ZipFile(safe_zip, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("safe/file.txt", b"safe")
    traversal_zip = args.output / "traversal.zip"
    with zipfile.ZipFile(traversal_zip, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("../escape.txt", b"escape")
    symlink_zip = args.output / "symlink.zip"
    with zipfile.ZipFile(symlink_zip, "w") as archive:
        info = zipfile.ZipInfo("link")
        info.create_system = 3
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive.writestr(info, b"/tmp/target")

    metadata = {
        "certificate_der": str(certificate_der),
        "catalog": str(catalog_path),
        "module_id": MODULE_ID,
        "packages": {
            "v1": package_1,
            "v11": package_11,
            "bad": package_bad,
        },
        "bundles": {
            "v1": str(version_1_bundle),
            "bad": str(corrupt_bundle),
        },
        "archives": {
            "safe": str(safe_zip),
            "traversal": str(traversal_zip),
            "symlink": str(symlink_zip),
        },
    }
    (args.output / "fixtures.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    private_key.unlink()
    certificate_pem.unlink()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Build deterministic Workshop ZIP packages and a signed catalog envelope."""

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
from typing import Optional
import zipfile


CATALOG_DOMAIN = b"TelegraphicaWorkshopCatalog/v1\0"
PACKAGE_DOMAIN = b"TelegraphicaWorkshopPackage/v1\0"

MODULES = {
    "TicTacToe": {
        "id": "com.michirose.telegraphica.workshop.tictactoe",
        "name": "Tic-Tac-Toe",
        "ru_name": "Крестики-нолики",
        "en_description": "A quick local match or a game against the computer.",
        "ru_description": "Быстрая локальная партия или игра против компьютера.",
        "category": "games",
    },
    "Minesweeper": {
        "id": "com.michirose.telegraphica.workshop.minesweeper",
        "name": "Minesweeper",
        "ru_name": "Сапёр",
        "en_description": "Clear a classic minefield with three difficulty levels.",
        "ru_description": "Классическое минное поле с тремя уровнями сложности.",
        "category": "games",
    },
    "Checkers": {
        "id": "com.michirose.telegraphica.workshop.checkers",
        "name": "Checkers",
        "ru_name": "Шашки",
        "en_description": "Play locally or against a lightweight computer opponent.",
        "ru_description": "Локальная игра или партия против лёгкого компьютерного соперника.",
        "category": "games",
    },
    "Solitaire": {
        "id": "com.michirose.telegraphica.workshop.solitaire",
        "name": "Solitaire",
        "ru_name": "Пасьянс",
        "en_description": "Classic draw-one Klondike with undo and saved progress.",
        "ru_description": "Классическая «Косынка» по одной карте с отменой хода и сохранением.",
        "category": "games",
    },
    "PacMan": {
        "id": "com.michirose.telegraphica.workshop.pacman",
        "name": "Pac-Man",
        "ru_name": "Pac-Man",
        "en_description": "A lightweight native maze chase for classic Macs.",
        "ru_description": "Лёгкая нативная погоня по лабиринту для старых Mac.",
        "category": "games",
    },
    "Fifteen": {
        "id": "com.michirose.telegraphica.workshop.fifteen",
        "name": "Fifteen",
        "ru_name": "Пятнашки",
        "en_description": "A compact sliding puzzle with saved progress and no background timer.",
        "ru_description": "Компактная игра в пятнашки с сохранением прогресса и без фонового таймера.",
        "category": "games",
    },
    "TankPatrol": {
        "id": "com.michirose.telegraphica.workshop.tankpatrol",
        "name": "Tank Patrol",
        "ru_name": "Танковый патруль",
        "en_description": "An original lightweight top-down tank defense inspired by cartridge-era games.",
        "ru_description": "Оригинальная лёгкая танковая оборона с видом сверху в духе картриджных игр.",
        "category": "games",
    },
}


def run(*args: str, input_bytes: Optional[bytes] = None) -> bytes:
    result = subprocess.run(args, input=input_bytes, check=True, stdout=subprocess.PIPE)
    return result.stdout


def sign(private_key: pathlib.Path, domain: bytes, payload: bytes) -> str:
    signature = run("openssl", "dgst", "-sha256", "-sign", str(private_key),
                    input_bytes=domain + payload)
    return base64.b64encode(signature).decode("ascii")


def deterministic_zip(bundle: pathlib.Path, output: pathlib.Path, archive_bundle_name: str) -> None:
    files = sorted(path for path in bundle.rglob("*") if path.is_file())
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            relative = f"{archive_bundle_name}/{path.relative_to(bundle).as_posix()}"
            info = zipfile.ZipInfo(relative, date_time=(2026, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            mode = 0o755 if os.access(path, os.X_OK) else 0o644
            info.external_attr = mode << 16
            archive.writestr(info, path.read_bytes())


def unpacked_metrics(bundle: pathlib.Path) -> tuple[int, int]:
    files = [path for path in bundle.rglob("*") if path.is_file()]
    return sum(path.stat().st_size for path in files), len(files)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--products", required=True, type=pathlib.Path)
    parser.add_argument("--output", required=True, type=pathlib.Path)
    parser.add_argument("--private-key", required=True, type=pathlib.Path)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--catalog-version", type=int, default=1)
    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    entries = []
    for module_name, metadata in MODULES.items():
        bundle = args.products / f"{module_name}.bundle"
        if not bundle.is_dir():
            raise SystemExit(f"Missing built bundle: {bundle}")
        manifest_path = bundle / "Contents" / "Resources" / "WorkshopModule.plist"
        if not manifest_path.is_file():
            raise SystemExit(f"Missing Workshop manifest: {manifest_path}")
        with manifest_path.open("rb") as manifest_file:
            manifest = plistlib.load(manifest_file)
        module_identifier = str(manifest.get("identifier", "")).strip()
        module_version = str(manifest.get("version", "")).strip()
        if module_identifier != metadata["id"] or not module_version:
            raise SystemExit(f"Invalid Workshop manifest identity: {manifest_path}")

        package_name = f"{module_identifier}-{module_version}.zip"
        package_path = args.output / package_name
        deterministic_zip(bundle, package_path, f"{module_identifier}.bundle")
        package_bytes = package_path.read_bytes()
        digest = hashlib.sha256(package_bytes).hexdigest()
        unpacked_size, entry_count = unpacked_metrics(bundle)
        signed_description = f"{module_identifier}\n{module_version}\n{digest}".encode("utf-8")
        package_signature = sign(args.private_key, PACKAGE_DOMAIN, signed_description)
        entries.append({
            "id": module_identifier,
            "name": metadata["name"],
            "localized_name": {"en": metadata["name"], "ru": metadata["ru_name"]},
            "description": {"en": metadata["en_description"], "ru": metadata["ru_description"]},
            "version": module_version,
            "api_version": 1,
            "minimum_app_version": "0.5.1",
            "minimum_os_version": "10.9",
            "architectures": ["x86_64"],
            "category": metadata["category"],
            "archive_size": len(package_bytes),
            "unpacked_size": unpacked_size,
            "entry_count": entry_count,
            "sha256": digest,
            "signature": {
                "key_id": "package-2026-01",
                "algorithm": "rsa-pkcs1-sha256",
                "value": package_signature,
            },
            "download_url": f"{args.base_url.rstrip('/')}/{package_name}",
            "icon_url": f"{args.base_url.rstrip('/')}/icons/{module_name.lower()}.png",
            "changelog": {
                "en": "Initial Workshop release.",
                "ru": "Первый выпуск модуля для Мастерской.",
            },
            "permissions": ["module-data", "host-notifications"],
        })

    now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    payload = {
        "catalog_version": args.catalog_version,
        "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "expires_at": (now + dt.timedelta(days=3650)).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "modules": entries,
    }
    payload_bytes = json.dumps(payload, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    envelope = {
        "schema_version": 1,
        "key_id": "catalog-2026-01",
        "algorithm": "rsa-pkcs1-sha256",
        "payload": base64.b64encode(payload_bytes).decode("ascii"),
        "catalog_signature": sign(args.private_key, CATALOG_DOMAIN, payload_bytes),
    }
    (args.output / "WorkshopCatalog.json").write_text(
        json.dumps(envelope, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Created {len(entries)} packages and WorkshopCatalog.json in {args.output}")


if __name__ == "__main__":
    main()

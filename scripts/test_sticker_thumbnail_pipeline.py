#!/usr/bin/env python
from __future__ import print_function

import os
import sys


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir))


def read_text(relative_path):
    path = os.path.join(ROOT, relative_path)
    with open(path, "rb") as handle:
        data = handle.read()
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return data.decode("latin-1")


def main():
    errors = []
    layout = read_text("Sources/UI/TGStickerPickerLayout.m")
    composer = read_text("Sources/UI/TGStatusWindowController+ComposerMedia.inc")
    controller = read_text("Sources/UI/TGStatusWindowController.m")

    if "initWithContentsOfFile:" in layout or "TGImageWithCorrectOrientationFromFile" in layout:
        errors.append("sticker picker layout still decodes sticker files synchronously")
    if "TGMediaCachedThumbnailFromFile(localPath, 192)" not in layout:
        errors.append("sticker picker layout does not use the bounded thumbnail cache")
    for fragment in (
            "stickerPickerGridThumbnailPrefetcher",
            "stickerPickerRailThumbnailPrefetcher",
            "maximumPixelSize:192",
            "generation != blockSelf.stickerPickerLoadGeneration"):
        if fragment not in composer and fragment not in controller:
            errors.append("missing asynchronous sticker thumbnail contract: %s" % fragment)
    if composer.count("cancelAll") < 4:
        errors.append("sticker thumbnail jobs are not cancelled on rebuild and close")

    if errors:
        print("Sticker thumbnail pipeline checks failed:")
        for error in errors:
            print(" - " + error)
        return 1
    print("Sticker thumbnail pipeline checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

# Third-Party Notices

## MiniZip from zlib 1.2.8

`Vendor/minizip` contains the `unzip` and `ioapi` portions of MiniZip from
zlib 1.2.8. MiniZip was originally written by Gilles Vollant, with Zip64
changes by Even Rouault and Mathias Svensson. The files retain their original
copyright and license notices.

zlib and MiniZip are provided "as-is", without express or implied warranty.
Permission is granted to use, modify, and redistribute the software for any
purpose, including commercial applications, provided that the origin is not
misrepresented, altered versions are marked, and the original notice is kept.

Source: https://github.com/madler/zlib/tree/v1.2.8/contrib/minizip

## libtgvoip 2.4.4

Telegraphica's optional audio-call transport build uses the archived
`telegramdesktop/libtgvoip` 2.4.4 source. The source is not vendored in this
repository; `scripts/build_libtgvoip_legacy.sh` accepts a local checkout and
applies the narrow OS X 10.8 compatibility patch kept under `Vendor/patches`.

libtgvoip is distributed under The Unlicense.

Source: https://github.com/telegramdesktop/libtgvoip/tree/2.4.4

# Sticker thumbnail pipeline

The sticker picker no longer opens or decodes full sticker files while its
AppKit button grid or sticker-set rail is being rebuilt.

- Button construction performs a cache-only lookup at a bounded 192 px size.
- Missing cached thumbnails are decoded on the shared background image loader.
- Grid and rail each use a bounded prefetcher, so one surface cannot starve the
  other and no unbounded operation list is created.
- Every completion checks the picker generation, button tag, and owning view
  before applying an image on the main thread.
- Rebuilding or closing the picker cancels outstanding jobs. Clearing the
  shared media cache also invalidates completed prefetch history.
- Tiny TDLib mini-thumbnails remain an immediate fallback while a local file
  thumbnail is being prepared.

The pipeline uses the existing bounded media image cache whose key includes
the canonical path, requested size, file identity, file size, and modification
date.

# rlottie in Telegraphica

Telegraphica vendors Samsung `rlottie` at commit
`f487eff2f8086b84ae1c7faa0418abec909e874b` to render Telegram TGS stickers
locally on OS X Mavericks.

The legacy build compiles a private static archive with C++14 language
features and no runtime downloads. Telegraphica rejects TGS image assets,
links a no-op image-loader stub, and uses only rlottie's C API through a
bounded background renderer in `TGTGSAnimationView`.

Upstream: https://github.com/Samsung/rlottie

License details are in `COPYING` and `licenses/`.

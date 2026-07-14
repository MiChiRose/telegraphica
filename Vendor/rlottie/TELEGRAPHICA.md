# rlottie in Telegraphica

Telegraphica vendors Samsung `rlottie` at commit
`f487eff2f8086b84ae1c7faa0418abec909e874b` to render Telegram TGS stickers
locally on OS X Mavericks.

The legacy build compiles a private static archive with C++14 language
features and no runtime downloads. Telegraphica rejects TGS image assets,
links a no-op image-loader stub, and uses only rlottie's C API through a
bounded background renderer in `TGTGSAnimationView`.

The vendored public header removes the empty-string default argument from
`Animation::loadFromData`. AppleClang 6.0 cannot bind that string literal to
the `const std::string &` parameter while parsing the declaration. Telegraphica
always supplies the resource path through rlottie's C API, so this compatibility
patch does not change runtime behavior.

The C API bridge also constructs `std::string` values explicitly for every
incoming C string (file path, JSON data, cache key, resource path, and property
key path). The Mavericks libc++ headers do not accept the newer bridge's
implicit `const char *` conversions at those C-to-C++ call sites.

The private renderer build uses C++11 and force-includes
`src/telegraphica/cxx11_compat.h`, which backports `make_unique` and
`enable_if_t`. Keeping the full renderer in C++11 mode makes the source-level
language requirement explicit and testable against the Xcode 6.2 generation.
The compatibility header also supplies a complete standard-library baseline
because the Mavericks libc++ headers expose fewer transitive includes than
current libc++. The public `rlottie.h` explicitly includes every standard type
it exposes, including `string`, `tuple`, and `function`.

Upstream: https://github.com/Samsung/rlottie

License details are in `COPYING` and `licenses/`.

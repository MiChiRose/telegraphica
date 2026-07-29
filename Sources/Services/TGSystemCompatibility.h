#import <AppKit/AppKit.h>

#ifndef TGSystemCompatibility_h
#define TGSystemCompatibility_h

/*
 * Mavericks reports AppKit 1265.x. A single 10.8 deployment-target binary can
 * therefore select Mountain Lion fallbacks at runtime without relying on the
 * bundle's minimum-system-version declaration.
 */
static inline BOOL TGSystemIsMountainLion(void) {
    return NSAppKitVersionNumber < 1265.0;
}

/*
 * The modern Telegram WebRTC transport is compiled as an optional 10.9+
 * module and loaded only after this runtime check.  The host executable keeps
 * its shared 10.8 deployment target and never asks Mountain Lion's loader to
 * resolve symbols from the newer module.
 */
static inline BOOL TGSystemSupportsModernTelegramAudioCalls(void) {
    return NSAppKitVersionNumber >= 1265.0;
}

#endif

#import <Cocoa/Cocoa.h>

extern NSString * const TGComposerLinkRangeKey;
extern NSString * const TGComposerLinkLabelRangeKey;
extern NSString * const TGComposerLinkLabelKey;
extern NSString * const TGComposerLinkURLKey;

NSDictionary *TGComposerLinkInfoForTextSelection(NSString *text, NSRange selection);
NSString *TGComposerMarkdownLinkString(NSString *label, NSString *URLString);
NSString *TGComposerPlainTextFromMarkdownLabel(NSString *label);
NSString *TGComposerPromptForLinkURL(NSString *selectedText, NSString *currentURL);

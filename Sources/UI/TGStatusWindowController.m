#import "TGStatusWindowController.h"
#import "TGActiveSessionsPresentation.h"
#import "TGChatDisplayPreferences.h"
#import "TGLocalization.h"
#import "TGMessageActionDialogs.h"
#import "TGMessageLayoutSupport.h"
#import "TGMessageViewersWindowController.h"
#import "TGAnimationSupport.h"
#import "TGIconAssets.h"
#import "TGProfilePresentation.h"
#import "TGStatusButtonCells.h"
#import "TGSectionTitleField.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGStatusSupport.h"
#import "TGStickerPickerLayout.h"
#import "TGStatusWindowStyling.h"
#import "TGStorageUsageWindowController.h"
#import "TGTheme.h"
#import "TGTypingIndicatorPresentation.h"
#import "TGUpdateSupport.h"
#import "TGTransparentSpinnerView.h"
#import "../Media/TGInlineMediaPlaybackCoordinator.h"
#import "../Media/TGAttachmentDescriptor.h"
#import "../Media/TGFileTransferState.h"
#import "../Media/TGMediaImageLoader.h"
#import "../Media/TGMediaItemSupport.h"
#import "../Media/TGOpusVoiceTranscoder.h"
#import "../Core/TGChatItem.h"
#import "../Core/TGMessageItem.h"
#import "../Core/TGMessagePollSupport.h"
#import "../Core/TGOutgoingMessageTextChunker.h"
#import "../Core/TGSearchResultItem.h"
#import "../Core/TGTDLibClient.h"
#import "../Services/TGLocalDataReset.h"
#import "../Services/TGLogger.h"
#import "../Services/TGResourcePolicy.h"
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#include <math.h>

static NSUInteger const TGStatusChatPreviewInitialLimit = 40;
static NSUInteger const TGStatusChatPreviewStep = 40;
static NSUInteger const TGStatusChatPreviewMaximumLimit = 500;
static NSUInteger const TGMessagePreviewInitialLimit = 20;
static NSUInteger const TGMessagePrefillMinimumRows = 20;
static NSUInteger const TGMessagePrefillMaxAttempts = 3;
static CGFloat const TGPanelHeaderHeight = 40.0;
static NSString * const TGSectionChats = @"chats";
static NSString * const TGSectionProfile = @"profile";
static NSString * const TGSectionSettings = @"settings";
static NSString * const TGSectionAbout = @"about";
static NSString * const TGSectionLogs = @"logs";

static NSString * const TGNotificationsEnabledDefaultsKey = @"TelegraphicaNotificationsEnabled";
static NSString * const TGNotificationSoundEnabledDefaultsKey = @"TelegraphicaNotificationSoundEnabled";
static NSString * const TGNotificationBadgeEnabledDefaultsKey = @"TelegraphicaNotificationBadgeEnabled";
static NSString * const TGNotificationPreviewEnabledDefaultsKey = @"TelegraphicaNotificationPreviewEnabled";
static NSString * const TGNotificationsWhenActiveDefaultsKey = @"TelegraphicaNotificationsWhenActive";
static NSString * const TGChatNotificationMuteOverridesDefaultsKey = @"TelegraphicaChatNotificationMuteOverrides";
static NSString * const TGDrawerHiddenDefaultsKey = @"TelegraphicaDrawerHidden";
static NSString * const TGTypingIndicatorsEnabledDefaultsKey = @"TelegraphicaTypingIndicatorsEnabled";
static NSString * const TGLastUpdateCheckDefaultsKey = @"TelegraphicaLastUpdateCheckTime";
static NSString * const TGAvailableUpdateVersionDefaultsKey = @"TelegraphicaAvailableUpdateVersion";
static NSString * const TGMicrophoneConsentDefaultsKey = @"TelegraphicaMicrophoneConsent";
static NSString * const TGProjectURLString = @"https://github.com/MiChiRose/telegraphica";
static NSString * const TGAuthorURLString = @"https://www.instagram.com/yuramenschikov/";
static NSString * const TGChannelURLString = @"https://t.me/macos_telegraphica";

@interface TGPointingHandButton : NSButton
@end

@implementation TGPointingHandButton

- (void)resetCursorRects {
    [super resetCursorRects];
    if ([self isEnabled] && ![self isHidden]) {
        [self addCursorRect:[self bounds] cursor:[NSCursor pointingHandCursor]];
    }
}

@end

@interface TGHeaderActionButton : TGPointingHandButton
@end

@implementation TGHeaderActionButton

- (void)mouseDown:(NSEvent *)event {
    if (![self isEnabled] || [self isHidden]) {
        [super mouseDown:event];
        return;
    }
    if (![self target] || ![self action] || ![[self target] respondsToSelector:[self action]]) {
        [super mouseDown:event];
        return;
    }
    [[self cell] setHighlighted:YES];
    [self setNeedsDisplay:YES];
    [[self target] performSelector:[self action] withObject:self];
    [[self cell] setHighlighted:NO];
    [self setNeedsDisplay:YES];
}

@end

@interface TGReplyCancelButton : TGPointingHandButton
@end

@implementation TGReplyCancelButton

- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSRect bounds = [self bounds];
    BOOL highlighted = [[self cell] isHighlighted];

    NSRect buttonRect = NSInsetRect(bounds, 1.0, 1.0);
    NSBezierPath *buttonPath = [NSBezierPath bezierPathWithRoundedRect:buttonRect xRadius:7.0 yRadius:7.0];
    TGThemeDrawEnamelButtonInPath(buttonPath, buttonRect, highlighted, YES, YES, [self isFlipped]);
    [TGClassicPanelStrokeColor() set];
    [buttonPath setLineWidth:1.0];
    [buttonPath stroke];

    NSColor *iconColor = TGClassicHeaderTextColor(1.0);
    NSRect iconRect = NSMakeRect(NSMidX(buttonRect) - 8.5,
                                 NSMidY(buttonRect) - 8.5,
                                 17.0,
                                 17.0);
    if (!NSIsEmptyRect(iconRect)) {
        TGDrawTemplateIconAsset(@"cross", iconRect, iconColor, 1.0, [self isFlipped]);
    }

    [iconColor set];
    NSBezierPath *crossPath = [NSBezierPath bezierPath];
    [crossPath setLineWidth:1.8];
    [crossPath setLineCapStyle:NSRoundLineCapStyle];
    [crossPath moveToPoint:NSMakePoint(NSMinX(iconRect) + 1.0, NSMinY(iconRect) + 1.0)];
    [crossPath lineToPoint:NSMakePoint(NSMaxX(iconRect) - 1.0, NSMaxY(iconRect) - 1.0)];
    [crossPath moveToPoint:NSMakePoint(NSMinX(iconRect) + 1.0, NSMaxY(iconRect) - 1.0)];
    [crossPath lineToPoint:NSMakePoint(NSMaxX(iconRect) - 1.0, NSMinY(iconRect) + 1.0)];
    [crossPath stroke];
}

@end

@interface TGStatusWindowController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, NSMenuDelegate, NSUserNotificationCenterDelegate, TGMediaPreviewMagnificationTarget>
@property (nonatomic, retain) NSView *topPanelView;
@property (nonatomic, retain) NSView *sidebarPanelView;
@property (nonatomic, retain) NSView *conversationPanelView;
@property (nonatomic, retain) NSView *diagnosticsPanelView;
@property (nonatomic, retain) NSView *loginPanelView;
@property (nonatomic, retain) NSView *profilePanelView;
@property (nonatomic, retain) NSScrollView *profileScrollView;
@property (nonatomic, retain) NSView *profileContentView;
@property (nonatomic, retain) NSView *settingsPanelView;
@property (nonatomic, retain) NSScrollView *settingsScrollView;
@property (nonatomic, retain) NSView *settingsContentView;
@property (nonatomic, retain) NSView *aboutPanelView;
@property (nonatomic, retain) TGGroupedCardView *bottomNavigationView;
@property (nonatomic, retain) NSArray *navigationButtons;
@property (nonatomic, retain) NSProgressIndicator *markAllChatsReadSpinner;
@property (nonatomic, retain) NSArray *drawerFolderButtons;
@property (nonatomic, retain) NSArray *chatFilterInfos;
@property (nonatomic, retain) TGAccountBadgeView *accountBadgeView;
@property (nonatomic, retain) NSButton *drawerButton;
@property (nonatomic, retain) TGGroupedCardView *profileSummaryCardView;
@property (nonatomic, retain) TGGroupedCardView *profileInfoCardView;
@property (nonatomic, retain) TGGroupedCardView *profileDetailsCardView;
@property (nonatomic, retain) TGGroupedCardView *profileActionsCardView;
@property (nonatomic, retain) TGProfileAvatarView *profileAvatarView;
@property (nonatomic, retain) TGGroupedCardView *settingsAccountCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsThemeCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsSessionCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsDrawerCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsResourceCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsFilesCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsHelpCardView;
@property (nonatomic, retain) TGStorageUsageWindowController *storageUsageWindowController;
@property (nonatomic, retain) TGGroupedCardView *aboutCardView;
@property (nonatomic, retain) TGGroupedCardView *logsCardView;
@property (nonatomic, retain) NSTextField *diagnosticsLabel;
@property (nonatomic, retain) NSTextField *titleField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSScrollView *detailsScrollView;
@property (nonatomic, retain) NSTextView *detailsView;
@property (nonatomic, retain) NSButton *checkButton;
@property (nonatomic, retain) NSButton *loadChatsButton;
@property (nonatomic, retain) NSButton *loadMoreChatsButton;
@property (nonatomic, retain) NSButton *topicBackButton;
@property (nonatomic, retain) NSButton *commentThreadBackButton;
@property (nonatomic, retain) NSButton *loadMessagesButton;
@property (nonatomic, retain) NSButton *loadOlderMessagesButton;
@property (nonatomic, retain) NSButton *chatSearchButton;
@property (nonatomic, retain) NSButton *conversationSearchButton;
@property (nonatomic, retain) NSButton *mediaCenterButton;
@property (nonatomic, retain) TGGroupedCardView *searchPanelView;
@property (nonatomic, retain) NSTextField *searchTextField;
@property (nonatomic, retain) NSPopUpButton *searchScopePopUpButton;
@property (nonatomic, retain) NSPopUpButton *searchFilterPopUpButton;
@property (nonatomic, retain) NSButton *searchCloseButton;
@property (nonatomic, retain) NSTextField *searchStatusField;
@property (nonatomic, retain) NSScrollView *searchResultsScrollView;
@property (nonatomic, retain) NSTableView *searchResultsTableView;
@property (nonatomic, retain) NSMutableArray *searchResultItems;
@property (nonatomic, retain) NSTimer *searchDebounceTimer;
@property (nonatomic, copy) NSString *globalSearchOffset;
@property (nonatomic, assign) BOOL searchPanelVisible;
@property (nonatomic, assign) BOOL searchLoading;
@property (nonatomic, assign) BOOL searchEndReached;
@property (nonatomic, assign) BOOL chatTitleSearchOnly;
@property (nonatomic, assign) BOOL searchInlineCurrentChatOnly;
@property (nonatomic, assign) NSUInteger searchGeneration;
@property (nonatomic, retain) NSWindow *chatSearchWindow;
@property (nonatomic, retain) NSTextField *chatSearchWindowTextField;
@property (nonatomic, retain) NSScrollView *chatSearchWindowScrollView;
@property (nonatomic, retain) NSView *chatSearchWindowResultsView;
@property (nonatomic, retain) NSTextField *chatSearchWindowStatusField;
@property (nonatomic, retain) NSMutableArray *chatSearchWindowResults;
@property (nonatomic, retain) NSMutableArray *chatSearchWindowResultButtons;
@property (nonatomic, assign) NSUInteger chatSearchGeneration;
@property (nonatomic, retain) NSWindow *mediaCenterWindow;
@property (nonatomic, retain) TGGroupedCardView *mediaCenterContentCardView;
@property (nonatomic, retain) NSSearchField *mediaCenterSearchField;
@property (nonatomic, retain) NSArray *mediaCenterTabButtons;
@property (nonatomic, assign) NSInteger mediaCenterSelectedTabIndex;
@property (nonatomic, retain) NSPopUpButton *mediaCenterFilterPopUpButton;
@property (nonatomic, retain) NSPopUpButton *mediaCenterSortPopUpButton;
@property (nonatomic, retain) NSTextField *mediaCenterStatusField;
@property (nonatomic, retain) NSScrollView *mediaCenterScrollView;
@property (nonatomic, retain) NSView *mediaCenterResultsView;
@property (nonatomic, retain) NSButton *mediaCenterRefreshButton;
@property (nonatomic, retain) NSProgressIndicator *mediaCenterLoadingSpinner;
@property (nonatomic, assign) BOOL mediaCenterLoading;
@property (nonatomic, retain) NSView *mediaCenterPreviewOverlayView;
@property (nonatomic, retain) NSImageView *mediaCenterPreviewImageView;
@property (nonatomic, retain) NSTextField *mediaCenterPreviewTitleField;
@property (nonatomic, retain) NSButton *mediaCenterPreviewCloseButton;
@property (nonatomic, retain) NSMutableArray *mediaCenterItems;
@property (nonatomic, retain) NSMutableDictionary *mediaCenterPaginationAnchorsByFilter;
@property (nonatomic, retain) NSMutableSet *mediaCenterExhaustedFilterIdentifiers;
@property (nonatomic, retain) NSMutableSet *mediaCenterSeenKeys;
@property (nonatomic, assign) NSUInteger mediaCenterGeneration;
@property (nonatomic, assign) BOOL mediaCenterLoadingMore;
@property (nonatomic, assign) BOOL mediaCenterExhausted;
@property (nonatomic, retain) TGGroupedCardView *pinnedMessagePanelView;
@property (nonatomic, retain) NSTextField *pinnedMessageStripeField;
@property (nonatomic, retain) NSTextField *pinnedMessageLabelField;
@property (nonatomic, retain) NSTextField *pinnedMessageTextField;
@property (nonatomic, retain) NSButton *pinnedMessageButton;
@property (nonatomic, retain) NSArray *pinnedMessageItems;
@property (nonatomic, retain) TGMessageItem *pinnedMessageItem;
@property (nonatomic, assign) NSUInteger pinnedMessageCarouselIndex;
@property (nonatomic, assign) NSUInteger pinnedMessageGeneration;
@property (nonatomic, retain) TGGroupedCardView *replyPanelView;
@property (nonatomic, retain) NSTextField *replyPanelTitleField;
@property (nonatomic, retain) NSTextField *replyPanelTextField;
@property (nonatomic, retain) NSButton *replyPanelCancelButton;
@property (nonatomic, retain) TGMessageItem *replyTargetMessageItem;
@property (nonatomic, retain) NSNumber *replyTargetChatID;
@property (nonatomic, retain) NSNumber *replyTargetThreadID;
@property (nonatomic, copy) NSString *replyTargetTopicKind;
@property (nonatomic, retain) NSNumber *highlightedSearchMessageID;
@property (nonatomic, retain) NSTimer *searchHighlightTimer;
@property (nonatomic, retain) NSTextField *sendLabel;
@property (nonatomic, retain) NSView *sendTextFieldBackgroundView;
@property (nonatomic, retain) NSTextField *sendTextField;
@property (nonatomic, retain) NSButton *attachPhotoButton;
@property (nonatomic, retain) NSButton *stickerButton;
@property (nonatomic, retain) NSButton *voiceRecordButton;
@property (nonatomic, retain) NSButton *sendMessageButton;
@property (nonatomic, retain) NSTextField *authLabel;
@property (nonatomic, retain) NSTextField *authStateField;
@property (nonatomic, retain) NSImageView *loginIconView;
@property (nonatomic, retain) NSTextField *loginBrandField;
@property (nonatomic, retain) NSTextField *loginTitleField;
@property (nonatomic, retain) NSTextField *loginHintField;
@property (nonatomic, retain) NSView *authTextFieldBackgroundView;
@property (nonatomic, retain) NSTextField *authTextField;
@property (nonatomic, retain) NSSecureTextField *authSecureField;
@property (nonatomic, retain) NSTextField *authSecondaryLabel;
@property (nonatomic, retain) NSView *authSecondaryTextFieldBackgroundView;
@property (nonatomic, retain) NSButton *authButton;
@property (nonatomic, retain) TGTransparentSpinnerView *busySpinner;
@property (nonatomic, retain) NSButton *loginLogsButton;
@property (nonatomic, retain) NSArray *loginLanguageButtons;
@property (nonatomic, retain) NSTextField *chatsLabel;
@property (nonatomic, retain) NSTextField *messagesLabel;
@property (nonatomic, retain) NSTextField *selectedChatField;
@property (nonatomic, retain) NSTextField *typingIndicatorField;
@property (nonatomic, retain) TGProfileAvatarView *selectedChatAvatarView;
@property (nonatomic, retain) NSButton *selectedChatProfileButton;
@property (nonatomic, retain) TGGroupedCardView *closedChatPlaceholderView;
@property (nonatomic, retain) NSTextField *closedChatTitleField;
@property (nonatomic, retain) NSTextField *closedChatHintField;
@property (nonatomic, retain) NSArray *closedChatSuggestionViews;
@property (nonatomic, retain) NSArray *closedChatSuggestionItems;
@property (nonatomic, retain) NSView *chatScrollSurfaceView;
@property (nonatomic, retain) NSScrollView *chatScrollView;
@property (nonatomic, retain) NSTableView *chatTableView;
@property (nonatomic, retain) NSMutableArray *chatItems;
@property (nonatomic, retain) NSArray *chatItemsBeforeTopicList;
@property (nonatomic, retain) NSView *messageScrollSurfaceView;
@property (nonatomic, retain) NSScrollView *messageScrollView;
@property (nonatomic, retain) NSTableView *messageTableView;
@property (nonatomic, retain) TGTransparentSpinnerView *messageLoadingSpinner;
@property (nonatomic, retain) NSButton *messageJumpToNewestButton;
@property (nonatomic, retain) TGInlineMediaPlaybackCoordinator *inlineMediaPlaybackCoordinator;
@property (nonatomic, retain) NSMutableSet *inlineMediaPlaybackDiagnosticKeys;
@property (nonatomic, retain) TGDropOverlayView *messageDropOverlayView;
@property (nonatomic, retain) NSMutableArray *messageItems;
@property (nonatomic, retain) NSMutableDictionary *composerDraftsByTargetKey;
@property (nonatomic, retain) NSTimer *composerDraftSyncTimer;
@property (nonatomic, assign) NSUInteger composerDraftSyncGeneration;
@property (nonatomic, retain) NSNumber *composerDraftSyncChatID;
@property (nonatomic, retain) NSNumber *composerDraftSyncThreadID;
@property (nonatomic, copy) NSString *composerDraftSyncTopicKind;
@property (nonatomic, copy) NSString *composerDraftSyncText;
@property (nonatomic, retain) NSNumber *composerDraftSyncReplyMessageID;
@property (nonatomic, retain) NSTextField *profileTitleField;
@property (nonatomic, retain) NSTextField *profileNameField;
@property (nonatomic, retain) NSTextField *profileUsernameField;
@property (nonatomic, retain) NSTextField *profileIDField;
@property (nonatomic, retain) NSTextField *profileStateField;
@property (nonatomic, retain) NSTextField *profileAboutSectionField;
@property (nonatomic, retain) NSTextField *profileAccountSectionField;
@property (nonatomic, retain) NSTextField *profileUsernameRowTitleField;
@property (nonatomic, retain) NSTextField *profileUsernameRowValueField;
@property (nonatomic, retain) NSTextField *profilePhoneRowTitleField;
@property (nonatomic, retain) NSTextField *profilePhoneRowValueField;
@property (nonatomic, retain) NSTextField *profileIDRowTitleField;
@property (nonatomic, retain) NSTextField *profileIDRowValueField;
@property (nonatomic, retain) NSBox *profileDetailsSeparatorOne;
@property (nonatomic, retain) NSBox *profileDetailsSeparatorTwo;
@property (nonatomic, retain) NSTextField *settingsTitleField;
@property (nonatomic, retain) NSTextField *settingsStateField;
@property (nonatomic, retain) NSTextField *settingsLibraryField;
@property (nonatomic, retain) NSTextField *settingsStorageField;
@property (nonatomic, retain) NSTextField *settingsDrawerSectionField;
@property (nonatomic, retain) NSTextField *settingsResourceSectionField;
@property (nonatomic, retain) NSTextField *settingsFilesSectionField;
@property (nonatomic, retain) NSTextField *settingsHelpSectionField;
@property (nonatomic, retain) NSTextField *settingsThemeLabel;
@property (nonatomic, retain) NSTextField *settingsThemeCategoryLabel;
@property (nonatomic, retain) NSPopUpButton *themeCategoryPopUpButton;
@property (nonatomic, retain) NSPopUpButton *themePopUpButton;
@property (nonatomic, retain) NSButton *settingsNotificationsEnabledButton;
@property (nonatomic, retain) NSButton *settingsNotificationSoundButton;
@property (nonatomic, retain) NSButton *settingsNotificationBadgeButton;
@property (nonatomic, retain) NSButton *settingsNotificationPreviewButton;
@property (nonatomic, retain) NSButton *settingsNotificationsWhenActiveButton;
@property (nonatomic, retain) NSButton *settingsDrawerHiddenButton;
@property (nonatomic, retain) NSButton *settingsTypingIndicatorsButton;
@property (nonatomic, retain) NSButton *settingsEconomyModeButton;
@property (nonatomic, retain) NSButton *settingsAutoDownloadPhotosButton;
@property (nonatomic, retain) NSButton *settingsAutoDownloadVideosButton;
@property (nonatomic, retain) NSButton *settingsAutoDownloadDocumentsButton;
@property (nonatomic, retain) NSButton *settingsAutoplayAnimatedStickersButton;
@property (nonatomic, retain) NSButton *settingsStopInactiveAnimationsButton;
@property (nonatomic, retain) NSTextField *settingsMaxAutoDownloadLabel;
@property (nonatomic, retain) NSPopUpButton *settingsMaxAutoDownloadPopUpButton;
@property (nonatomic, retain) NSTextField *settingsMaxAnimationsLabel;
@property (nonatomic, retain) NSPopUpButton *settingsMaxAnimationsPopUpButton;
@property (nonatomic, retain) NSTextField *settingsMediaCacheLimitLabel;
@property (nonatomic, retain) NSPopUpButton *settingsMediaCacheLimitPopUpButton;
@property (nonatomic, retain) NSTextField *settingsResourceHintField;
@property (nonatomic, retain) NSButton *settingsActiveSessionsButton;
@property (nonatomic, retain) NSTextField *settingsActiveSessionsDetailField;
@property (nonatomic, retain) NSTextField *settingsLanguageLabel;
@property (nonatomic, retain) NSPopUpButton *settingsLanguagePopUpButton;
@property (nonatomic, retain) NSButton *settingsMessagesAsBlocksButton;
@property (nonatomic, retain) NSTextField *settingsChatTextSizeSectionField;
@property (nonatomic, retain) NSSlider *settingsChatTextSizeSlider;
@property (nonatomic, retain) NSTextField *settingsChatTextSizeValueField;
@property (nonatomic, retain) NSTextField *settingsDownloadFolderHelpField;
@property (nonatomic, retain) NSButton *settingsDownloadFolderButton;
@property (nonatomic, retain) NSButton *settingsStorageUsageButton;
@property (nonatomic, retain) NSButton *settingsDeleteLocalDataButton;
@property (nonatomic, retain) NSButton *settingsCheckUpdatesButton;
@property (nonatomic, retain) TGNotificationDotView *settingsUpdateDotView;
@property (nonatomic, retain) NSButton *settingsAppearanceButton;
@property (nonatomic, retain) NSButton *settingsLogsButton;
@property (nonatomic, retain) NSButton *settingsAboutButton;
@property (nonatomic, retain) NSButton *logoutButton;
@property (nonatomic, retain) NSButton *profileRefreshButton;
@property (nonatomic, retain) NSImageView *aboutIconView;
@property (nonatomic, retain) NSTextField *aboutTitleField;
@property (nonatomic, retain) NSTextField *aboutVersionField;
@property (nonatomic, retain) NSTextField *aboutCopyrightField;
@property (nonatomic, retain) NSTextField *aboutLinkField;
@property (nonatomic, retain) NSNumber *selectedChatID;
@property (nonatomic, copy) NSString *selectedChatTitle;
@property (nonatomic, copy) NSString *selectedChatTypeSummary;
@property (nonatomic, copy) NSString *selectedChatAvatarLocalPath;
@property (nonatomic, retain) NSNumber *selectedChatLastReadOutboxMessageID;
@property (nonatomic, retain) NSNumber *selectedMessageThreadID;
@property (nonatomic, copy) NSString *selectedMessageTopicKind;
@property (nonatomic, copy) NSString *commentThreadParentTitle;
@property (nonatomic, copy) NSString *commentThreadParentTypeSummary;
@property (nonatomic, copy) NSString *commentThreadParentAvatarLocalPath;
@property (nonatomic, retain) NSNumber *topicParentChatID;
@property (nonatomic, copy) NSString *topicParentTitle;
@property (nonatomic, copy) NSString *topicParentAvatarLocalPath;
@property (nonatomic, retain) NSNumber *selectedChatFilterID;
@property (nonatomic, copy) NSString *profileDisplayName;
@property (nonatomic, copy) NSString *profileFirstName;
@property (nonatomic, copy) NSString *profileLastName;
@property (nonatomic, copy) NSString *profileUsername;
@property (nonatomic, copy) NSString *profilePhoneNumber;
@property (nonatomic, retain) NSNumber *profileUserID;
@property (nonatomic, copy) NSString *profileAvatarLocalPath;
@property (nonatomic, copy) NSString *profileBio;
@property (nonatomic, copy) NSString *lastLogSection;
@property (nonatomic, retain) NSWindow *logsWindow;
@property (nonatomic, retain) NSWindow *aboutWindow;
@property (nonatomic, retain) NSWindow *appearanceWindow;
@property (nonatomic, retain) NSWindow *activeSessionsWindow;
@property (nonatomic, retain) NSTextView *activeSessionsTextView;
@property (nonatomic, retain) NSTableView *activeSessionsTableView;
@property (nonatomic, retain) NSArray *activeSessionsSelectableSessions;
@property (nonatomic, retain) NSTextField *activeSessionsStatusField;
@property (nonatomic, retain) NSButton *activeSessionsRefreshButton;
@property (nonatomic, retain) NSPopUpButton *activeSessionsTerminatePopup;
@property (nonatomic, retain) NSButton *activeSessionsTerminateButton;
@property (nonatomic, retain) NSButton *activeSessionsCloseButton;
@property (nonatomic, retain) NSDictionary *activeSessionsSummary;
@property (nonatomic, assign) NSUInteger activeSessionsRequestGeneration;
@property (nonatomic, retain) NSWindow *mediaPreviewWindow;
@property (nonatomic, retain) NSScrollView *mediaPreviewScrollView;
@property (nonatomic, retain) NSImageView *mediaPreviewImageView;
@property (nonatomic, retain) NSButton *mediaPreviewZoomOutButton;
@property (nonatomic, retain) NSButton *mediaPreviewFitButton;
@property (nonatomic, retain) NSButton *mediaPreviewZoomInButton;
@property (nonatomic, retain) NSWindow *mediaPlaybackWindow;
@property (nonatomic, retain) NSView *mediaPlaybackContainerView;
@property (nonatomic, retain) NSTextField *mediaPlaybackTitleField;
@property (nonatomic, retain) NSButton *mediaPlaybackPlayPauseButton;
@property (nonatomic, retain) NSSlider *mediaPlaybackProgressSlider;
@property (nonatomic, retain) NSTextField *mediaPlaybackTimeField;
@property (nonatomic, retain) NSButton *mediaPlaybackCloseButton;
@property (nonatomic, retain) AVPlayer *mediaPlaybackPlayer;
@property (nonatomic, retain) AVPlayerLayer *mediaPlaybackLayer;
@property (nonatomic, retain) NSTimer *mediaPlaybackTimer;
@property (nonatomic, retain) TGMessageViewersWindowController *messageViewersWindowController;
@property (nonatomic, retain) NSWindow *photoSendPreviewWindow;
@property (nonatomic, retain) NSImageView *photoSendPreviewImageView;
@property (nonatomic, retain) NSView *photoSendCaptionBackgroundView;
@property (nonatomic, retain) NSTextField *photoSendCaptionField;
@property (nonatomic, retain) NSTextField *photoSendTitleField;
@property (nonatomic, retain) NSTextField *photoSendErrorField;
@property (nonatomic, retain) NSTextField *photoSendMetaField;
@property (nonatomic, retain) NSButton *photoSendSendButton;
@property (nonatomic, retain) NSScrollView *photoSendQueueScrollView;
@property (nonatomic, retain) NSView *photoSendQueueContentView;
@property (nonatomic, copy) NSString *pendingPhotoSendPath;
@property (nonatomic, retain) TGAttachmentDescriptor *pendingAttachmentDescriptor;
@property (nonatomic, retain) NSArray *pendingAttachmentDescriptors;
@property (nonatomic, retain) TGFileTransferState *pendingAttachmentTransferState;
@property (nonatomic, retain) NSArray *pendingAttachmentQueueItems;
@property (nonatomic, assign) BOOL pendingAttachmentCancelRequested;
@property (nonatomic, retain) NSNumber *pendingPhotoSendChatID;
@property (nonatomic, retain) NSNumber *pendingPhotoSendThreadID;
@property (nonatomic, copy) NSString *pendingPhotoSendTopicKind;
@property (nonatomic, retain) NSWindow *stickerPickerWindow;
@property (nonatomic, retain) NSScrollView *stickerPickerScrollView;
@property (nonatomic, retain) NSView *stickerPickerContentView;
@property (nonatomic, retain) NSButton *stickerPickerRecentButton;
@property (nonatomic, retain) NSButton *stickerPickerFavoriteButton;
@property (nonatomic, retain) NSSearchField *stickerPickerSearchField;
@property (nonatomic, retain) NSScrollView *stickerPickerSetScrollView;
@property (nonatomic, retain) NSView *stickerPickerSetContentView;
@property (nonatomic, copy) NSArray *stickerPickerItems;
@property (nonatomic, copy) NSArray *stickerPickerStickerSets;
@property (nonatomic, retain) NSMutableDictionary *stickerPickerSetCache;
@property (nonatomic, retain) NSMutableDictionary *stickerPickerRailPreviewState;
@property (nonatomic, retain) NSNumber *stickerPickerSelectedSetID;
@property (nonatomic, retain) NSTextField *stickerPickerStatusField;
@property (nonatomic, retain) TGInlineMediaPlaybackCoordinator *stickerPickerPlaybackCoordinator;
@property (nonatomic, assign) NSUInteger stickerPickerLoadGeneration;
@property (nonatomic, retain) AVAudioRecorder *voiceRecorder;
@property (nonatomic, retain) AVAudioPlayer *voicePreviewPlayer;
@property (nonatomic, copy) NSString *voiceRecordingPath;
@property (nonatomic, retain) NSDate *voiceRecordingStartDate;
@property (nonatomic, retain) NSWindow *voicePreviewWindow;
@property (nonatomic, retain) NSTextField *voicePreviewTitleField;
@property (nonatomic, retain) NSButton *voicePreviewPlayButton;
@property (nonatomic, retain) NSButton *voicePreviewStopButton;
@property (nonatomic, retain) NSSlider *voicePreviewProgressSlider;
@property (nonatomic, retain) NSTextField *voicePreviewTimeField;
@property (nonatomic, retain) NSButton *voicePreviewCancelButton;
@property (nonatomic, retain) NSButton *voicePreviewSendButton;
@property (nonatomic, retain) NSTextField *voicePreviewErrorField;
@property (nonatomic, retain) NSTimer *voicePreviewTimer;
@property (nonatomic, retain) NSTextField *voiceRecordingIndicatorField;
@property (nonatomic, retain) NSMenu *messageContextMenu;
@property (nonatomic, retain) NSMenu *chatContextMenu;
@property (nonatomic, retain) NSMenu *chatsNavigationContextMenu;
@property (nonatomic, copy) NSString *mediaPreviewPath;
@property (nonatomic, assign) NSUInteger mediaPreviewRequestGeneration;
@property (nonatomic, retain) NSTextView *logsWindowDetailsView;
@property (nonatomic, retain) NSButton *logsCheckButton;
@property (nonatomic, retain) NSPopUpButton *appearanceThemePopUpButton;
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, copy) NSString *currentAuthState;
@property (nonatomic, copy) NSString *activeSection;
@property (nonatomic, retain) NSTimer *liveUpdateTimer;
@property (nonatomic, assign) BOOL controlsBusy;
@property (nonatomic, assign) BOOL authSubmissionInFlight;
@property (nonatomic, assign) BOOL authClientRecoveryInFlight;
@property (nonatomic, assign) NSUInteger authClientRecoveryAttemptCount;
@property (nonatomic, assign) NSUInteger accountUnreadCount;
@property (nonatomic, assign) BOOL hasAccountUnreadCount;
@property (nonatomic, assign) BOOL backgroundChatRefreshInFlight;
@property (nonatomic, assign) BOOL backgroundMessageRefreshInFlight;
@property (nonatomic, assign) BOOL messageLoadingIndicatorVisible;
@property (nonatomic, assign) NSUInteger messageLoadingGeneration;
@property (nonatomic, assign) BOOL pendingLiveChatRefresh;
@property (nonatomic, assign) BOOL pendingLiveMessageRefresh;
@property (nonatomic, assign) NSUInteger chatPreviewLimit;
@property (nonatomic, assign) BOOL chatsExhausted;
@property (nonatomic, assign) BOOL olderMessagesExhausted;
@property (nonatomic, assign) BOOL autoOlderMessagesLoadArmed;
@property (nonatomic, assign) BOOL autoChatListLoadArmed;
@property (nonatomic, assign) BOOL autoChatListRefreshArmed;
@property (nonatomic, assign) BOOL forceMessageScrollToNewest;
@property (nonatomic, assign) BOOL messageItemsRepresentFocusedContext;
@property (nonatomic, assign) BOOL initialConnectStarted;
@property (nonatomic, assign) BOOL profileSummaryLoaded;
@property (nonatomic, assign) BOOL profileSummaryLoading;
@property (nonatomic, assign) BOOL drawerOpen;
@property (nonatomic, assign) BOOL suppressComposerDraftSave;
@property (nonatomic, assign) BOOL loginErrorVisible;
@property (nonatomic, copy) NSString *loginErrorLocalizationKey;
@property (nonatomic, assign) BOOL composerRefocusPending;
@property (nonatomic, assign) BOOL messageDropOverlayVisible;
@property (nonatomic, assign) BOOL offlineModeActive;
@property (nonatomic, assign) BOOL updateAvailable;
@property (nonatomic, copy) NSString *availableUpdateVersion;
@property (nonatomic, assign) BOOL chatFilterRefreshInFlight;
@property (nonatomic, assign) BOOL chatFilterRefreshPending;
@property (nonatomic, assign) NSUInteger chatFilterRefreshRetryCount;
@property (nonatomic, assign) BOOL forumTopicRefreshInFlight;
@property (nonatomic, assign) BOOL suppressChatSelectionHandling;
@property (nonatomic, assign) BOOL showingForumTopicList;
@property (nonatomic, assign) BOOL chatNavigationClosed;
@property (nonatomic, retain) NSNumber *suppressedForumTopicAutoOpenChatID;
@property (nonatomic, assign) NSUInteger forumTopicNavigationGeneration;
@property (nonatomic, assign) CGFloat mediaPreviewZoomScale;
@property (nonatomic, assign) CGFloat mediaPreviewMinimumZoomScale;
@property (nonatomic, assign) BOOL mediaPlaybackPlaying;
@property (nonatomic, assign) BOOL mediaPlaybackAudioOnly;
@property (nonatomic, assign) NSTimeInterval mediaPlaybackKnownDuration;
@property (nonatomic, retain) NSNumber *typingChatID;
@property (nonatomic, copy) NSString *typingIndicatorText;
@property (nonatomic, retain) NSTimer *typingClearTimer;
@property (nonatomic, retain) NSNumber *pendingNotificationChatID;
@property (nonatomic, retain) NSNumber *pendingNotificationThreadID;
@property (nonatomic, retain) NSMutableDictionary *notificationChatInfoByChatID;
@property (nonatomic, retain) NSMutableDictionary *localMuteUnreadCountsByChatID;
- (NSArray *)messageIDsForMessageActionItem:(TGMessageItem *)item;
- (void)clearReplyTarget;
- (void)clearReplyTargetIfSelectionDiffersFromChatID:(NSNumber *)chatID
                                     messageThreadID:(NSNumber *)messageThreadID
                                    messageTopicKind:(NSString *)messageTopicKind;
- (void)replyToMessageFromMenu:(id)sender;
- (void)cancelReplyTarget:(id)sender;
- (void)forwardMessageFromMenu:(id)sender;
- (void)forwardMessageToSavedMessagesFromMenu:(id)sender;
- (void)submitPollAnswerForMessageItem:(TGMessageItem *)item optionIndexes:(NSArray *)optionIndexes;
- (void)togglePollOptionForMessageItem:(TGMessageItem *)item optionIndex:(NSUInteger)optionIndex;
- (void)updateSavedMessagesPresentationForChatItems;
- (void)setMarkAllChatsReadBusy:(BOOL)busy;
@end

#include "TGChatSearchPanelView.inc"

@implementation TGStatusWindowController

@synthesize topPanelView = _topPanelView;
@synthesize sidebarPanelView = _sidebarPanelView;
@synthesize conversationPanelView = _conversationPanelView;
@synthesize diagnosticsPanelView = _diagnosticsPanelView;
@synthesize loginPanelView = _loginPanelView;
@synthesize profilePanelView = _profilePanelView;
@synthesize profileScrollView = _profileScrollView;
@synthesize profileContentView = _profileContentView;
@synthesize settingsPanelView = _settingsPanelView;
@synthesize settingsScrollView = _settingsScrollView;
@synthesize settingsContentView = _settingsContentView;
@synthesize aboutPanelView = _aboutPanelView;
@synthesize bottomNavigationView = _bottomNavigationView;
@synthesize navigationButtons = _navigationButtons;
@synthesize markAllChatsReadSpinner = _markAllChatsReadSpinner;
@synthesize drawerFolderButtons = _drawerFolderButtons;
@synthesize chatFilterInfos = _chatFilterInfos;
@synthesize accountBadgeView = _accountBadgeView;
@synthesize drawerButton = _drawerButton;
@synthesize profileSummaryCardView = _profileSummaryCardView;
@synthesize profileInfoCardView = _profileInfoCardView;
@synthesize profileDetailsCardView = _profileDetailsCardView;
@synthesize profileActionsCardView = _profileActionsCardView;
@synthesize profileAvatarView = _profileAvatarView;
@synthesize settingsAccountCardView = _settingsAccountCardView;
@synthesize settingsThemeCardView = _settingsThemeCardView;
@synthesize settingsSessionCardView = _settingsSessionCardView;
@synthesize settingsDrawerCardView = _settingsDrawerCardView;
@synthesize settingsResourceCardView = _settingsResourceCardView;
@synthesize settingsFilesCardView = _settingsFilesCardView;
@synthesize settingsHelpCardView = _settingsHelpCardView;
@synthesize storageUsageWindowController = _storageUsageWindowController;
@synthesize aboutCardView = _aboutCardView;
@synthesize logsCardView = _logsCardView;
@synthesize diagnosticsLabel = _diagnosticsLabel;
@synthesize statusField = _statusField;
@synthesize titleField = _titleField;
@synthesize detailsScrollView = _detailsScrollView;
@synthesize detailsView = _detailsView;
@synthesize checkButton = _checkButton;
@synthesize loadChatsButton = _loadChatsButton;
@synthesize loadMoreChatsButton = _loadMoreChatsButton;
@synthesize topicBackButton = _topicBackButton;
@synthesize commentThreadBackButton = _commentThreadBackButton;
@synthesize loadMessagesButton = _loadMessagesButton;
@synthesize loadOlderMessagesButton = _loadOlderMessagesButton;
@synthesize chatSearchButton = _chatSearchButton;
@synthesize conversationSearchButton = _conversationSearchButton;
@synthesize mediaCenterButton = _mediaCenterButton;
@synthesize searchPanelView = _searchPanelView;
@synthesize searchTextField = _searchTextField;
@synthesize searchScopePopUpButton = _searchScopePopUpButton;
@synthesize searchFilterPopUpButton = _searchFilterPopUpButton;
@synthesize searchCloseButton = _searchCloseButton;
@synthesize searchStatusField = _searchStatusField;
@synthesize searchResultsScrollView = _searchResultsScrollView;
@synthesize searchResultsTableView = _searchResultsTableView;
@synthesize searchResultItems = _searchResultItems;
@synthesize searchDebounceTimer = _searchDebounceTimer;
@synthesize globalSearchOffset = _globalSearchOffset;
@synthesize searchPanelVisible = _searchPanelVisible;
@synthesize searchLoading = _searchLoading;
@synthesize searchEndReached = _searchEndReached;
@synthesize chatTitleSearchOnly = _chatTitleSearchOnly;
@synthesize searchInlineCurrentChatOnly = _searchInlineCurrentChatOnly;
@synthesize searchGeneration = _searchGeneration;
@synthesize chatSearchWindow = _chatSearchWindow;
@synthesize chatSearchWindowTextField = _chatSearchWindowTextField;
@synthesize chatSearchWindowScrollView = _chatSearchWindowScrollView;
@synthesize chatSearchWindowResultsView = _chatSearchWindowResultsView;
@synthesize chatSearchWindowStatusField = _chatSearchWindowStatusField;
@synthesize chatSearchWindowResults = _chatSearchWindowResults;
@synthesize chatSearchWindowResultButtons = _chatSearchWindowResultButtons;
@synthesize chatSearchGeneration = _chatSearchGeneration;
@synthesize mediaCenterWindow = _mediaCenterWindow;
@synthesize mediaCenterContentCardView = _mediaCenterContentCardView;
@synthesize mediaCenterSearchField = _mediaCenterSearchField;
@synthesize mediaCenterTabButtons = _mediaCenterTabButtons;
@synthesize mediaCenterSelectedTabIndex = _mediaCenterSelectedTabIndex;
@synthesize mediaCenterFilterPopUpButton = _mediaCenterFilterPopUpButton;
@synthesize mediaCenterSortPopUpButton = _mediaCenterSortPopUpButton;
@synthesize mediaCenterStatusField = _mediaCenterStatusField;
@synthesize mediaCenterScrollView = _mediaCenterScrollView;
@synthesize mediaCenterResultsView = _mediaCenterResultsView;
@synthesize mediaCenterRefreshButton = _mediaCenterRefreshButton;
@synthesize mediaCenterLoadingSpinner = _mediaCenterLoadingSpinner;
@synthesize mediaCenterLoading = _mediaCenterLoading;
@synthesize mediaCenterPreviewOverlayView = _mediaCenterPreviewOverlayView;
@synthesize mediaCenterPreviewImageView = _mediaCenterPreviewImageView;
@synthesize mediaCenterPreviewTitleField = _mediaCenterPreviewTitleField;
@synthesize mediaCenterPreviewCloseButton = _mediaCenterPreviewCloseButton;
@synthesize mediaCenterItems = _mediaCenterItems;
@synthesize mediaCenterPaginationAnchorsByFilter = _mediaCenterPaginationAnchorsByFilter;
@synthesize mediaCenterExhaustedFilterIdentifiers = _mediaCenterExhaustedFilterIdentifiers;
@synthesize mediaCenterSeenKeys = _mediaCenterSeenKeys;
@synthesize mediaCenterGeneration = _mediaCenterGeneration;
@synthesize mediaCenterLoadingMore = _mediaCenterLoadingMore;
@synthesize mediaCenterExhausted = _mediaCenterExhausted;
@synthesize pinnedMessagePanelView = _pinnedMessagePanelView;
@synthesize pinnedMessageStripeField = _pinnedMessageStripeField;
@synthesize pinnedMessageLabelField = _pinnedMessageLabelField;
@synthesize pinnedMessageTextField = _pinnedMessageTextField;
@synthesize pinnedMessageButton = _pinnedMessageButton;
@synthesize pinnedMessageItems = _pinnedMessageItems;
@synthesize pinnedMessageItem = _pinnedMessageItem;
@synthesize pinnedMessageCarouselIndex = _pinnedMessageCarouselIndex;
@synthesize pinnedMessageGeneration = _pinnedMessageGeneration;
@synthesize replyPanelView = _replyPanelView;
@synthesize replyPanelTitleField = _replyPanelTitleField;
@synthesize replyPanelTextField = _replyPanelTextField;
@synthesize replyPanelCancelButton = _replyPanelCancelButton;
@synthesize replyTargetMessageItem = _replyTargetMessageItem;
@synthesize replyTargetChatID = _replyTargetChatID;
@synthesize replyTargetThreadID = _replyTargetThreadID;
@synthesize replyTargetTopicKind = _replyTargetTopicKind;
@synthesize highlightedSearchMessageID = _highlightedSearchMessageID;
@synthesize searchHighlightTimer = _searchHighlightTimer;
@synthesize sendLabel = _sendLabel;
@synthesize sendTextFieldBackgroundView = _sendTextFieldBackgroundView;
@synthesize sendTextField = _sendTextField;
@synthesize attachPhotoButton = _attachPhotoButton;
@synthesize stickerButton = _stickerButton;
@synthesize voiceRecordButton = _voiceRecordButton;
@synthesize sendMessageButton = _sendMessageButton;
@synthesize authLabel = _authLabel;
@synthesize authStateField = _authStateField;
@synthesize loginIconView = _loginIconView;
@synthesize loginBrandField = _loginBrandField;
@synthesize loginTitleField = _loginTitleField;
@synthesize loginHintField = _loginHintField;
@synthesize authTextFieldBackgroundView = _authTextFieldBackgroundView;
@synthesize authTextField = _authTextField;
@synthesize authSecureField = _authSecureField;
@synthesize authSecondaryLabel = _authSecondaryLabel;
@synthesize authSecondaryTextFieldBackgroundView = _authSecondaryTextFieldBackgroundView;
@synthesize authButton = _authButton;
@synthesize busySpinner = _busySpinner;
@synthesize loginLogsButton = _loginLogsButton;
@synthesize loginLanguageButtons = _loginLanguageButtons;
@synthesize chatsLabel = _chatsLabel;
@synthesize messagesLabel = _messagesLabel;
@synthesize selectedChatField = _selectedChatField;
@synthesize typingIndicatorField = _typingIndicatorField;
@synthesize selectedChatAvatarView = _selectedChatAvatarView;
@synthesize selectedChatProfileButton = _selectedChatProfileButton;
@synthesize chatScrollSurfaceView = _chatScrollSurfaceView;
@synthesize chatScrollView = _chatScrollView;
@synthesize chatTableView = _chatTableView;
@synthesize chatItems = _chatItems;
@synthesize chatItemsBeforeTopicList = _chatItemsBeforeTopicList;
@synthesize messageScrollSurfaceView = _messageScrollSurfaceView;
@synthesize messageScrollView = _messageScrollView;
@synthesize messageTableView = _messageTableView;
@synthesize messageLoadingSpinner = _messageLoadingSpinner;
@synthesize messageJumpToNewestButton = _messageJumpToNewestButton;
@synthesize inlineMediaPlaybackCoordinator = _inlineMediaPlaybackCoordinator;
@synthesize inlineMediaPlaybackDiagnosticKeys = _inlineMediaPlaybackDiagnosticKeys;
@synthesize messageDropOverlayView = _messageDropOverlayView;
@synthesize messageItems = _messageItems;
@synthesize composerDraftsByTargetKey = _composerDraftsByTargetKey;
@synthesize composerDraftSyncTimer = _composerDraftSyncTimer;
@synthesize composerDraftSyncGeneration = _composerDraftSyncGeneration;
@synthesize composerDraftSyncChatID = _composerDraftSyncChatID;
@synthesize composerDraftSyncThreadID = _composerDraftSyncThreadID;
@synthesize composerDraftSyncTopicKind = _composerDraftSyncTopicKind;
@synthesize composerDraftSyncText = _composerDraftSyncText;
@synthesize composerDraftSyncReplyMessageID = _composerDraftSyncReplyMessageID;
@synthesize profileTitleField = _profileTitleField;
@synthesize profileNameField = _profileNameField;
@synthesize profileUsernameField = _profileUsernameField;
@synthesize profileIDField = _profileIDField;
@synthesize profileStateField = _profileStateField;
@synthesize profileAboutSectionField = _profileAboutSectionField;
@synthesize profileAccountSectionField = _profileAccountSectionField;
@synthesize profileUsernameRowTitleField = _profileUsernameRowTitleField;
@synthesize profileUsernameRowValueField = _profileUsernameRowValueField;
@synthesize profilePhoneRowTitleField = _profilePhoneRowTitleField;
@synthesize profilePhoneRowValueField = _profilePhoneRowValueField;
@synthesize profileIDRowTitleField = _profileIDRowTitleField;
@synthesize profileIDRowValueField = _profileIDRowValueField;
@synthesize profileDetailsSeparatorOne = _profileDetailsSeparatorOne;
@synthesize profileDetailsSeparatorTwo = _profileDetailsSeparatorTwo;
@synthesize settingsTitleField = _settingsTitleField;
@synthesize settingsStateField = _settingsStateField;
@synthesize settingsLibraryField = _settingsLibraryField;
@synthesize settingsStorageField = _settingsStorageField;
@synthesize settingsDrawerSectionField = _settingsDrawerSectionField;
@synthesize settingsResourceSectionField = _settingsResourceSectionField;
@synthesize settingsFilesSectionField = _settingsFilesSectionField;
@synthesize settingsHelpSectionField = _settingsHelpSectionField;
@synthesize settingsThemeLabel = _settingsThemeLabel;
@synthesize settingsThemeCategoryLabel = _settingsThemeCategoryLabel;
@synthesize themeCategoryPopUpButton = _themeCategoryPopUpButton;
@synthesize themePopUpButton = _themePopUpButton;
@synthesize settingsNotificationsEnabledButton = _settingsNotificationsEnabledButton;
@synthesize settingsNotificationSoundButton = _settingsNotificationSoundButton;
@synthesize settingsNotificationBadgeButton = _settingsNotificationBadgeButton;
@synthesize settingsNotificationPreviewButton = _settingsNotificationPreviewButton;
@synthesize settingsNotificationsWhenActiveButton = _settingsNotificationsWhenActiveButton;
@synthesize settingsDrawerHiddenButton = _settingsDrawerHiddenButton;
@synthesize settingsTypingIndicatorsButton = _settingsTypingIndicatorsButton;
@synthesize settingsEconomyModeButton = _settingsEconomyModeButton;
@synthesize settingsAutoDownloadPhotosButton = _settingsAutoDownloadPhotosButton;
@synthesize settingsAutoDownloadVideosButton = _settingsAutoDownloadVideosButton;
@synthesize settingsAutoDownloadDocumentsButton = _settingsAutoDownloadDocumentsButton;
@synthesize settingsAutoplayAnimatedStickersButton = _settingsAutoplayAnimatedStickersButton;
@synthesize settingsStopInactiveAnimationsButton = _settingsStopInactiveAnimationsButton;
@synthesize settingsMaxAutoDownloadLabel = _settingsMaxAutoDownloadLabel;
@synthesize settingsMaxAutoDownloadPopUpButton = _settingsMaxAutoDownloadPopUpButton;
@synthesize settingsMaxAnimationsLabel = _settingsMaxAnimationsLabel;
@synthesize settingsMaxAnimationsPopUpButton = _settingsMaxAnimationsPopUpButton;
@synthesize settingsMediaCacheLimitLabel = _settingsMediaCacheLimitLabel;
@synthesize settingsMediaCacheLimitPopUpButton = _settingsMediaCacheLimitPopUpButton;
@synthesize settingsResourceHintField = _settingsResourceHintField;
@synthesize settingsActiveSessionsButton = _settingsActiveSessionsButton;
@synthesize settingsActiveSessionsDetailField = _settingsActiveSessionsDetailField;
@synthesize settingsLanguageLabel = _settingsLanguageLabel;
@synthesize settingsLanguagePopUpButton = _settingsLanguagePopUpButton;
@synthesize settingsMessagesAsBlocksButton = _settingsMessagesAsBlocksButton;
@synthesize settingsChatTextSizeSectionField = _settingsChatTextSizeSectionField;
@synthesize settingsChatTextSizeSlider = _settingsChatTextSizeSlider;
@synthesize settingsChatTextSizeValueField = _settingsChatTextSizeValueField;
@synthesize settingsDownloadFolderHelpField = _settingsDownloadFolderHelpField;
@synthesize settingsDownloadFolderButton = _settingsDownloadFolderButton;
@synthesize settingsStorageUsageButton = _settingsStorageUsageButton;
@synthesize settingsDeleteLocalDataButton = _settingsDeleteLocalDataButton;
@synthesize settingsCheckUpdatesButton = _settingsCheckUpdatesButton;
@synthesize settingsUpdateDotView = _settingsUpdateDotView;
@synthesize settingsAppearanceButton = _settingsAppearanceButton;
@synthesize settingsLogsButton = _settingsLogsButton;
@synthesize settingsAboutButton = _settingsAboutButton;
@synthesize logoutButton = _logoutButton;
@synthesize profileRefreshButton = _profileRefreshButton;
@synthesize aboutIconView = _aboutIconView;
@synthesize aboutTitleField = _aboutTitleField;
@synthesize aboutVersionField = _aboutVersionField;
@synthesize aboutCopyrightField = _aboutCopyrightField;
@synthesize aboutLinkField = _aboutLinkField;
@synthesize selectedChatID = _selectedChatID;
@synthesize selectedChatTitle = _selectedChatTitle;
@synthesize selectedChatTypeSummary = _selectedChatTypeSummary;
@synthesize selectedChatAvatarLocalPath = _selectedChatAvatarLocalPath;
@synthesize selectedChatLastReadOutboxMessageID = _selectedChatLastReadOutboxMessageID;
@synthesize selectedMessageThreadID = _selectedMessageThreadID;
@synthesize selectedMessageTopicKind = _selectedMessageTopicKind;
@synthesize commentThreadParentTitle = _commentThreadParentTitle;
@synthesize commentThreadParentTypeSummary = _commentThreadParentTypeSummary;
@synthesize commentThreadParentAvatarLocalPath = _commentThreadParentAvatarLocalPath;
@synthesize topicParentChatID = _topicParentChatID;
@synthesize topicParentTitle = _topicParentTitle;
@synthesize topicParentAvatarLocalPath = _topicParentAvatarLocalPath;
@synthesize selectedChatFilterID = _selectedChatFilterID;
@synthesize profileDisplayName = _profileDisplayName;
@synthesize profileFirstName = _profileFirstName;
@synthesize profileLastName = _profileLastName;
@synthesize profileUsername = _profileUsername;
@synthesize profilePhoneNumber = _profilePhoneNumber;
@synthesize profileUserID = _profileUserID;
@synthesize profileAvatarLocalPath = _profileAvatarLocalPath;
@synthesize profileBio = _profileBio;
@synthesize lastLogSection = _lastLogSection;
@synthesize logsWindow = _logsWindow;
@synthesize aboutWindow = _aboutWindow;
@synthesize appearanceWindow = _appearanceWindow;
@synthesize activeSessionsWindow = _activeSessionsWindow;
@synthesize activeSessionsTextView = _activeSessionsTextView;
@synthesize activeSessionsTableView = _activeSessionsTableView;
@synthesize activeSessionsSelectableSessions = _activeSessionsSelectableSessions;
@synthesize activeSessionsStatusField = _activeSessionsStatusField;
@synthesize activeSessionsRefreshButton = _activeSessionsRefreshButton;
@synthesize activeSessionsTerminatePopup = _activeSessionsTerminatePopup;
@synthesize activeSessionsTerminateButton = _activeSessionsTerminateButton;
@synthesize activeSessionsCloseButton = _activeSessionsCloseButton;
@synthesize activeSessionsSummary = _activeSessionsSummary;
@synthesize activeSessionsRequestGeneration = _activeSessionsRequestGeneration;
@synthesize mediaPreviewWindow = _mediaPreviewWindow;
@synthesize mediaPreviewScrollView = _mediaPreviewScrollView;
@synthesize mediaPreviewImageView = _mediaPreviewImageView;
@synthesize mediaPreviewZoomOutButton = _mediaPreviewZoomOutButton;
@synthesize mediaPreviewFitButton = _mediaPreviewFitButton;
@synthesize mediaPreviewZoomInButton = _mediaPreviewZoomInButton;
@synthesize mediaPlaybackWindow = _mediaPlaybackWindow;
@synthesize mediaPlaybackContainerView = _mediaPlaybackContainerView;
@synthesize mediaPlaybackTitleField = _mediaPlaybackTitleField;
@synthesize mediaPlaybackPlayPauseButton = _mediaPlaybackPlayPauseButton;
@synthesize mediaPlaybackProgressSlider = _mediaPlaybackProgressSlider;
@synthesize mediaPlaybackTimeField = _mediaPlaybackTimeField;
@synthesize mediaPlaybackCloseButton = _mediaPlaybackCloseButton;
@synthesize mediaPlaybackPlayer = _mediaPlaybackPlayer;
@synthesize mediaPlaybackLayer = _mediaPlaybackLayer;
@synthesize mediaPlaybackTimer = _mediaPlaybackTimer;
@synthesize messageViewersWindowController = _messageViewersWindowController;
@synthesize photoSendPreviewWindow = _photoSendPreviewWindow;
@synthesize photoSendPreviewImageView = _photoSendPreviewImageView;
@synthesize photoSendCaptionBackgroundView = _photoSendCaptionBackgroundView;
@synthesize photoSendCaptionField = _photoSendCaptionField;
@synthesize photoSendTitleField = _photoSendTitleField;
@synthesize photoSendErrorField = _photoSendErrorField;
@synthesize photoSendMetaField = _photoSendMetaField;
@synthesize photoSendSendButton = _photoSendSendButton;
@synthesize photoSendQueueScrollView = _photoSendQueueScrollView;
@synthesize photoSendQueueContentView = _photoSendQueueContentView;
@synthesize pendingPhotoSendPath = _pendingPhotoSendPath;
@synthesize pendingAttachmentDescriptor = _pendingAttachmentDescriptor;
@synthesize pendingAttachmentDescriptors = _pendingAttachmentDescriptors;
@synthesize pendingAttachmentTransferState = _pendingAttachmentTransferState;
@synthesize pendingAttachmentQueueItems = _pendingAttachmentQueueItems;
@synthesize pendingAttachmentCancelRequested = _pendingAttachmentCancelRequested;
@synthesize pendingPhotoSendChatID = _pendingPhotoSendChatID;
@synthesize pendingPhotoSendThreadID = _pendingPhotoSendThreadID;
@synthesize pendingPhotoSendTopicKind = _pendingPhotoSendTopicKind;
@synthesize stickerPickerWindow = _stickerPickerWindow;
@synthesize stickerPickerScrollView = _stickerPickerScrollView;
@synthesize stickerPickerContentView = _stickerPickerContentView;
@synthesize stickerPickerRecentButton = _stickerPickerRecentButton;
@synthesize stickerPickerFavoriteButton = _stickerPickerFavoriteButton;
@synthesize stickerPickerSearchField = _stickerPickerSearchField;
@synthesize stickerPickerSetScrollView = _stickerPickerSetScrollView;
@synthesize stickerPickerSetContentView = _stickerPickerSetContentView;
@synthesize stickerPickerItems = _stickerPickerItems;
@synthesize stickerPickerStickerSets = _stickerPickerStickerSets;
@synthesize stickerPickerSetCache = _stickerPickerSetCache;
@synthesize stickerPickerRailPreviewState = _stickerPickerRailPreviewState;
@synthesize stickerPickerSelectedSetID = _stickerPickerSelectedSetID;
@synthesize stickerPickerStatusField = _stickerPickerStatusField;
@synthesize stickerPickerPlaybackCoordinator = _stickerPickerPlaybackCoordinator;
@synthesize stickerPickerLoadGeneration = _stickerPickerLoadGeneration;
@synthesize voiceRecorder = _voiceRecorder;
@synthesize voicePreviewPlayer = _voicePreviewPlayer;
@synthesize voiceRecordingPath = _voiceRecordingPath;
@synthesize voiceRecordingStartDate = _voiceRecordingStartDate;
@synthesize voicePreviewWindow = _voicePreviewWindow;
@synthesize voicePreviewTitleField = _voicePreviewTitleField;
@synthesize voicePreviewPlayButton = _voicePreviewPlayButton;
@synthesize voicePreviewStopButton = _voicePreviewStopButton;
@synthesize voicePreviewProgressSlider = _voicePreviewProgressSlider;
@synthesize voicePreviewTimeField = _voicePreviewTimeField;
@synthesize voicePreviewCancelButton = _voicePreviewCancelButton;
@synthesize voicePreviewSendButton = _voicePreviewSendButton;
@synthesize voicePreviewErrorField = _voicePreviewErrorField;
@synthesize voicePreviewTimer = _voicePreviewTimer;
@synthesize voiceRecordingIndicatorField = _voiceRecordingIndicatorField;
@synthesize messageContextMenu = _messageContextMenu;
@synthesize chatContextMenu = _chatContextMenu;
@synthesize chatsNavigationContextMenu = _chatsNavigationContextMenu;
@synthesize mediaPreviewPath = _mediaPreviewPath;
@synthesize mediaPreviewRequestGeneration = _mediaPreviewRequestGeneration;
@synthesize logsWindowDetailsView = _logsWindowDetailsView;
@synthesize logsCheckButton = _logsCheckButton;
@synthesize appearanceThemePopUpButton = _appearanceThemePopUpButton;
@synthesize client = _client;
@synthesize currentAuthState = _currentAuthState;
@synthesize activeSection = _activeSection;
@synthesize liveUpdateTimer = _liveUpdateTimer;
@synthesize controlsBusy = _controlsBusy;
@synthesize authSubmissionInFlight = _authSubmissionInFlight;
@synthesize authClientRecoveryInFlight = _authClientRecoveryInFlight;
@synthesize authClientRecoveryAttemptCount = _authClientRecoveryAttemptCount;
@synthesize accountUnreadCount = _accountUnreadCount;
@synthesize hasAccountUnreadCount = _hasAccountUnreadCount;
@synthesize backgroundChatRefreshInFlight = _backgroundChatRefreshInFlight;
@synthesize backgroundMessageRefreshInFlight = _backgroundMessageRefreshInFlight;
@synthesize messageLoadingIndicatorVisible = _messageLoadingIndicatorVisible;
@synthesize messageLoadingGeneration = _messageLoadingGeneration;
@synthesize pendingLiveChatRefresh = _pendingLiveChatRefresh;
@synthesize pendingLiveMessageRefresh = _pendingLiveMessageRefresh;
@synthesize chatPreviewLimit = _chatPreviewLimit;
@synthesize chatsExhausted = _chatsExhausted;
@synthesize olderMessagesExhausted = _olderMessagesExhausted;
@synthesize autoOlderMessagesLoadArmed = _autoOlderMessagesLoadArmed;
@synthesize autoChatListLoadArmed = _autoChatListLoadArmed;
@synthesize autoChatListRefreshArmed = _autoChatListRefreshArmed;
@synthesize forceMessageScrollToNewest = _forceMessageScrollToNewest;
@synthesize messageItemsRepresentFocusedContext = _messageItemsRepresentFocusedContext;
@synthesize initialConnectStarted = _initialConnectStarted;
@synthesize profileSummaryLoaded = _profileSummaryLoaded;
@synthesize profileSummaryLoading = _profileSummaryLoading;
@synthesize drawerOpen = _drawerOpen;
@synthesize suppressComposerDraftSave = _suppressComposerDraftSave;
@synthesize loginErrorVisible = _loginErrorVisible;
@synthesize loginErrorLocalizationKey = _loginErrorLocalizationKey;
@synthesize composerRefocusPending = _composerRefocusPending;
@synthesize messageDropOverlayVisible = _messageDropOverlayVisible;
@synthesize offlineModeActive = _offlineModeActive;
@synthesize updateAvailable = _updateAvailable;
@synthesize availableUpdateVersion = _availableUpdateVersion;
@synthesize chatFilterRefreshInFlight = _chatFilterRefreshInFlight;
@synthesize chatFilterRefreshPending = _chatFilterRefreshPending;
@synthesize chatFilterRefreshRetryCount = _chatFilterRefreshRetryCount;
@synthesize forumTopicRefreshInFlight = _forumTopicRefreshInFlight;
@synthesize typingChatID = _typingChatID;
@synthesize typingIndicatorText = _typingIndicatorText;
@synthesize typingClearTimer = _typingClearTimer;
@synthesize pendingNotificationChatID = _pendingNotificationChatID;
@synthesize pendingNotificationThreadID = _pendingNotificationThreadID;
@synthesize notificationChatInfoByChatID = _notificationChatInfoByChatID;
@synthesize localMuteUnreadCountsByChatID = _localMuteUnreadCountsByChatID;
@synthesize suppressChatSelectionHandling = _suppressChatSelectionHandling;
@synthesize showingForumTopicList = _showingForumTopicList;
@synthesize chatNavigationClosed = _chatNavigationClosed;
@synthesize suppressedForumTopicAutoOpenChatID = _suppressedForumTopicAutoOpenChatID;
@synthesize forumTopicNavigationGeneration = _forumTopicNavigationGeneration;
@synthesize mediaPreviewZoomScale = _mediaPreviewZoomScale;
@synthesize mediaPreviewMinimumZoomScale = _mediaPreviewMinimumZoomScale;
@synthesize mediaPlaybackPlaying = _mediaPlaybackPlaying;
@synthesize mediaPlaybackAudioOnly = _mediaPlaybackAudioOnly;
@synthesize mediaPlaybackKnownDuration = _mediaPlaybackKnownDuration;

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 980, 700);
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    [window setTitle:@"Telegraphica"];
    [window setMinSize:NSMakeSize(760, 620)];
    [window center];

    self = [super initWithWindow:window];
    if (self) {
        [[self window] setDelegate:self];
        TGResourcePolicyApplyDefaultsIfNeeded();
        self.client = [[[TGTDLibClient alloc] init] autorelease];
        TGSetActiveThemeIdentifier([[NSUserDefaults standardUserDefaults] stringForKey:TGThemeDefaultsKey]);
        self.chatItems = [NSMutableArray array];
        self.messageItems = [NSMutableArray array];
        self.searchResultItems = [NSMutableArray array];
        self.chatSearchWindowResults = [NSMutableArray array];
        self.chatSearchWindowResultButtons = [NSMutableArray array];
        self.mediaCenterItems = [NSMutableArray array];
        self.mediaCenterPaginationAnchorsByFilter = [NSMutableDictionary dictionary];
        self.mediaCenterExhaustedFilterIdentifiers = [NSMutableSet set];
        self.mediaCenterSeenKeys = [NSMutableSet set];
        self.inlineMediaPlaybackDiagnosticKeys = [NSMutableSet set];
        self.composerDraftsByTargetKey = [NSMutableDictionary dictionary];
        self.notificationChatInfoByChatID = [NSMutableDictionary dictionary];
        self.localMuteUnreadCountsByChatID = [NSMutableDictionary dictionary];
        self.chatFilterInfos = [NSArray array];
        self.closedChatSuggestionViews = [NSArray array];
        self.closedChatSuggestionItems = [NSArray array];
        self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
        self.activeSection = TGSectionChats;
        NSString *storedUpdateVersion = [[NSUserDefaults standardUserDefaults] stringForKey:TGAvailableUpdateVersionDefaultsKey];
        if ([storedUpdateVersion isKindOfClass:[NSString class]] &&
            TGVersionStringIsNewer(storedUpdateVersion, TGCurrentApplicationVersionString())) {
            self.availableUpdateVersion = storedUpdateVersion;
            self.updateAvailable = YES;
        } else if ([storedUpdateVersion length] > 0) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:TGAvailableUpdateVersionDefaultsKey];
        }
        self.mediaPreviewZoomScale = 1.0;
        self.autoChatListLoadArmed = YES;
        self.autoChatListRefreshArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleInlineMediaPlaybackDiagnostic:)
                                                     name:TGInlineMediaPlaybackDiagnosticNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resourcePolicyDidChange:)
                                                     name:TGResourcePolicyDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(chatFiltersDidChange:)
                                                     name:TGTDLibChatFiltersDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(chatDisplayPreferencesDidChange:)
                                                     name:TGChatDisplayPreferencesDidChangeNotification
                                                   object:nil];
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
        [self buildContentView];
        [self refreshUpdateAvailabilityBadge];
        [self applyPointingHandCursorToButtonsInView:[[self window] contentView]];
        [self applyResourcePolicyToMediaSubsystems];
        [self startLiveUpdateTimerIfNeeded];
        [self performSelector:@selector(connectOnLaunch:) withObject:nil afterDelay:0.15];
        [self performSelector:@selector(checkForUpdatesOnLaunch) withObject:nil afterDelay:3.0];
    }
    return self;
}

- (void)handleInlineMediaPlaybackDiagnostic:(NSNotification *)notification {
    id message = [[notification userInfo] objectForKey:TGInlineMediaPlaybackDiagnosticMessageKey];
    if ([message isKindOfClass:[NSString class]] && [(NSString *)message length] > 0) {
        [[TGLogger sharedLogger] log:(NSString *)message];
    }
}

- (void)chatFiltersDidChange:(NSNotification *)notification {
    if ([notification object] && [notification object] != self.client) {
        return;
    }
    NSArray *updatedFilters = [[[notification userInfo] objectForKey:@"chatFilterInfos"] retain];
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(handleChatFiltersDidChangeOnMainThread:)
                               withObject:updatedFilters
                            waitUntilDone:NO];
        [updatedFilters release];
        return;
    }
    [self handleChatFiltersDidChangeOnMainThread:updatedFilters];
    [updatedFilters release];
}

- (void)handleChatFiltersDidChangeOnMainThread:(NSArray *)updatedFilters {
    [[TGLogger sharedLogger] log:@"Drawer: TDLib chat folder update received on main thread; refreshing drawer folders."];
    if ([updatedFilters isKindOfClass:[NSArray class]]) {
        self.chatFilterInfos = updatedFilters;
        self.chatFilterRefreshInFlight = NO;
        self.chatFilterRefreshPending = NO;
        [self rebuildDrawerFolderButtons];
        return;
    }
    if (self.chatFilterRefreshInFlight) {
        self.chatFilterRefreshPending = YES;
        [[TGLogger sharedLogger] log:@"Drawer: chat folder refresh already in flight; queued one follow-up refresh."];
        return;
    }
    [self reloadChatFiltersIfReady];
}

- (void)applyTransparentChatTableStyle {
    if (TGThemeIsSkeuomorphicBlue()) {
        [self.chatTableView setBackgroundColor:TGClassicTablePaperColor()];
        [[self.chatScrollView contentView] setDrawsBackground:YES];
        [[self.chatScrollView contentView] setBackgroundColor:TGClassicTablePaperColor()];
    } else {
        [self.chatTableView setBackgroundColor:[NSColor clearColor]];
        [[self.chatScrollView contentView] setDrawsBackground:NO];
        [[self.chatScrollView contentView] setBackgroundColor:[NSColor clearColor]];
    }
    [self.chatTableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [self.chatTableView setGridColor:TGClassicTableGridColor()];
    [self.chatTableView setUsesAlternatingRowBackgroundColors:NO];
    [self.chatTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
}

- (void)applyMessageTranscriptBackgroundStyle {
    if (TGThemeIsSkeuomorphicBlue()) {
        [self.messageTableView setBackgroundColor:[NSColor clearColor]];
        [self.messageScrollView setDrawsBackground:NO];
        [[self.messageScrollView contentView] setDrawsBackground:NO];
        [[self.messageScrollView contentView] setBackgroundColor:[NSColor clearColor]];
        [[self.messageScrollView contentView] setCopiesOnScroll:NO];
    } else {
        [self.messageScrollView setDrawsBackground:YES];
        [self.messageTableView setBackgroundColor:TGClassicTablePaperColor()];
        [[self.messageScrollView contentView] setDrawsBackground:YES];
        [[self.messageScrollView contentView] setBackgroundColor:TGClassicTablePaperColor()];
        [[self.messageScrollView contentView] setCopiesOnScroll:YES];
    }
}

- (void)selectThemePopUpItemForIdentifier:(NSString *)identifier {
    if (!TGThemeIdentifierIsValid(identifier)) {
        identifier = TGCurrentThemeIdentifier();
    }
    NSString *categoryIdentifier = TGThemeCategoryIdentifierForThemeIdentifier(identifier);
    [self selectThemeCategoryPopUpItemForIdentifier:categoryIdentifier];
    [self populateThemePopUpButton:self.themePopUpButton
             forCategoryIdentifier:categoryIdentifier
                selectedIdentifier:identifier];

    NSArray *popUpButtons = [NSArray arrayWithObjects:
                             self.themePopUpButton ? self.themePopUpButton : (id)[NSNull null],
                             self.appearanceThemePopUpButton ? self.appearanceThemePopUpButton : (id)[NSNull null],
                             nil];
    NSUInteger popUpIndex = 0;
    for (popUpIndex = 0; popUpIndex < [popUpButtons count]; popUpIndex++) {
        id candidate = [popUpButtons objectAtIndex:popUpIndex];
        if (![candidate isKindOfClass:[NSPopUpButton class]]) {
            continue;
        }
        NSPopUpButton *popUpButton = (NSPopUpButton *)candidate;
        NSArray *items = [popUpButton itemArray];
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            NSMenuItem *item = [items objectAtIndex:index];
            if ([[item representedObject] isEqual:identifier]) {
                [popUpButton selectItem:item];
                break;
            }
        }
        if ([popUpButton selectedItem] == nil && [items count] > 0) {
            [popUpButton selectItemAtIndex:0];
        }
    }
}

- (NSString *)localizedThemeCategoryTitleForIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:TGThemeCategoryIdentifierDark]) {
        return TGLoc(@"settings.theme.category.dark");
    }
    if ([identifier isEqualToString:TGThemeCategoryIdentifierOldSchool]) {
        return TGLoc(@"settings.theme.category.oldSchool");
    }
    if ([identifier isEqualToString:TGThemeCategoryIdentifierExperimental]) {
        return TGLoc(@"settings.theme.category.experimental");
    }
    if ([identifier isEqualToString:TGThemeCategoryIdentifierVisualWorlds]) {
        return TGLoc(@"settings.theme.category.visualWorlds");
    }
    return TGLoc(@"settings.theme.category.light");
}

- (void)populateThemeCategoryPopUp {
    if (!self.themeCategoryPopUpButton) {
        return;
    }
    NSString *selectedIdentifier = [[self.themeCategoryPopUpButton selectedItem] representedObject];
    if (![selectedIdentifier isKindOfClass:[NSString class]]) {
        selectedIdentifier = TGThemeCategoryIdentifierForThemeIdentifier(TGCurrentThemeIdentifier());
    }
    [self.themeCategoryPopUpButton removeAllItems];
    NSArray *categoryIdentifiers = TGThemeCategoryIdentifiers();
    NSUInteger index = 0;
    for (index = 0; index < [categoryIdentifiers count]; index++) {
        NSString *categoryIdentifier = [categoryIdentifiers objectAtIndex:index];
        [self.themeCategoryPopUpButton addItemWithTitle:[self localizedThemeCategoryTitleForIdentifier:categoryIdentifier]];
        [[self.themeCategoryPopUpButton lastItem] setRepresentedObject:categoryIdentifier];
    }
    [self selectThemeCategoryPopUpItemForIdentifier:selectedIdentifier];
}

- (void)selectThemeCategoryPopUpItemForIdentifier:(NSString *)identifier {
    if (!self.themeCategoryPopUpButton) {
        return;
    }
    if (![identifier isKindOfClass:[NSString class]] || [identifier length] == 0) {
        identifier = TGThemeCategoryIdentifierForThemeIdentifier(TGCurrentThemeIdentifier());
    }
    NSArray *items = [self.themeCategoryPopUpButton itemArray];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        NSMenuItem *item = [items objectAtIndex:index];
        if ([[item representedObject] isEqual:identifier]) {
            [self.themeCategoryPopUpButton selectItem:item];
            return;
        }
    }
    if ([items count] > 0) {
        [self.themeCategoryPopUpButton selectItemAtIndex:0];
    }
}

- (void)populateThemePopUpButton:(NSPopUpButton *)popUpButton
           forCategoryIdentifier:(NSString *)categoryIdentifier
              selectedIdentifier:(NSString *)selectedIdentifier {
    if (!popUpButton) {
        return;
    }
    NSArray *themeIdentifiers = nil;
    if (popUpButton == self.themePopUpButton) {
        themeIdentifiers = TGThemeIdentifiersForCategory(categoryIdentifier);
    } else {
        themeIdentifiers = TGThemeIdentifiers();
    }
    if ([themeIdentifiers count] == 0) {
        themeIdentifiers = TGThemeIdentifiers();
    }
    [popUpButton removeAllItems];
    NSUInteger themeIndex = 0;
    for (themeIndex = 0; themeIndex < [themeIdentifiers count]; themeIndex++) {
        NSString *themeIdentifier = [themeIdentifiers objectAtIndex:themeIndex];
        [popUpButton addItemWithTitle:TGThemeDisplayNameForIdentifier(themeIdentifier)];
        [[popUpButton lastItem] setRepresentedObject:themeIdentifier];
    }
    NSArray *items = [popUpButton itemArray];
    NSUInteger itemIndex = 0;
    for (itemIndex = 0; itemIndex < [items count]; itemIndex++) {
        NSMenuItem *item = [items objectAtIndex:itemIndex];
        if ([[item representedObject] isEqual:selectedIdentifier]) {
            [popUpButton selectItem:item];
            return;
        }
    }
    if ([items count] > 0) {
        [popUpButton selectItemAtIndex:0];
    }
}

- (void)updateSavedMessagesPresentationForChatItems {
    long long profileID = 0;
    if ([self.profileUserID respondsToSelector:@selector(longLongValue)]) {
        profileID = [self.profileUserID longLongValue];
    }
    if (profileID == 0) {
        return;
    }

    BOOL changed = NO;
    NSArray *collections[2] = { self.chatItems, self.chatItemsBeforeTopicList };
    NSUInteger collectionIndex = 0;
    for (collectionIndex = 0; collectionIndex < 2; collectionIndex++) {
        NSArray *collection = collections[collectionIndex];
        NSUInteger index = 0;
        for (index = 0; index < [collection count]; index++) {
            id candidate = [collection objectAtIndex:index];
            if (![candidate isKindOfClass:[TGChatItem class]]) {
                continue;
            }
            TGChatItem *item = (TGChatItem *)candidate;
            BOOL savedMessages = (![item isForumTopic] &&
                                  [[item chatID] respondsToSelector:@selector(longLongValue)] &&
                                  [[item chatID] longLongValue] == profileID);
            if ([item isSavedMessages] != savedMessages) {
                [item setSavedMessages:savedMessages];
                changed = YES;
            }
            if (savedMessages && ![[item title] isEqualToString:TGLoc(@"savedMessages")]) {
                [item setTitle:TGLoc(@"savedMessages")];
                changed = YES;
            }
        }
    }

    if (changed) {
        [self.chatTableView reloadData];
        if (self.chatSearchWindow) {
            [self updateChatSearchWindowResults];
        }
    }
}

- (void)setMarkAllChatsReadBusy:(BOOL)busy {
    if (!self.markAllChatsReadSpinner) {
        return;
    }
    if (busy) {
        [self.markAllChatsReadSpinner setHidden:NO];
        [self.markAllChatsReadSpinner startAnimation:self];
    } else {
        [self.markAllChatsReadSpinner stopAnimation:self];
        [self.markAllChatsReadSpinner setHidden:YES];
    }
}

- (void)selectLanguagePopUpItemForCode:(NSString *)code {
    if (![code isKindOfClass:[NSString class]] || [code length] == 0) {
        code = TGLanguageCode();
    }
    NSArray *items = [self.settingsLanguagePopUpButton itemArray];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        NSMenuItem *item = [items objectAtIndex:index];
        if ([[item representedObject] isEqual:code]) {
            [self.settingsLanguagePopUpButton selectItem:item];
            return;
        }
    }
    if ([items count] > 0) {
        [self.settingsLanguagePopUpButton selectItemAtIndex:0];
    }
}

- (void)refreshDownloadFolderButtonTitle {
    NSString *path = TGConfiguredDownloadFolderPath();
    NSString *displayPath = TGDisplayPathForDownloadFolder(path);
    [self.settingsDownloadFolderButton setTitle:[NSString stringWithFormat:@"%@: %@", TGLoc(@"settings.downloads"), displayPath]];
    [self.settingsDownloadFolderButton setToolTip:path];
}

- (void)refreshLoginLocalizedText {
    NSString *state = self.currentAuthState;
    NSString *title = TGLoc(@"login.connecting.title");
    NSString *hint = TGLoc(@"login.connecting.hint");
    NSString *label = TGLoc(@"login.status");

    if ([state isEqualToString:@"waitPhoneNumber"]) {
        title = TGLoc(@"login.title");
        hint = TGLoc(@"login.phone.hint");
        label = TGLoc(@"login.phone.label");
    } else if ([state isEqualToString:@"waitCode"]) {
        title = TGLoc(@"login.code.title");
        hint = TGLoc(@"login.code.hint");
        label = TGLoc(@"login.code.label");
    } else if ([state isEqualToString:@"waitPassword"]) {
        title = TGLoc(@"login.password.title");
        hint = TGLoc(@"login.password.hint");
        label = TGLoc(@"login.password.label");
    } else if ([state isEqualToString:@"waitApiCredentials"]) {
        title = TGLoc(@"login.config.title");
        hint = TGLoc(@"login.config.missing");
    }

    [self.loginTitleField setStringValue:title];
    [self.loginHintField setStringValue:hint];
    [self.authLabel setStringValue:label];
    [self.authButton setTitle:(self.authSubmissionInFlight ? TGLoc(@"login.sending") : TGLoc(@"login.send"))];
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [[self.authTextField cell] setPlaceholderString:@"+123456789"];
        [self applyComposerPlaceholderStyle:self.authTextField];
    } else if ([state isEqualToString:@"waitCode"]) {
        [[self.authTextField cell] setPlaceholderString:label];
        [self applyComposerPlaceholderStyle:self.authTextField];
    } else if ([state isEqualToString:@"waitPassword"]) {
        [[self.authSecureField cell] setPlaceholderString:label];
        [self applyComposerPlaceholderStyle:self.authSecureField];
    }
}

- (void)refreshLocalizedText {
    [self.chatsLabel setStringValue:TGLoc(@"chats")];
    [self.profileTitleField setStringValue:TGLoc(@"profile.title")];
    [self.profileAboutSectionField setStringValue:TGLoc(@"profile.about")];
    [self.profileAccountSectionField setStringValue:TGLoc(@"profile.account")];
    [self.profileUsernameRowTitleField setStringValue:TGLoc(@"profile.username")];
    [self.profilePhoneRowTitleField setStringValue:TGLoc(@"profile.phone")];
    [self.profileIDRowTitleField setStringValue:TGLoc(@"profile.id")];
    [self applyDestructiveSettingsButtonStyle:self.logoutButton];
    [self.settingsTitleField setStringValue:TGLoc(@"settings")];
    [[self.sendTextField cell] setPlaceholderString:TGLoc(@"message.placeholder")];
    [self applyComposerPlaceholderStyle:self.sendTextField];
    [self.attachPhotoButton setToolTip:TGLoc(@"attach.photo")];
    [self.stickerButton setToolTip:TGLoc(@"stickers")];
    [self.voiceRecordButton setToolTip:TGLoc(@"voice")];
    [self.sendMessageButton setToolTip:TGLoc(@"send")];
    [self.settingsNotificationsEnabledButton setTitle:TGLoc(@"settings.notifications")];
    [self.settingsNotificationSoundButton setTitle:TGLoc(@"settings.sound")];
    [self.settingsNotificationBadgeButton setTitle:TGLoc(@"settings.badge")];
    [self.settingsNotificationPreviewButton setTitle:TGLoc(@"settings.preview")];
    [self.settingsNotificationsWhenActiveButton setTitle:TGLoc(@"settings.whenActive")];
    [self.settingsDrawerHiddenButton setTitle:TGLoc(@"settings.drawer")];
    [self.settingsTypingIndicatorsButton setTitle:TGLoc(@"settings.typing")];
    [self.settingsStateField setStringValue:TGLoc(@"settings.section.notifications")];
    [self.settingsDrawerSectionField setStringValue:TGLoc(@"settings.section.drawer")];
    [self.settingsResourceSectionField setStringValue:TGLoc(@"settings.section.resources")];
    [self.settingsLibraryField setStringValue:TGLoc(@"settings.appearance")];
    [self.settingsStorageField setStringValue:TGLoc(@"settings.section.sessions")];
    [self.settingsFilesSectionField setStringValue:TGLoc(@"settings.section.files")];
    [self.settingsHelpSectionField setStringValue:TGLoc(@"settings.section.help")];
    [self.settingsThemeCategoryLabel setStringValue:TGLoc(@"settings.theme.category")];
    [self.settingsThemeLabel setStringValue:TGLoc(@"settings.theme")];
    [self.settingsLanguageLabel setStringValue:TGLoc(@"settings.language")];
    [self.settingsMessagesAsBlocksButton setTitle:TGLoc(@"settings.messages.blocks")];
    [self.settingsChatTextSizeSectionField setStringValue:TGLoc(@"settings.chatText")];
    [self refreshChatDisplayPreferenceControls];
    [self.settingsDownloadFolderHelpField setStringValue:TGLoc(@"settings.downloads.help")];
    [self.settingsActiveSessionsDetailField setStringValue:TGLoc(@"settings.sessions.help")];
    [self.settingsActiveSessionsButton setTitle:TGLoc(@"settings.sessions.open")];
    [self.settingsStorageUsageButton setTitle:TGLoc(@"storage.open")];
    [self.settingsDeleteLocalDataButton setTitle:TGLoc(@"settings.localData.delete")];
    [self.settingsEconomyModeButton setTitle:TGLoc(@"settings.resources.economy")];
    [self.settingsAutoDownloadPhotosButton setTitle:TGLoc(@"settings.resources.photos")];
    [self.settingsAutoDownloadVideosButton setTitle:TGLoc(@"settings.resources.videos")];
    [self.settingsAutoDownloadDocumentsButton setTitle:TGLoc(@"settings.resources.documents")];
    [self.settingsAutoplayAnimatedStickersButton setTitle:TGLoc(@"settings.resources.autoplay")];
    [self.settingsStopInactiveAnimationsButton setTitle:TGLoc(@"settings.resources.stopInactive")];
    [self.settingsMaxAutoDownloadLabel setStringValue:TGLoc(@"settings.resources.maxDownload")];
    [self.settingsMaxAnimationsLabel setStringValue:TGLoc(@"settings.resources.maxAnimations")];
    [self.settingsMediaCacheLimitLabel setStringValue:TGLoc(@"settings.resources.cacheLimit")];
    [self.settingsResourceHintField setStringValue:TGLoc(@"settings.resources.hint")];
    [self.activeSessionsWindow setTitle:TGLoc(@"settings.section.sessions")];
    [self.activeSessionsRefreshButton setTitle:TGLoc(@"settings.sessions.refresh")];
    [self.activeSessionsTerminateButton setTitle:TGLoc(@"settings.sessions.terminate")];
    [self.activeSessionsCloseButton setTitle:TGLoc(@"close")];
    [self.profileRefreshButton setTitle:TGLoc(@"profile.refresh")];
    [self.settingsCheckUpdatesButton setTitle:TGLoc(@"settings.update")];
    [self.settingsAppearanceButton setTitle:@""];
    [self.settingsLogsButton setTitle:TGLoc(@"settings.logs")];
    [self.settingsAboutButton setTitle:TGLoc(@"settings.about")];
    [self.loginLogsButton setTitle:TGLoc(@"login.logs")];
    [self.loginLogsButton setToolTip:TGLoc(@"settings.logs")];
    [self.pinnedMessageLabelField setStringValue:TGLoc(@"pinned.title")];
    [self refreshLoginLocalizedText];
    [self refreshDownloadFolderButtonTitle];
    [self populateThemeCategoryPopUp];
    [self selectThemePopUpItemForIdentifier:TGCurrentThemeIdentifier()];
    [self selectLanguagePopUpItemForCode:TGLanguageCode()];
    [self updateSavedMessagesPresentationForChatItems];
    [self refreshLoginLanguageButtons];
    if ([[self.chatsNavigationContextMenu itemArray] count] > 0) {
        [[[self.chatsNavigationContextMenu itemArray] objectAtIndex:0] setTitle:TGLoc(@"chat.readAll")];
    }

    NSUInteger index = 0;
    for (index = 0; index < [self.navigationButtons count]; index++) {
        id candidate = [self.navigationButtons objectAtIndex:index];
        if (![candidate isKindOfClass:[NSButton class]]) {
            continue;
        }
        NSButton *button = (NSButton *)candidate;
        if ([button tag] == 0) {
            [button setTitle:TGLoc(@"chats")];
        } else if ([button tag] == 1) {
            [button setTitle:TGLoc(@"profile")];
        } else if ([button tag] == 2) {
            [button setTitle:TGLoc(@"settings")];
        }
        [button setToolTip:[button title]];
        [button setNeedsDisplay:YES];
    }
}

- (void)refreshThemeAppearance {
    NSColor *cardInkColor = TGClassicCardInkColor();
    NSColor *cardMutedColor = TGClassicCardMutedInkColor();

    [self.titleField setTextColor:TGClassicNavigationTextColor(1.0)];
    [self applyPanelHeaderDetailStyle:self.statusField];
    [self applyPanelHeaderLabelStyle:self.diagnosticsLabel];
    [self applyPanelHeaderLabelStyle:self.chatsLabel];
    [self applyPanelHeaderLabelStyle:self.messagesLabel];
    [self applyPanelHeaderLabelStyle:self.profileTitleField];
    [self applyPanelHeaderLabelStyle:self.settingsTitleField];
    [self applyPanelHeaderDetailStyle:self.selectedChatField];

    [self.loginBrandField setTextColor:TGClassicNavigationTextColor(1.0)];
    [self.loginTitleField setTextColor:cardInkColor];
    [self.sendLabel setTextColor:TGClassicInkColor()];
    [self.profileNameField setTextColor:cardInkColor];
    [self.profileNameField setFont:[NSFont boldSystemFontOfSize:18.0]];
    [self.profileUsernameField setFont:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsStateField];
    [self applyMutedLabelStyle:self.settingsDrawerSectionField];
    [self applyMutedLabelStyle:self.settingsResourceSectionField];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [self applyMutedLabelStyle:self.settingsFilesSectionField];
    [self applyMutedLabelStyle:self.settingsHelpSectionField];
    [self.aboutTitleField setTextColor:cardInkColor];
    [self.loginHintField setTextColor:cardMutedColor];
    [self.authLabel setTextColor:cardMutedColor];
    [self.authSecondaryLabel setTextColor:cardMutedColor];
    if (self.loginErrorVisible) {
        [self.authStateField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    } else {
        [self.authStateField setTextColor:cardMutedColor];
    }
    [self.profileUsernameField setTextColor:cardMutedColor];
    [self.profileIDField setTextColor:cardMutedColor];
    [self.profileStateField setTextColor:cardMutedColor];
    [self applyMutedLabelStyle:self.profileAboutSectionField];
    [self applyMutedLabelStyle:self.profileAccountSectionField];
    [self.profileStateField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profileAboutSectionField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profileAccountSectionField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profileUsernameRowTitleField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profileUsernameRowValueField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profilePhoneRowTitleField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profilePhoneRowValueField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profileIDRowTitleField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profileIDRowValueField setFont:[NSFont systemFontOfSize:13.0]];
    [self.profileUsernameRowTitleField setTextColor:cardInkColor];
    [self.profilePhoneRowTitleField setTextColor:cardInkColor];
    [self.profileIDRowTitleField setTextColor:cardInkColor];
    [self.profileUsernameRowValueField setTextColor:cardMutedColor];
    [self.profilePhoneRowValueField setTextColor:cardMutedColor];
    [self.profileIDRowValueField setTextColor:cardMutedColor];
    [self applyMutedLabelStyle:self.settingsLibraryField];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [self.settingsDownloadFolderHelpField setTextColor:cardMutedColor];
    [self.settingsActiveSessionsDetailField setTextColor:cardMutedColor];
    [self.settingsThemeCategoryLabel setTextColor:cardInkColor];
    [self.settingsThemeLabel setTextColor:cardInkColor];
    [self.settingsLanguageLabel setTextColor:cardInkColor];
    [self.pinnedMessageLabelField setTextColor:cardMutedColor];
    [self.pinnedMessageTextField setTextColor:cardInkColor];
    [self.settingsChatTextSizeSectionField setTextColor:cardInkColor];
    [self.settingsChatTextSizeValueField setTextColor:cardMutedColor];
    [self.settingsMaxAutoDownloadLabel setTextColor:cardInkColor];
    [self.settingsMaxAnimationsLabel setTextColor:cardInkColor];
    [self.settingsMediaCacheLimitLabel setTextColor:cardInkColor];
    [self.settingsResourceHintField setTextColor:cardMutedColor];
    [self.aboutVersionField setTextColor:cardMutedColor];
    [self.aboutCopyrightField setTextColor:cardMutedColor];
    [self.aboutLinkField setTextColor:TGClassicCardLinkColor()];
    NSArray *settingsSwitchButtons = [NSArray arrayWithObjects:
                                      self.settingsNotificationsEnabledButton,
                                      self.settingsNotificationSoundButton,
                                      self.settingsNotificationBadgeButton,
                                      self.settingsNotificationPreviewButton,
                                      self.settingsNotificationsWhenActiveButton,
                                      self.settingsDrawerHiddenButton,
                                      self.settingsTypingIndicatorsButton,
                                      self.settingsMessagesAsBlocksButton,
                                      self.settingsEconomyModeButton,
                                      self.settingsAutoDownloadPhotosButton,
                                      self.settingsAutoDownloadVideosButton,
                                      self.settingsAutoDownloadDocumentsButton,
                                      self.settingsAutoplayAnimatedStickersButton,
                                      self.settingsStopInactiveAnimationsButton,
                                      nil];
    NSUInteger settingsSwitchIndex = 0;
    for (settingsSwitchIndex = 0; settingsSwitchIndex < [settingsSwitchButtons count]; settingsSwitchIndex++) {
        [self applySettingsSwitchTextStyle:[settingsSwitchButtons objectAtIndex:settingsSwitchIndex]];
    }
    [self applyDestructiveSettingsButtonStyle:self.logoutButton];

    [self applyComposerTextFieldStyle:self.authTextField];
    [self applyComposerTextFieldStyle:self.authSecureField];
    [self.authTextFieldBackgroundView setNeedsDisplay:YES];
    [self.authSecondaryTextFieldBackgroundView setNeedsDisplay:YES];
    [self applyComposerTextFieldStyle:self.sendTextField];
    [self applyComposerPlaceholderStyle:self.sendTextField];
    [self.sendTextFieldBackgroundView setNeedsDisplay:YES];
    [self applyComposerTextFieldStyle:self.photoSendCaptionField];
    [self applyComposerPlaceholderStyle:self.photoSendCaptionField];
    [self.photoSendCaptionBackgroundView setNeedsDisplay:YES];
    [self.voiceRecordingIndicatorField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    [self.settingsAppearanceButton setNeedsDisplay:YES];
    [self.settingsLogsButton setNeedsDisplay:YES];
    [self.settingsAboutButton setNeedsDisplay:YES];
    [self.settingsDownloadFolderButton setNeedsDisplay:YES];
    [self.settingsStorageUsageButton setNeedsDisplay:YES];
    [self.settingsCheckUpdatesButton setNeedsDisplay:YES];
    [self.settingsActiveSessionsButton setNeedsDisplay:YES];
    [self.profileRefreshButton setNeedsDisplay:YES];
    [self.settingsAccountCardView setNeedsDisplay:YES];
    [self.settingsDrawerCardView setNeedsDisplay:YES];
    [self.settingsThemeCardView setNeedsDisplay:YES];
    [self.settingsSessionCardView setNeedsDisplay:YES];
    [self.settingsFilesCardView setNeedsDisplay:YES];
    [self.settingsResourceCardView setNeedsDisplay:YES];
    [self.settingsHelpCardView setNeedsDisplay:YES];
    [self.bottomNavigationView setNeedsDisplay:YES];
    if ([self.messageScrollSurfaceView isKindOfClass:[TGScrollSurfaceView class]]) {
        [(TGScrollSurfaceView *)self.messageScrollSurfaceView setDrawsInterior:!TGThemeIsSkeuomorphicBlue()];
    }
    [self.chatScrollSurfaceView setNeedsDisplay:YES];
    [self.messageScrollSurfaceView setNeedsDisplay:YES];
    [self applySkeuomorphicScrollStyle:self.detailsScrollView];
    [self applySkeuomorphicScrollStyle:self.chatScrollView];
    [self applySkeuomorphicScrollStyle:self.messageScrollView];
    [self.detailsView setTextColor:TGClassicMutedInkColor()];
    [self.detailsView setBackgroundColor:TGClassicTablePaperColor()];

    [self applySkeuomorphicTableStyle:self.chatTableView];
    [self applySkeuomorphicTableStyle:self.messageTableView];
    [self applyMessageTranscriptBackgroundStyle];
    [self applyTransparentChatTableStyle];
    [self.messageTableView setIntercellSpacing:NSMakeSize(0.0, 3.0)];
    [self.messageTableView setGridStyleMask:0];
    [self.messageTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];

    NSArray *tables = [NSArray arrayWithObjects:self.chatTableView, self.messageTableView, nil];
    NSUInteger tableIndex = 0;
    for (tableIndex = 0; tableIndex < [tables count]; tableIndex++) {
        NSTableView *tableView = [tables objectAtIndex:tableIndex];
        NSArray *columns = [tableView tableColumns];
        NSUInteger columnIndex = 0;
        for (columnIndex = 0; columnIndex < [columns count]; columnIndex++) {
            NSTableColumn *column = [columns objectAtIndex:columnIndex];
            [self applySkeuomorphicHeaderCellStyle:[column headerCell]];
        }
    }

    NSView *contentView = [[self window] contentView];
    [contentView setNeedsDisplay:YES];
    NSArray *subviews = [contentView subviews];
    NSUInteger viewIndex = 0;
    for (viewIndex = 0; viewIndex < [subviews count]; viewIndex++) {
        [[subviews objectAtIndex:viewIndex] setNeedsDisplay:YES];
    }
    [self.chatTableView reloadData];
    [self.messageTableView reloadData];
}

- (void)refreshProfileDisplay {
    NSString *displayName = TGProfileDisplayName(self.profileDisplayName);
    [self.accountBadgeView setDisplayName:displayName];
    [self.accountBadgeView setAvatarLocalPath:self.profileAvatarLocalPath];
    [self.accountBadgeView setConnected:[self.currentAuthState isEqualToString:@"ready"]];
    [self.profileAvatarView setDisplayName:displayName];
    [self.profileAvatarView setAvatarLocalPath:self.profileAvatarLocalPath];

    [self.profileNameField setStringValue:TGProfileFullName(self.profileDisplayName,
                                                            self.profileFirstName,
                                                            self.profileLastName,
                                                            TGLoc(@"profile.fallback"))];
    [self.settingsStateField setStringValue:TGLoc(@"settings.section.notifications")];

    [self.settingsLibraryField setStringValue:TGLoc(@"settings.appearance")];
    [self.profileUsernameRowValueField setStringValue:TGProfileUsernameText(self.profileUsername)];
    [self.profilePhoneRowValueField setStringValue:TGProfilePhoneText(self.profilePhoneNumber)];
    [self.profileIDRowValueField setStringValue:TGProfileIDText(self.profileUserID)];
    [self.profileUsernameField setStringValue:TGProfileSubtitleText(self.profileUsername, self.profileUserID)];

    [self.profileIDField setStringValue:@""];
    [self.profileStateField setStringValue:([self.profileBio length] > 0) ? self.profileBio : @""];
    [self.settingsStorageField setStringValue:TGLoc(@"settings.section.sessions")];
}

- (void)refreshSelectedChatHeaderDisplay {
    NSString *title = ([self.selectedChatTitle length] > 0) ? self.selectedChatTitle : @"Select a chat";
    [self.selectedChatField setStringValue:title];
    NSString *typingText = @"";
    if (TGUserDefaultBoolWithDefault(TGTypingIndicatorsEnabledDefaultsKey, YES) &&
        [self.typingIndicatorText length] > 0 &&
        [self.typingChatID respondsToSelector:@selector(longLongValue)] &&
        [self.selectedChatID respondsToSelector:@selector(longLongValue)] &&
        [self.typingChatID longLongValue] == [self.selectedChatID longLongValue]) {
        typingText = self.typingIndicatorText;
    }
    [self.typingIndicatorField setStringValue:typingText];
    [self.typingIndicatorField setHidden:([typingText length] == 0)];
    [self.selectedChatAvatarView setDisplayName:title];
    [self.selectedChatAvatarView setAvatarLocalPath:self.selectedChatAvatarLocalPath];
    [self.selectedChatProfileButton setToolTip:(self.selectedChatID ? @"Open chat profile" : @"Select a chat")];
    [self.selectedChatAvatarView setNeedsDisplay:YES];
}

- (void)clearTypingIndicator {
    [self.typingClearTimer invalidate];
    self.typingClearTimer = nil;
    self.typingChatID = nil;
    self.typingIndicatorText = nil;
    [self refreshSelectedChatHeaderDisplay];
    [self layoutContentView];
}

- (void)clearTypingIndicatorTimerFired:(NSTimer *)timer {
    (void)timer;
    [self clearTypingIndicator];
}

- (void)handleTypingUpdateSummary:(NSDictionary *)summary {
    if (![summary isKindOfClass:[NSDictionary class]]) {
        return;
    }
    NSNumber *chatID = [summary objectForKey:@"chat_id"];
    if (![chatID respondsToSelector:@selector(longLongValue)] ||
        ![self.selectedChatID respondsToSelector:@selector(longLongValue)] ||
        [chatID longLongValue] != [self.selectedChatID longLongValue]) {
        return;
    }

    NSNumber *threadID = [summary objectForKey:@"message_thread_id"];
    BOOL threadMatches = YES;
    if (self.selectedMessageThreadID) {
        threadMatches = ([threadID respondsToSelector:@selector(longLongValue)] &&
                         [threadID longLongValue] == [self.selectedMessageThreadID longLongValue]);
    } else if (self.showingForumTopicList) {
        threadMatches = NO;
    }
    if (!threadMatches) {
        return;
    }

    id activeObject = [summary objectForKey:@"active"];
    BOOL active = ([activeObject respondsToSelector:@selector(boolValue)] && [activeObject boolValue]);
    if (!active) {
        [self clearTypingIndicator];
        return;
    }

    self.typingChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
    self.typingIndicatorText = TGTypingIndicatorTextForSummary(summary,
                                                               self.selectedChatTypeSummary,
                                                               self.selectedChatTitle,
                                                               self.messageItems);
    [self.typingClearTimer invalidate];
    self.typingClearTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                             target:self
                                                           selector:@selector(clearTypingIndicatorTimerFired:)
                                                           userInfo:nil
                                                            repeats:NO];
    [self refreshSelectedChatHeaderDisplay];
    [self layoutContentView];
}

- (void)clearForumTopicListState {
    self.showingForumTopicList = NO;
    self.chatItemsBeforeTopicList = nil;
    self.topicParentChatID = nil;
    self.topicParentTitle = nil;
    self.topicParentAvatarLocalPath = nil;
    [self.chatsLabel setStringValue:TGLoc(@"chats")];
    [self.loadChatsButton setToolTip:TGLoc(@"settings.sessions.refresh")];
}

- (void)clearProfileDisplayCache {
    self.profileDisplayName = nil;
    self.profileFirstName = nil;
    self.profileLastName = nil;
    self.profileUsername = nil;
    self.profilePhoneNumber = nil;
    self.profileUserID = nil;
    self.profileAvatarLocalPath = nil;
    self.profileBio = nil;
    [self.profileStateField setStringValue:@""];
    [self.profileUsernameRowValueField setStringValue:@""];
    [self.profilePhoneRowValueField setStringValue:@""];
    [self.profileIDRowValueField setStringValue:@""];
    [self refreshProfileDisplay];
    [self layoutContentView];
}

- (void)buildContentView {
    TGChromeView *contentView = [[[TGChromeView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [[self window] setContentView:contentView];
    [contentView setAutoresizesSubviews:YES];

    self.topPanelView = [[[TGRailView alloc] initWithFrame:NSMakeRect(16, 628, 948, 56)] autorelease];
    [self.topPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.topPanelView];

    self.accountBadgeView = [[[TGAccountBadgeView alloc] initWithFrame:NSMakeRect(30, 626, 60, 60)] autorelease];
    [self.accountBadgeView setDisplayName:@"Telegraphica"];
    [self.accountBadgeView setTarget:self];
    [self.accountBadgeView setAction:@selector(openProfileFromDrawer:)];
    [self.accountBadgeView setToolTip:@"Open profile"];
    [self.accountBadgeView setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
    [contentView addSubview:self.accountBadgeView];

    self.drawerButton = [[[NSButton alloc] initWithFrame:NSMakeRect(18, 636, 34, 34)] autorelease];
    TGDrawerButtonCell *drawerCell = [[[TGDrawerButtonCell alloc] initTextCell:@""] autorelease];
    [drawerCell setButtonType:NSMomentaryPushInButton];
    [self.drawerButton setCell:drawerCell];
    [self.drawerButton setTitle:@""];
    [self.drawerButton setBordered:NO];
    [self.drawerButton setToolTip:@"Chat folders"];
    [self.drawerButton setTarget:self];
    [self.drawerButton setAction:@selector(toggleDrawer:)];
    [self.drawerButton setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
    [contentView addSubview:self.drawerButton];

    self.sidebarPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 286, 480)] autorelease];
    [self.sidebarPanelView setAutoresizingMask:(NSViewHeightSizable | NSViewMaxXMargin)];
    [contentView addSubview:self.sidebarPanelView];

    self.conversationPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(314, 132, 650, 480)] autorelease];
    [self.conversationPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.conversationPanelView];

    self.diagnosticsPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 16, 948, 104)] autorelease];
    [self.diagnosticsPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.diagnosticsPanelView];

    self.loginPanelView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(180, 150, 620, 360)] autorelease];
    [self.loginPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.loginPanelView];

    self.profilePanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.profilePanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.profilePanelView];

    self.profileScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(16, 132, 948, 420)] autorelease];
    [self.profileScrollView setBorderType:NSNoBorder];
    [self.profileScrollView setDrawsBackground:NO];
    [self.profileScrollView setHasVerticalScroller:YES];
    [self.profileScrollView setHasHorizontalScroller:NO];
    [self.profileScrollView setAutohidesScrollers:YES];
    [[self.profileScrollView contentView] setDrawsBackground:NO];
    self.profileContentView = [[[TGFlippedDocumentView alloc] initWithFrame:NSMakeRect(0, 0, 760, 520)] autorelease];
    [self.profileScrollView setDocumentView:self.profileContentView];
    [contentView addSubview:self.profileScrollView];

    self.settingsPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.settingsPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.settingsPanelView];

    self.settingsScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(16, 132, 948, 420)] autorelease];
    [self.settingsScrollView setBorderType:NSNoBorder];
    [self.settingsScrollView setDrawsBackground:NO];
    [self.settingsScrollView setHasVerticalScroller:YES];
    [self.settingsScrollView setHasHorizontalScroller:NO];
    [self.settingsScrollView setAutohidesScrollers:YES];
    [[self.settingsScrollView contentView] setDrawsBackground:NO];
    self.settingsContentView = [[[TGFlippedDocumentView alloc] initWithFrame:NSMakeRect(0, 0, 760, 620)] autorelease];
    [self.settingsScrollView setDocumentView:self.settingsContentView];
    [contentView addSubview:self.settingsScrollView];

    self.aboutPanelView = [[[TGPanelView alloc] initWithFrame:NSMakeRect(16, 132, 948, 480)] autorelease];
    [self.aboutPanelView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.aboutPanelView];

    self.bottomNavigationView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(126, 18, 276, 54)] autorelease];
    [self.bottomNavigationView setAutoresizingMask:(NSViewMaxXMargin | NSViewMaxYMargin)];
    [contentView addSubview:self.bottomNavigationView];

    self.titleField = [self labelWithFrame:NSMakeRect(24, 668, 712, 28)
                                      text:@"Telegraphica"
                                      font:[NSFont boldSystemFontOfSize:20.0]];
    [self.titleField setTextColor:[NSColor colorWithCalibratedWhite:0.98 alpha:1.0]];
    [self.titleField setHidden:YES];
    [contentView addSubview:self.titleField];

    self.statusField = [self labelWithFrame:NSMakeRect(24, 636, 712, 22)
                                     text:@"Connecting..."
                                     font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderDetailStyle:self.statusField];
    [self.statusField setHidden:YES];
    [contentView addSubview:self.statusField];

    NSArray *navigationTitles = [NSArray arrayWithObjects:@"Chats", @"Profile", @"Settings", nil];
    NSInteger navigationTags[] = {0, 1, 2};
    NSMutableArray *navigationButtons = [NSMutableArray arrayWithCapacity:[navigationTitles count]];
    NSUInteger navigationIndex = 0;
    for (navigationIndex = 0; navigationIndex < [navigationTitles count]; navigationIndex++) {
        NSString *buttonTitle = [navigationTitles objectAtIndex:navigationIndex];
        NSButton *navigationButton = [[[NSButton alloc] initWithFrame:NSMakeRect(260 + (navigationIndex * 82), 636, 78, 28)] autorelease];
        TGNavigationButtonCell *navigationCell = [[[TGNavigationButtonCell alloc] initTextCell:buttonTitle] autorelease];
        [navigationCell setButtonType:NSToggleButton];
        [navigationButton setCell:navigationCell];
        [navigationButton setTitle:buttonTitle];
        [navigationButton setButtonType:NSToggleButton];
        [navigationButton setBordered:NO];
        [navigationButton setTag:navigationTags[navigationIndex]];
        [navigationButton setToolTip:buttonTitle];
        [navigationButton setTarget:self];
        [navigationButton setAction:@selector(navigationChanged:)];
        [navigationButton setAutoresizingMask:(NSViewMinXMargin | NSViewMinYMargin)];
        if (navigationTags[navigationIndex] == 0) {
            NSMenu *readAllMenu = [[[NSMenu alloc] initWithTitle:@"Chats"] autorelease];
            NSMenuItem *readAllItem = [[[NSMenuItem alloc] initWithTitle:TGLoc(@"chat.readAll")
                                                                   action:@selector(markAllChatsReadFromMenu:)
                                                            keyEquivalent:@""] autorelease];
            [readAllItem setTarget:self];
            [readAllMenu addItem:readAllItem];
            self.chatsNavigationContextMenu = readAllMenu;
            [navigationButton setMenu:readAllMenu];
        }
        [contentView addSubview:navigationButton];
        [navigationButtons addObject:navigationButton];
    }
    self.navigationButtons = navigationButtons;

    self.markAllChatsReadSpinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(0, 0, 14, 14)] autorelease];
    [self.markAllChatsReadSpinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.markAllChatsReadSpinner setControlSize:NSSmallControlSize];
    [self.markAllChatsReadSpinner setDisplayedWhenStopped:NO];
    [self.markAllChatsReadSpinner setHidden:YES];
    [contentView addSubview:self.markAllChatsReadSpinner];

    self.drawerFolderButtons = [NSArray array];

    self.logsCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(24, 410, 712, 210)] autorelease];
    [self.logsCardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.logsCardView];

    self.detailsScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 410, 712, 210)] autorelease];
    [self.detailsScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [self applySkeuomorphicScrollStyle:self.detailsScrollView];

    self.detailsView = [[[NSTextView alloc] initWithFrame:[[self.detailsScrollView contentView] bounds]] autorelease];
    [self.detailsView setEditable:NO];
    [self.detailsView setSelectable:YES];
    [self.detailsView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
    [self.detailsView setTextColor:TGClassicMutedInkColor()];
    [self.detailsView setBackgroundColor:TGClassicTablePaperColor()];
    [self.detailsView setString:@"Diagnostic Logs\n"];
    [self.detailsScrollView setDocumentView:self.detailsView];
    [contentView addSubview:self.detailsScrollView];

    self.diagnosticsLabel = [self labelWithFrame:NSMakeRect(24, 104, 112, 18)
                                            text:@"Diagnostic Logs"
                                            font:[NSFont boldSystemFontOfSize:11.0]];
    [self applyPanelHeaderLabelStyle:self.diagnosticsLabel];
    [contentView addSubview:self.diagnosticsLabel];

    self.loginIconView = [[[NSImageView alloc] initWithFrame:NSMakeRect(454, 548, 72, 72)] autorelease];
    [self.loginIconView setImageScaling:NSImageScaleProportionallyUpOrDown];
    NSString *loginIconPath = [[NSBundle mainBundle] pathForResource:@"TelegraphicaAppIcon" ofType:@"icns"];
    if ([loginIconPath length] > 0) {
        NSImage *loginIcon = [[[NSImage alloc] initWithContentsOfFile:loginIconPath] autorelease];
        [self.loginIconView setImage:loginIcon];
    } else {
        [self.loginIconView setImage:[NSImage imageNamed:@"NSApplicationIcon"]];
    }
    [self.loginIconView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin)];
    [contentView addSubview:self.loginIconView];

    self.loginBrandField = [self labelWithFrame:NSMakeRect(300, 516, 380, 28)
                                           text:@"Telegraphica"
                                           font:[NSFont boldSystemFontOfSize:22.0]];
    [self.loginBrandField setAlignment:NSCenterTextAlignment];
    [self.loginBrandField setTextColor:TGClassicNavigationTextColor(1.0)];
    [self.loginBrandField setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin)];
    [contentView addSubview:self.loginBrandField];

    self.loginTitleField = [self labelWithFrame:NSMakeRect(230, 430, 520, 26)
                                           text:@"Sign in"
                                           font:[NSFont boldSystemFontOfSize:21.0]];
    [self.loginTitleField setAlignment:NSCenterTextAlignment];
    [self.loginTitleField setTextColor:TGClassicInkColor()];
    [contentView addSubview:self.loginTitleField];

    self.loginHintField = [self labelWithFrame:NSMakeRect(250, 392, 480, 44)
                                          text:@"Telegraphica will connect automatically. If this Mac is not signed in yet, continue with your phone number, login code, and password."
                                          font:[NSFont systemFontOfSize:12.0]];
    [self.loginHintField setAlignment:NSCenterTextAlignment];
    [[self.loginHintField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.loginHintField];
    [contentView addSubview:self.loginHintField];

    self.authLabel = [self labelWithFrame:NSMakeRect(24, 374, 76, 22)
                                     text:@"Auth:"
                                     font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.authLabel];
    [contentView addSubview:self.authLabel];

    self.authStateField = [self labelWithFrame:NSMakeRect(104, 374, 560, 22)
                                          text:@"not checked"
                                          font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.authStateField];
    [[self.authStateField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.authStateField];

    self.authTextFieldBackgroundView = [[[TGAuthInputBackgroundView alloc] initWithFrame:NSMakeRect(104, 370, 240, 30)] autorelease];
    [self.authTextFieldBackgroundView setHidden:YES];
    [self.authTextFieldBackgroundView setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authTextFieldBackgroundView];

    self.authTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authTextField setEnabled:NO];
    [self.authTextField setHidden:YES];
    [self applyComposerTextFieldStyle:self.authTextField];
    [self.authTextField setDelegate:(id)self];
    [self.authTextField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authTextField];

    self.authSecureField = [[[NSSecureTextField alloc] initWithFrame:NSMakeRect(104, 370, 240, 24)] autorelease];
    [self.authSecureField setEnabled:NO];
    [self.authSecureField setHidden:YES];
    [self applyComposerTextFieldStyle:self.authSecureField];
    [self.authSecureField setDelegate:(id)self];
    [self.authSecureField setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authSecureField];

    self.authSecondaryLabel = [self labelWithFrame:NSMakeRect(24, 336, 76, 22)
                                              text:@"API Hash"
                                              font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.authSecondaryLabel];
    [self.authSecondaryLabel setHidden:YES];
    [contentView addSubview:self.authSecondaryLabel];

    self.authSecondaryTextFieldBackgroundView = [[[TGAuthInputBackgroundView alloc] initWithFrame:NSMakeRect(104, 330, 240, 30)] autorelease];
    [self.authSecondaryTextFieldBackgroundView setHidden:YES];
    [self.authSecondaryTextFieldBackgroundView setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authSecondaryTextFieldBackgroundView];

    self.authButton = [[[NSButton alloc] initWithFrame:NSMakeRect(356, 366, 116, 32)] autorelease];
    [self.authButton setTitle:TGLoc(@"login.send")];
    [self.authButton setTarget:self];
    [self.authButton setAction:@selector(submitAuthInput:)];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self applySkeuomorphicButtonStyle:self.authButton isPrimary:YES];
    [self.authButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.authButton];

    self.busySpinner = [[[TGTransparentSpinnerView alloc] initWithFrame:NSMakeRect(760, 374, 16, 16)] autorelease];
    [self.busySpinner setDisplayedWhenStopped:NO];
    [self.busySpinner setHidden:YES];
    [contentView addSubview:self.busySpinner];

    self.loginLogsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(894, 20, 70, 28)] autorelease];
    [self.loginLogsButton setTitle:@"Logs"];
    [self.loginLogsButton setToolTip:@"Open diagnostic logs"];
    [self.loginLogsButton setTarget:self];
    [self.loginLogsButton setAction:@selector(showLogsWindow:)];
    [self applyUtilityButtonStyle:self.loginLogsButton];
    [self.loginLogsButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [contentView addSubview:self.loginLogsButton];

    NSArray *loginLanguageTitles = [NSArray arrayWithObjects:@"RU", @"EN", @"BE", nil];
    NSMutableArray *loginLanguageButtons = [NSMutableArray arrayWithCapacity:[loginLanguageTitles count]];
    NSUInteger loginLanguageIndex = 0;
    for (loginLanguageIndex = 0; loginLanguageIndex < [loginLanguageTitles count]; loginLanguageIndex++) {
        NSButton *languageButton = [[[NSButton alloc] initWithFrame:NSMakeRect(18.0 + (loginLanguageIndex * 48.0), 26.0, 42.0, 26.0)] autorelease];
        [languageButton setTitle:[loginLanguageTitles objectAtIndex:loginLanguageIndex]];
        [languageButton setTag:(NSInteger)loginLanguageIndex];
        [languageButton setTarget:self];
        [languageButton setAction:@selector(loginLanguageChanged:)];
        [languageButton setToolTip:(loginLanguageIndex == 0 ? @"Русский" : (loginLanguageIndex == 1 ? @"English" : @"Беларуская"))];
        [self applyUtilityButtonStyle:languageButton];
        [languageButton setAutoresizingMask:(NSViewMaxXMargin | NSViewMaxYMargin)];
        [contentView addSubview:languageButton];
        [loginLanguageButtons addObject:languageButton];
    }
    self.loginLanguageButtons = loginLanguageButtons;

    self.chatsLabel = [self labelWithFrame:NSMakeRect(24, 338, 76, 22)
                                      text:TGLoc(@"chats")
                                      font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderLabelStyle:self.chatsLabel];
    [contentView addSubview:self.chatsLabel];

    self.loadChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(104, 332, 112, 32)] autorelease];
    [self.loadChatsButton setTitle:@"↻"];
    [self.loadChatsButton setToolTip:@"Refresh chats"];
    [self.loadChatsButton setTarget:self];
    [self.loadChatsButton setAction:@selector(loadChats:)];
    [self.loadChatsButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.loadChatsButton];
    [self.loadChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadChatsButton];

    self.loadMoreChatsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(224, 332, 80, 32)] autorelease];
    [self.loadMoreChatsButton setTitle:@"+"];
    [self.loadMoreChatsButton setToolTip:@"Load more chats"];
    [self.loadMoreChatsButton setTarget:self];
    [self.loadMoreChatsButton setAction:@selector(loadMoreChats:)];
    [self.loadMoreChatsButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.loadMoreChatsButton];
    [self.loadMoreChatsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMoreChatsButton];

    self.chatSearchButton = [[[NSButton alloc] initWithFrame:NSMakeRect(188, 332, 32, 32)] autorelease];
    [self.chatSearchButton setTitle:@"search"];
    [self.chatSearchButton setToolTip:@"Search all chats"];
    [self.chatSearchButton setTarget:self];
    [self.chatSearchButton setAction:@selector(openChatListSearch:)];
    [self.chatSearchButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.chatSearchButton];
    [self.chatSearchButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.chatSearchButton];

    self.mediaCenterButton = [[[TGHeaderActionButton alloc] initWithFrame:NSMakeRect(700, 332, 32, 32)] autorelease];
    [self.mediaCenterButton setTitle:@"media-center"];
    [self.mediaCenterButton setToolTip:TGLoc(@"media.center.title")];
    [self.mediaCenterButton setTarget:self];
    [self.mediaCenterButton setAction:@selector(openMediaCenter:)];
    [self.mediaCenterButton setEnabled:NO];
    [self.mediaCenterButton setHidden:YES];
    [self applyHeaderIconButtonStyle:self.mediaCenterButton];
    [self.mediaCenterButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.mediaCenterButton];

    self.topicBackButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 332, 32, 32)] autorelease];
    [self.topicBackButton setTitle:@"‹"];
    [self.topicBackButton setToolTip:@"Back to chats"];
    [self.topicBackButton setTarget:self];
    [self.topicBackButton setAction:@selector(closeForumTopicList:)];
    [self.topicBackButton setEnabled:YES];
    [self applyHeaderIconButtonStyle:self.topicBackButton];
    [self.topicBackButton setAutoresizingMask:NSViewMaxYMargin];
    [self.topicBackButton setHidden:YES];
    [contentView addSubview:self.topicBackButton];

    self.commentThreadBackButton = [[[NSButton alloc] initWithFrame:NSMakeRect(228, 192, 32, 32)] autorelease];
    [self.commentThreadBackButton setTitle:@"‹"];
    [self.commentThreadBackButton setToolTip:@"Back to channel"];
    [self.commentThreadBackButton setTarget:self];
    [self.commentThreadBackButton setAction:@selector(closeMessageCommentsThread:)];
    [self.commentThreadBackButton setEnabled:YES];
    [self applyHeaderIconButtonStyle:self.commentThreadBackButton];
    [self.commentThreadBackButton setAutoresizingMask:NSViewMaxYMargin];
    [self.commentThreadBackButton setHidden:YES];
    [contentView addSubview:self.commentThreadBackButton];

    self.chatScrollSurfaceView = [[[TGScrollSurfaceView alloc] initWithFrame:NSMakeRect(24, 232, 712, 96)] autorelease];
    [self.chatScrollSurfaceView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.chatScrollSurfaceView];

    self.chatScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 232, 712, 96)] autorelease];
    [self.chatScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [self applySkeuomorphicScrollStyle:self.chatScrollView];

    self.chatTableView = [[[NSTableView alloc] initWithFrame:[[self.chatScrollView contentView] bounds]] autorelease];
    [self.chatTableView setDataSource:self];
    [self.chatTableView setDelegate:self];
    [self.chatTableView setTarget:self];
    [self.chatTableView setAction:@selector(activateSelectedChatRow:)];
    [self.chatTableView setDoubleAction:@selector(activateSelectedChatRow:)];
    [self.chatTableView setAllowsColumnReordering:NO];
    [self.chatTableView setAllowsMultipleSelection:NO];
    [self.chatTableView setRowHeight:38.0];
    [self applySkeuomorphicTableStyle:self.chatTableView];
    [self applyTransparentChatTableStyle];
    [self.chatTableView setHeaderView:nil];

    self.chatContextMenu = [[[NSMenu alloc] initWithTitle:@"Chat"] autorelease];
    [self.chatContextMenu setDelegate:self];
    [self.chatTableView setMenu:self.chatContextMenu];

    NSTableColumn *chatColumn = [[[NSTableColumn alloc] initWithIdentifier:@"chat"] autorelease];
    [[chatColumn headerCell] setStringValue:@"Chat"];
    TGChatListCell *chatCell = [[[TGChatListCell alloc] initTextCell:@""] autorelease];
    [chatCell setEditable:NO];
    [chatCell setSelectable:NO];
    [chatColumn setDataCell:chatCell];
    [chatColumn setWidth:470.0];
    [self.chatTableView addTableColumn:chatColumn];

    [self.chatScrollView setDocumentView:self.chatTableView];
    [[self.chatScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(chatScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.chatScrollView contentView]];
    [contentView addSubview:self.chatScrollView];

    self.messagesLabel = [self labelWithFrame:NSMakeRect(24, 198, 86, 22)
                                         text:@"Conversation"
                                         font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderLabelStyle:self.messagesLabel];
    [contentView addSubview:self.messagesLabel];

    self.loadMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(116, 192, 136, 32)] autorelease];
    [self.loadMessagesButton setTitle:@"↻"];
    [self.loadMessagesButton setToolTip:@"Reload messages"];
    [self.loadMessagesButton setTarget:self];
    [self.loadMessagesButton setAction:@selector(loadMessages:)];
    [self.loadMessagesButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.loadMessagesButton];
    [self.loadMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadMessagesButton];

    self.loadOlderMessagesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(264, 192, 112, 32)] autorelease];
    [self.loadOlderMessagesButton setTitle:@"↑"];
    [self.loadOlderMessagesButton setToolTip:@"Load older messages"];
    [self.loadOlderMessagesButton setTarget:self];
    [self.loadOlderMessagesButton setAction:@selector(loadOlderMessages:)];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.loadOlderMessagesButton];
    [self.loadOlderMessagesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.loadOlderMessagesButton];

    self.conversationSearchButton = [[[NSButton alloc] initWithFrame:NSMakeRect(228, 192, 32, 32)] autorelease];
    [self.conversationSearchButton setTitle:@"search"];
    [self.conversationSearchButton setToolTip:@"Search in this chat"];
    [self.conversationSearchButton setTarget:self];
    [self.conversationSearchButton setAction:@selector(openChatSearch:)];
    [self.conversationSearchButton setEnabled:NO];
    [self applyHeaderIconButtonStyle:self.conversationSearchButton];
    [self.conversationSearchButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.conversationSearchButton];

    self.selectedChatField = [self labelWithFrame:NSMakeRect(264, 198, 472, 22)
                                             text:@"Select a chat"
                                             font:[NSFont systemFontOfSize:13.0]];
    [self applyPanelHeaderDetailStyle:self.selectedChatField];
    [[self.selectedChatField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.selectedChatField];

    self.typingIndicatorField = [self labelWithFrame:NSMakeRect(264, 184, 472, 16)
                                                text:@""
                                                font:[NSFont systemFontOfSize:10.0]];
    [self applyPanelHeaderDetailStyle:self.typingIndicatorField];
    [self.typingIndicatorField setFont:[NSFont systemFontOfSize:10.0]];
    [self.typingIndicatorField setAlphaValue:0.85];
    [[self.typingIndicatorField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.typingIndicatorField setHidden:YES];
    [contentView addSubview:self.typingIndicatorField];

    self.selectedChatAvatarView = [[[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(232, 194, 26, 26)] autorelease];
    [self.selectedChatAvatarView setDisplayName:@"Select a chat"];
    [self.selectedChatAvatarView setHidden:YES];
    [contentView addSubview:self.selectedChatAvatarView];

    self.selectedChatProfileButton = [[[NSButton alloc] initWithFrame:NSMakeRect(232, 194, 400, 28)] autorelease];
    [self.selectedChatProfileButton setTitle:@""];
    [self.selectedChatProfileButton setBordered:NO];
    [self.selectedChatProfileButton setTransparent:YES];
    [self.selectedChatProfileButton setTarget:self];
    [self.selectedChatProfileButton setAction:@selector(openSelectedChatProfile:)];
    [self.selectedChatProfileButton setToolTip:@"Open chat profile"];
    [self.selectedChatProfileButton setHidden:YES];
    [contentView addSubview:self.selectedChatProfileButton];

    self.messageScrollSurfaceView = [[[TGScrollSurfaceView alloc] initWithFrame:NSMakeRect(24, 72, 712, 112)] autorelease];
    [(TGScrollSurfaceView *)self.messageScrollSurfaceView setDrawsInterior:!TGThemeIsSkeuomorphicBlue()];
    [self.messageScrollSurfaceView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.messageScrollSurfaceView];

    self.messageScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(24, 72, 712, 112)] autorelease];
    [self.messageScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [self applySkeuomorphicScrollStyle:self.messageScrollView];

    TGMessageTableView *messageTableView = [[[TGMessageTableView alloc] initWithFrame:[[self.messageScrollView contentView] bounds]] autorelease];
    [messageTableView setDropOverlayTarget:self];
    self.messageTableView = messageTableView;
    [self.messageTableView setDataSource:self];
    [self.messageTableView setDelegate:self];
    [self.messageTableView setAllowsColumnReordering:NO];
    [self.messageTableView setAllowsMultipleSelection:NO];
    [self.messageTableView setTarget:self];
    [self.messageTableView setAction:@selector(openMessageLink:)];
    [self.messageTableView setDoubleAction:@selector(reactToMessageWithDefaultReaction:)];
    [self.messageTableView setRowHeight:52.0];
    [self.messageTableView setIntercellSpacing:NSMakeSize(0.0, 3.0)];
    [self applySkeuomorphicTableStyle:self.messageTableView];
    [self applyMessageTranscriptBackgroundStyle];
    [self.messageTableView setIntercellSpacing:NSMakeSize(0.0, 3.0)];
    [self.messageTableView setGridStyleMask:0];
    [self.messageTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [self.messageTableView setHeaderView:nil];
    [self.messageTableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];

    self.messageContextMenu = [[[NSMenu alloc] initWithTitle:@"Message"] autorelease];
    [self.messageContextMenu setDelegate:self];
    [self.messageTableView setMenu:self.messageContextMenu];

    NSTableColumn *bubbleColumn = [[[NSTableColumn alloc] initWithIdentifier:@"bubble"] autorelease];
    [[bubbleColumn headerCell] setStringValue:@"Conversation"];
    TGMessageBubbleCell *bubbleCell = [[[TGMessageBubbleCell alloc] initTextCell:@""] autorelease];
    [bubbleCell setEditable:NO];
    [bubbleCell setSelectable:NO];
    [bubbleColumn setDataCell:bubbleCell];
    [bubbleColumn setWidth:500.0];
    [self.messageTableView addTableColumn:bubbleColumn];

    [self.messageScrollView setDocumentView:self.messageTableView];
    self.inlineMediaPlaybackCoordinator = [[[TGInlineMediaPlaybackCoordinator alloc] initWithHostView:self.messageTableView
                                                                                  maximumActiveItems:5] autorelease];
    [[self.messageScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(messageScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.messageScrollView contentView]];
    [contentView addSubview:self.messageScrollView];

    self.messageLoadingSpinner = [[[TGTransparentSpinnerView alloc] initWithFrame:NSMakeRect(0, 0, 24, 24)] autorelease];
    [self.messageLoadingSpinner setDisplayedWhenStopped:NO];
    [self.messageLoadingSpinner setHidden:YES];
    [self.messageLoadingSpinner setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    [contentView addSubview:self.messageLoadingSpinner];

    self.messageJumpToNewestButton = [[[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 34, 34)] autorelease];
    [self.messageJumpToNewestButton setTitle:@"jump-newest"];
    [self.messageJumpToNewestButton setToolTip:@"Jump to latest messages"];
    [self.messageJumpToNewestButton setTarget:self];
    [self.messageJumpToNewestButton setAction:@selector(jumpToNewestMessages:)];
    [self.messageJumpToNewestButton setBordered:NO];
    [self.messageJumpToNewestButton setFocusRingType:NSFocusRingTypeNone];
    [self.messageJumpToNewestButton setCell:[[[TGHeaderIconButtonCell alloc] initTextCell:@"jump-newest"] autorelease]];
    [self.messageJumpToNewestButton setTarget:self];
    [self.messageJumpToNewestButton setAction:@selector(jumpToNewestMessages:)];
    [self.messageJumpToNewestButton sendActionOn:NSLeftMouseUpMask];
    [self.messageJumpToNewestButton setEnabled:NO];
    [self.messageJumpToNewestButton setHidden:YES];
    [contentView addSubview:self.messageJumpToNewestButton];

    self.closedChatPlaceholderView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(0, 0, 420, 212)] autorelease];
    [self.closedChatPlaceholderView setHidden:YES];
    [self.closedChatPlaceholderView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin)];
    [contentView addSubview:self.closedChatPlaceholderView];

    self.closedChatTitleField = [self labelWithFrame:NSMakeRect(0, 0, 360, 24)
                                                text:TGLoc(@"closedChats.title")
                                                font:[NSFont boldSystemFontOfSize:15.0]];
    [self.closedChatTitleField setAlignment:NSCenterTextAlignment];
    [self.closedChatTitleField setAutoresizingMask:NSViewWidthSizable];
    [self.closedChatPlaceholderView addSubview:self.closedChatTitleField];

    self.closedChatHintField = [self labelWithFrame:NSMakeRect(0, 0, 360, 34)
                                               text:TGLoc(@"closedChats.hint")
                                               font:[NSFont systemFontOfSize:12.0]];
    [self.closedChatHintField setAlignment:NSCenterTextAlignment];
    [self.closedChatHintField setTextColor:TGClassicMutedInkColor()];
    [[self.closedChatHintField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self.closedChatHintField setAutoresizingMask:NSViewWidthSizable];
    [self.closedChatPlaceholderView addSubview:self.closedChatHintField];

    self.messageDropOverlayView = [[[TGDropOverlayView alloc] initWithFrame:NSMakeRect(42, 90, 672, 84)] autorelease];
    [self.messageDropOverlayView setHidden:YES];
    [self.messageDropOverlayView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.messageDropOverlayView];

    self.pinnedMessagePanelView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(24, 180, 600, 42)] autorelease];
    [self.pinnedMessagePanelView setHidden:YES];
    [contentView addSubview:self.pinnedMessagePanelView];

    self.pinnedMessageStripeField = [self labelWithFrame:NSMakeRect(32, 182, 8, 40)
                                                    text:@""
                                                    font:[NSFont boldSystemFontOfSize:14.0]];
    [self.pinnedMessageStripeField setTextColor:TGClassicNavigationSelectedColor(0.92)];
    [self.pinnedMessageStripeField setHidden:YES];
    [contentView addSubview:self.pinnedMessageStripeField];

    self.pinnedMessageLabelField = [self labelWithFrame:NSMakeRect(44, 190, 90, 16)
                                                   text:TGLoc(@"pinned.title")
                                                   font:[NSFont boldSystemFontOfSize:10.0]];
    [self.pinnedMessageLabelField setTextColor:TGClassicMutedInkColor()];
    [contentView addSubview:self.pinnedMessageLabelField];

    self.pinnedMessageTextField = [self labelWithFrame:NSMakeRect(44, 174, 520, 18)
                                                  text:@""
                                                  font:[NSFont systemFontOfSize:12.0]];
    [self.pinnedMessageTextField setTextColor:TGClassicInkColor()];
    [[self.pinnedMessageTextField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.pinnedMessageTextField];

    self.pinnedMessageButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 180, 600, 42)] autorelease];
    [self.pinnedMessageButton setTitle:@""];
    [self.pinnedMessageButton setBordered:NO];
    [self.pinnedMessageButton setTransparent:YES];
    [self.pinnedMessageButton setTarget:self];
    [self.pinnedMessageButton setAction:@selector(jumpToPinnedMessage:)];
    [self.pinnedMessageButton setToolTip:@"Jump to pinned message"];
    [self.pinnedMessageButton setHidden:YES];
    [contentView addSubview:self.pinnedMessageButton];

    self.replyPanelView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(24, 88, 600, 44)] autorelease];
    [self.replyPanelView setHidden:YES];
    [contentView addSubview:self.replyPanelView];

    self.replyPanelTitleField = [self labelWithFrame:NSMakeRect(38, 112, 500, 15)
                                                text:@"Reply"
                                                font:[NSFont boldSystemFontOfSize:10.0]];
    [self.replyPanelTitleField setTextColor:TGClassicNavigationSelectedColor(0.95)];
    [self.replyPanelTitleField setHidden:YES];
    [contentView addSubview:self.replyPanelTitleField];

    self.replyPanelTextField = [self labelWithFrame:NSMakeRect(38, 95, 500, 17)
                                               text:@""
                                               font:[NSFont systemFontOfSize:11.0]];
    [self.replyPanelTextField setTextColor:TGClassicMutedInkColor()];
    [[self.replyPanelTextField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.replyPanelTextField setHidden:YES];
    [contentView addSubview:self.replyPanelTextField];

    self.replyPanelCancelButton = [[[TGReplyCancelButton alloc] initWithFrame:NSMakeRect(24, 96, 38, 32)] autorelease];
    [self.replyPanelCancelButton setTitle:@""];
    [self.replyPanelCancelButton setBordered:NO];
    [self.replyPanelCancelButton setTransparent:YES];
    [self.replyPanelCancelButton setButtonType:NSMomentaryPushInButton];
    [self.replyPanelCancelButton setImage:nil];
    [self.replyPanelCancelButton setImagePosition:NSNoImage];
    [self.replyPanelCancelButton setTarget:self];
    [self.replyPanelCancelButton setAction:@selector(cancelReplyTarget:)];
    [self.replyPanelCancelButton setToolTip:@"Cancel reply"];
    [self.replyPanelCancelButton setHidden:YES];
    [contentView addSubview:self.replyPanelCancelButton];

    self.searchPanelView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(24, 180, 600, 180)] autorelease];
    [self.searchPanelView setHidden:YES];
    [contentView addSubview:self.searchPanelView];

    self.searchTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(36, 318, 260, 24)] autorelease];
    [[self.searchTextField cell] setPlaceholderString:@"Search"];
    [self.searchTextField setTarget:self];
    [self.searchTextField setAction:@selector(searchTextCommitted:)];
    [self.searchTextField setDelegate:(id)self];
    [self.searchTextField setHidden:YES];
    [contentView addSubview:self.searchTextField];

    self.searchScopePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(304, 318, 132, 26) pullsDown:NO] autorelease];
    [self.searchScopePopUpButton addItemWithTitle:@"В этом чате"];
    [self.searchScopePopUpButton addItemWithTitle:@"Во всех чатах"];
    [self.searchScopePopUpButton setTarget:self];
    [self.searchScopePopUpButton setAction:@selector(searchScopeChanged:)];
    [self.searchScopePopUpButton setHidden:YES];
    [contentView addSubview:self.searchScopePopUpButton];

    self.searchFilterPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(442, 318, 112, 26) pullsDown:NO] autorelease];
    [self.searchFilterPopUpButton addItemWithTitle:@"Все"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Фото"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Видео"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Документы"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Ссылки"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Голосовые"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Аудио"];
    [self.searchFilterPopUpButton addItemWithTitle:@"GIF"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Кружки"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Стикеры"];
    [self.searchFilterPopUpButton addItemWithTitle:@"Опросы"];
    [self.searchFilterPopUpButton setTarget:self];
    [self.searchFilterPopUpButton setAction:@selector(searchFilterChanged:)];
    [self.searchFilterPopUpButton setHidden:YES];
    [contentView addSubview:self.searchFilterPopUpButton];

    self.searchCloseButton = [[[NSButton alloc] initWithFrame:NSMakeRect(560, 318, 32, 26)] autorelease];
    [self.searchCloseButton setTitle:@"×"];
    [self.searchCloseButton setToolTip:@"Close search"];
    [self.searchCloseButton setTarget:self];
    [self.searchCloseButton setAction:@selector(closeSearchPanel:)];
    [self applyUtilityButtonStyle:self.searchCloseButton];
    [self.searchCloseButton setHidden:YES];
    [contentView addSubview:self.searchCloseButton];

    self.searchStatusField = [self labelWithFrame:NSMakeRect(36, 296, 540, 18)
                                             text:@"Введите запрос"
                                             font:[NSFont systemFontOfSize:11.0]];
    [self.searchStatusField setTextColor:TGClassicMutedInkColor()];
    [self.searchStatusField setHidden:YES];
    [contentView addSubview:self.searchStatusField];

    self.searchResultsScrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(36, 190, 540, 102)] autorelease];
    [self applySkeuomorphicScrollStyle:self.searchResultsScrollView];
    [self.searchResultsScrollView setHasVerticalScroller:YES];
    [self.searchResultsScrollView setHidden:YES];
    [[self.searchResultsScrollView contentView] setPostsBoundsChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(searchResultsScrollViewDidScroll:)
                                                 name:NSViewBoundsDidChangeNotification
                                               object:[self.searchResultsScrollView contentView]];
    self.searchResultsTableView = [[[NSTableView alloc] initWithFrame:[[self.searchResultsScrollView contentView] bounds]] autorelease];
    [self.searchResultsTableView setDataSource:self];
    [self.searchResultsTableView setDelegate:self];
    [self.searchResultsTableView setTarget:self];
    [self.searchResultsTableView setAction:@selector(activateSearchResult:)];
    [self.searchResultsTableView setDoubleAction:@selector(activateSearchResult:)];
    [self.searchResultsTableView setRowHeight:44.0];
    [self.searchResultsTableView setHeaderView:nil];
    NSTableColumn *searchColumn = [[[NSTableColumn alloc] initWithIdentifier:@"search"] autorelease];
    [[searchColumn headerCell] setStringValue:@"Search"];
    [searchColumn setWidth:520.0];
    [self.searchResultsTableView addTableColumn:searchColumn];
    [self.searchResultsScrollView setDocumentView:self.searchResultsTableView];
    [contentView addSubview:self.searchResultsScrollView];

    self.sendLabel = [self labelWithFrame:NSMakeRect(24, 58, 48, 22)
                                     text:@""
                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.sendLabel];

    self.attachPhotoButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 50, 38, 32)] autorelease];
    TGAttachButtonCell *attachCell = [[[TGAttachButtonCell alloc] initTextCell:@""] autorelease];
    [attachCell setButtonType:NSMomentaryPushInButton];
    [self.attachPhotoButton setCell:attachCell];
    [self.attachPhotoButton setTitle:@""];
    [self.attachPhotoButton setTarget:self];
    [self.attachPhotoButton setAction:@selector(attachPhoto:)];
    [self.attachPhotoButton setEnabled:NO];
    [self.attachPhotoButton setBordered:NO];
    [self.attachPhotoButton setToolTip:@"Attach photo"];
    [self.attachPhotoButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.attachPhotoButton];

    self.stickerButton = [[[NSButton alloc] initWithFrame:NSMakeRect(76, 50, 34, 32)] autorelease];
    TGComposerSymbolButtonCell *stickerCell = [[[TGComposerSymbolButtonCell alloc] initTextCell:@"☺"] autorelease];
    [stickerCell setButtonType:NSMomentaryPushInButton];
    [self.stickerButton setCell:stickerCell];
    [self.stickerButton setTitle:@"☺"];
    [self.stickerButton setTarget:self];
    [self.stickerButton setAction:@selector(showStickerPicker:)];
    [self.stickerButton setEnabled:NO];
    [self.stickerButton setBordered:NO];
    [self.stickerButton setToolTip:@"Stickers"];
    [self.stickerButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.stickerButton];

    self.voiceRecordButton = [[[NSButton alloc] initWithFrame:NSMakeRect(112, 50, 34, 32)] autorelease];
    TGComposerSymbolButtonCell *voiceCell = [[[TGComposerSymbolButtonCell alloc] initTextCell:@"mic"] autorelease];
    [voiceCell setButtonType:NSMomentaryPushInButton];
    [self.voiceRecordButton setCell:voiceCell];
    [self.voiceRecordButton setTitle:@"mic"];
    [self.voiceRecordButton setTarget:self];
    [self.voiceRecordButton setAction:@selector(toggleVoiceRecording:)];
    [self.voiceRecordButton setEnabled:NO];
    [self.voiceRecordButton setBordered:NO];
    [self.voiceRecordButton setToolTip:@"Record voice message"];
    [self.voiceRecordButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.voiceRecordButton];

    self.voiceRecordingIndicatorField = [self labelWithFrame:NSMakeRect(150, 84, 340, 18)
                                                        text:@""
                                                        font:[NSFont boldSystemFontOfSize:11.0]];
    [self.voiceRecordingIndicatorField setHidden:YES];
    [self.voiceRecordingIndicatorField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.voiceRecordingIndicatorField];

    self.sendTextFieldBackgroundView = [[[TGComposerInputBackgroundView alloc] initWithFrame:NSMakeRect(76, 54, 500, 24)] autorelease];
    [self.sendTextFieldBackgroundView setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.sendTextFieldBackgroundView];

    self.sendTextField = [[[NSTextField alloc] initWithFrame:NSMakeRect(76, 54, 500, 24)] autorelease];
    [self.sendTextField setEnabled:NO];
    [self applyComposerTextFieldStyle:self.sendTextField];
    [[self.sendTextField cell] setUsesSingleLineMode:NO];
    [[self.sendTextField cell] setWraps:YES];
    [[self.sendTextField cell] setScrollable:NO];
    [[self.sendTextField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [[self.sendTextField cell] setPlaceholderString:@"Message"];
    [self.sendTextField setDelegate:(id)self];
    [self.sendTextField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [contentView addSubview:self.sendTextField];

    self.sendMessageButton = [[[NSButton alloc] initWithFrame:NSMakeRect(588, 50, 38, 32)] autorelease];
    TGSendButtonCell *sendCell = [[[TGSendButtonCell alloc] initTextCell:@""] autorelease];
    [sendCell setButtonType:NSMomentaryPushInButton];
    [self.sendMessageButton setCell:sendCell];
    [self.sendMessageButton setTitle:@""];
    [self.sendMessageButton setTarget:self];
    [self.sendMessageButton setAction:@selector(sendMessage:)];
    [self.sendMessageButton setEnabled:NO];
    [self.sendMessageButton setBordered:NO];
    [self.sendMessageButton setToolTip:@"Send message"];
    [self.sendMessageButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.sendMessageButton];

    self.checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(24, 28, 140, 32)] autorelease];
    [self.checkButton setTitle:@"Check Connection"];
    [self.checkButton setTarget:self];
    [self.checkButton setAction:@selector(checkTDLib:)];
    [self applySkeuomorphicButtonStyle:self.checkButton isPrimary:YES];
    [self.checkButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.checkButton];

    self.profileSummaryCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 370, 620, 160)] autorelease];
    [self.profileSummaryCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileSummaryCardView];

    self.profileInfoCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 300, 620, 54)] autorelease];
    [self.profileInfoCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileInfoCardView];

    self.profileDetailsCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 230, 620, 124)] autorelease];
    [self.profileDetailsCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileDetailsCardView];

    self.profileActionsCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 166, 620, 54)] autorelease];
    [self.profileActionsCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileActionsCardView];

    self.profileAvatarView = [[[TGProfileAvatarView alloc] initWithFrame:NSMakeRect(446, 424, 88, 88)] autorelease];
    [self.profileAvatarView setAutoresizingMask:NSViewMinYMargin];
    [contentView addSubview:self.profileAvatarView];

    self.profileTitleField = [self labelWithFrame:NSMakeRect(40, 520, 400, 28)
                                             text:TGLoc(@"profile.title")
                                             font:[NSFont boldSystemFontOfSize:18.0]];
    [self applyPanelHeaderLabelStyle:self.profileTitleField];
    [contentView addSubview:self.profileTitleField];

    self.profileNameField = [self labelWithFrame:NSMakeRect(64, 458, 620, 24)
                                            text:TGLoc(@"profile.fallback")
                                            font:[NSFont boldSystemFontOfSize:18.0]];
    [self.profileNameField setAlignment:NSCenterTextAlignment];
    [[self.profileNameField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [contentView addSubview:self.profileNameField];

    self.profileUsernameField = [self labelWithFrame:NSMakeRect(64, 424, 620, 24)
                                                text:@""
                                                font:[NSFont systemFontOfSize:13.0]];
    [self.profileUsernameField setAlignment:NSCenterTextAlignment];
    [[self.profileUsernameField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self applyMutedLabelStyle:self.profileUsernameField];
    [contentView addSubview:self.profileUsernameField];

    self.profileIDField = [self labelWithFrame:NSMakeRect(64, 392, 620, 24)
                                           text:@""
                                           font:[NSFont systemFontOfSize:13.0]];
    [self.profileIDField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:self.profileIDField];
    [contentView addSubview:self.profileIDField];

    self.profileStateField = [self labelWithFrame:NSMakeRect(64, 348, 720, 38)
                                             text:@""
                                             font:[NSFont systemFontOfSize:12.0]];
    [[self.profileStateField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.profileStateField];
    [contentView addSubview:self.profileStateField];

    self.profileAboutSectionField = [self labelWithFrame:NSMakeRect(64, 320, 620, 18)
                                                    text:TGLoc(@"profile.about")
                                                    font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.profileAboutSectionField];
    [contentView addSubview:self.profileAboutSectionField];

    self.profileAccountSectionField = [self labelWithFrame:NSMakeRect(64, 250, 620, 18)
                                                      text:TGLoc(@"profile.account")
                                                      font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.profileAccountSectionField];
    [contentView addSubview:self.profileAccountSectionField];

    self.profileUsernameRowTitleField = [self labelWithFrame:NSMakeRect(64, 248, 180, 20)
                                                        text:TGLoc(@"profile.username")
                                                        font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.profileUsernameRowTitleField];
    self.profileUsernameRowValueField = [self labelWithFrame:NSMakeRect(260, 248, 360, 20)
                                                        text:@""
                                                        font:[NSFont systemFontOfSize:13.0]];
    [self.profileUsernameRowValueField setAlignment:NSRightTextAlignment];
    [[self.profileUsernameRowValueField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [self applyMutedLabelStyle:self.profileUsernameRowValueField];
    [contentView addSubview:self.profileUsernameRowValueField];

    self.profilePhoneRowTitleField = [self labelWithFrame:NSMakeRect(64, 206, 180, 20)
                                                     text:TGLoc(@"profile.phone")
                                                     font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.profilePhoneRowTitleField];
    self.profilePhoneRowValueField = [self labelWithFrame:NSMakeRect(260, 206, 360, 20)
                                                     text:@""
                                                     font:[NSFont systemFontOfSize:13.0]];
    [self.profilePhoneRowValueField setAlignment:NSRightTextAlignment];
    [[self.profilePhoneRowValueField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [self applyMutedLabelStyle:self.profilePhoneRowValueField];
    [contentView addSubview:self.profilePhoneRowValueField];

    self.profileIDRowTitleField = [self labelWithFrame:NSMakeRect(64, 164, 180, 20)
                                                  text:TGLoc(@"profile.id")
                                                  font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.profileIDRowTitleField];
    self.profileIDRowValueField = [self labelWithFrame:NSMakeRect(260, 164, 360, 20)
                                                  text:@""
                                                  font:[NSFont systemFontOfSize:13.0]];
    [self.profileIDRowValueField setAlignment:NSRightTextAlignment];
    [[self.profileIDRowValueField cell] setLineBreakMode:NSLineBreakByTruncatingHead];
    [self applyMutedLabelStyle:self.profileIDRowValueField];
    [contentView addSubview:self.profileIDRowValueField];

    self.profileDetailsSeparatorOne = [[[NSBox alloc] initWithFrame:NSMakeRect(64, 228, 620, 1)] autorelease];
    [self.profileDetailsSeparatorOne setBoxType:NSBoxSeparator];
    [self.profileDetailsSeparatorOne setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileDetailsSeparatorOne];

    self.profileDetailsSeparatorTwo = [[[NSBox alloc] initWithFrame:NSMakeRect(64, 186, 620, 1)] autorelease];
    [self.profileDetailsSeparatorTwo setBoxType:NSBoxSeparator];
    [self.profileDetailsSeparatorTwo setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.profileDetailsSeparatorTwo];

    self.settingsAccountCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 380, 760, 100)] autorelease];
    [self.settingsAccountCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsAccountCardView];

    self.settingsThemeCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 316, 760, 54)] autorelease];
    [self.settingsThemeCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsThemeCardView];

    self.settingsSessionCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 250, 760, 54)] autorelease];
    [self.settingsSessionCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsSessionCardView];

    self.settingsDrawerCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 190, 760, 54)] autorelease];
    [self.settingsDrawerCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsDrawerCardView];

    self.settingsResourceCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 170, 760, 230)] autorelease];
    [self.settingsResourceCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsResourceCardView];

    self.settingsFilesCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 130, 760, 76)] autorelease];
    [self.settingsFilesCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsFilesCardView];

    self.settingsHelpCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(64, 56, 760, 92)] autorelease];
    [self.settingsHelpCardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [contentView addSubview:self.settingsHelpCardView];

    self.settingsTitleField = [self labelWithFrame:NSMakeRect(40, 520, 400, 28)
                                              text:@"Settings"
                                              font:[NSFont boldSystemFontOfSize:18.0]];
    [self applyPanelHeaderLabelStyle:self.settingsTitleField];
    [contentView addSubview:self.settingsTitleField];

    self.settingsStateField = [[[TGSectionTitleField alloc] initWithFrame:NSMakeRect(64, 458, 760, 24)] autorelease];
    [self.settingsStateField setStringValue:@"Notifications"];
    [self.settingsStateField setFont:[NSFont systemFontOfSize:13.0]];
    [(TGSectionTitleField *)self.settingsStateField setIconName:@"bell"];
    [self applyMutedLabelStyle:self.settingsStateField];
    [contentView addSubview:self.settingsStateField];

    self.settingsLibraryField = [[[TGSectionTitleField alloc] initWithFrame:NSMakeRect(64, 424, 760, 24)] autorelease];
    [self.settingsLibraryField setStringValue:@"Appearance"];
    [self.settingsLibraryField setFont:[NSFont systemFontOfSize:13.0]];
    [(TGSectionTitleField *)self.settingsLibraryField setIconName:@"image"];
    [self applyMutedLabelStyle:self.settingsLibraryField];
    [[self.settingsLibraryField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:self.settingsLibraryField];

    self.settingsStorageField = [[[TGSectionTitleField alloc] initWithFrame:NSMakeRect(64, 380, 760, 44)] autorelease];
    [self.settingsStorageField setStringValue:@"Active Sessions"];
    [self.settingsStorageField setFont:[NSFont systemFontOfSize:13.0]];
    [(TGSectionTitleField *)self.settingsStorageField setIconName:@"smartphone"];
    [[self.settingsStorageField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [contentView addSubview:self.settingsStorageField];

    self.settingsDrawerSectionField = [[[TGSectionTitleField alloc] initWithFrame:NSMakeRect(64, 356, 760, 18)] autorelease];
    [self.settingsDrawerSectionField setStringValue:@"General"];
    [self.settingsDrawerSectionField setFont:[NSFont systemFontOfSize:13.0]];
    [(TGSectionTitleField *)self.settingsDrawerSectionField setIconName:@"suitcase"];
    [self applyMutedLabelStyle:self.settingsDrawerSectionField];
    [contentView addSubview:self.settingsDrawerSectionField];

    self.settingsResourceSectionField = [[[TGSectionTitleField alloc] initWithFrame:NSMakeRect(64, 286, 760, 18)] autorelease];
    [self.settingsResourceSectionField setStringValue:@"Resource management"];
    [self.settingsResourceSectionField setFont:[NSFont systemFontOfSize:13.0]];
    [(TGSectionTitleField *)self.settingsResourceSectionField setIconName:@"restore"];
    [self applyMutedLabelStyle:self.settingsResourceSectionField];
    [contentView addSubview:self.settingsResourceSectionField];

    self.settingsFilesSectionField = [[[TGSectionTitleField alloc] initWithFrame:NSMakeRect(64, 206, 760, 18)] autorelease];
    [self.settingsFilesSectionField setStringValue:@"Files"];
    [self.settingsFilesSectionField setFont:[NSFont systemFontOfSize:13.0]];
    [(TGSectionTitleField *)self.settingsFilesSectionField setIconName:@"document"];
    [self applyMutedLabelStyle:self.settingsFilesSectionField];
    [contentView addSubview:self.settingsFilesSectionField];

    self.settingsHelpSectionField = [[[TGSectionTitleField alloc] initWithFrame:NSMakeRect(64, 126, 760, 18)] autorelease];
    [self.settingsHelpSectionField setStringValue:@"Help"];
    [self.settingsHelpSectionField setFont:[NSFont systemFontOfSize:13.0]];
    [(TGSectionTitleField *)self.settingsHelpSectionField setIconName:@"info"];
    [self applyMutedLabelStyle:self.settingsHelpSectionField];
    [contentView addSubview:self.settingsHelpSectionField];

    self.settingsThemeCategoryLabel = [self labelWithFrame:NSMakeRect(64, 362, 88, 24)
                                                      text:@"Category"
                                                      font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.settingsThemeCategoryLabel];

    self.themeCategoryPopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(154, 356, 300, 30) pullsDown:NO] autorelease];
    [self populateThemeCategoryPopUp];
    [self.themeCategoryPopUpButton setTarget:self];
    [self.themeCategoryPopUpButton setAction:@selector(themeCategorySelectionChanged:)];
    [self.themeCategoryPopUpButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.themeCategoryPopUpButton];

    self.settingsThemeLabel = [self labelWithFrame:NSMakeRect(64, 332, 88, 24)
                                              text:@"Theme"
                                              font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.settingsThemeLabel];

    self.themePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(154, 326, 300, 30) pullsDown:NO] autorelease];
    [self.themePopUpButton setTarget:self];
    [self.themePopUpButton setAction:@selector(themeSelectionChanged:)];
    [self.themePopUpButton setAutoresizingMask:NSViewMaxYMargin];
    [self selectThemePopUpItemForIdentifier:TGCurrentThemeIdentifier()];
    [contentView addSubview:self.themePopUpButton];

    self.settingsNotificationsEnabledButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 300, 260, 22)] autorelease];
    [self.settingsNotificationsEnabledButton setButtonType:NSSwitchButton];
    [self.settingsNotificationsEnabledButton setTitle:@"Show message notifications"];
    [self.settingsNotificationsEnabledButton setTarget:self];
    [self.settingsNotificationsEnabledButton setAction:@selector(notificationSettingChanged:)];
    [self.settingsNotificationsEnabledButton setState:TGUserDefaultBoolWithDefault(TGNotificationsEnabledDefaultsKey, YES) ? NSOnState : NSOffState];
    [self.settingsNotificationsEnabledButton setFont:[NSFont systemFontOfSize:13.0]];
    [self.settingsNotificationsEnabledButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsNotificationsEnabledButton];

    self.settingsNotificationSoundButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 276, 260, 22)] autorelease];
    [self.settingsNotificationSoundButton setButtonType:NSSwitchButton];
    [self.settingsNotificationSoundButton setTitle:@"Play notification sound"];
    [self.settingsNotificationSoundButton setTarget:self];
    [self.settingsNotificationSoundButton setAction:@selector(notificationSettingChanged:)];
    [self.settingsNotificationSoundButton setState:TGUserDefaultBoolWithDefault(TGNotificationSoundEnabledDefaultsKey, YES) ? NSOnState : NSOffState];
    [self.settingsNotificationSoundButton setFont:[NSFont systemFontOfSize:13.0]];
    [self.settingsNotificationSoundButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsNotificationSoundButton];

    self.settingsNotificationBadgeButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 252, 260, 22)] autorelease];
    [self.settingsNotificationBadgeButton setButtonType:NSSwitchButton];
    [self.settingsNotificationBadgeButton setTitle:@"Show unread badge in Dock"];
    [self.settingsNotificationBadgeButton setTarget:self];
    [self.settingsNotificationBadgeButton setAction:@selector(notificationSettingChanged:)];
    [self.settingsNotificationBadgeButton setState:TGUserDefaultBoolWithDefault(TGNotificationBadgeEnabledDefaultsKey, YES) ? NSOnState : NSOffState];
    [self.settingsNotificationBadgeButton setFont:[NSFont systemFontOfSize:13.0]];
    [self.settingsNotificationBadgeButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsNotificationBadgeButton];

    self.settingsNotificationPreviewButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 228, 340, 22)] autorelease];
    [self.settingsNotificationPreviewButton setButtonType:NSSwitchButton];
    [self.settingsNotificationPreviewButton setTitle:@"Show message preview"];
    [self.settingsNotificationPreviewButton setTarget:self];
    [self.settingsNotificationPreviewButton setAction:@selector(notificationSettingChanged:)];
    [self.settingsNotificationPreviewButton setState:TGUserDefaultBoolWithDefault(TGNotificationPreviewEnabledDefaultsKey, YES) ? NSOnState : NSOffState];
    [self.settingsNotificationPreviewButton setFont:[NSFont systemFontOfSize:13.0]];
    [self.settingsNotificationPreviewButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsNotificationPreviewButton];

    self.settingsNotificationsWhenActiveButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 204, 400, 22)] autorelease];
    [self.settingsNotificationsWhenActiveButton setButtonType:NSSwitchButton];
    [self.settingsNotificationsWhenActiveButton setTitle:@"Notify while Telegraphica is active"];
    [self.settingsNotificationsWhenActiveButton setTarget:self];
    [self.settingsNotificationsWhenActiveButton setAction:@selector(notificationSettingChanged:)];
    [self.settingsNotificationsWhenActiveButton setState:TGUserDefaultBoolWithDefault(TGNotificationsWhenActiveDefaultsKey, NO) ? NSOnState : NSOffState];
    [self.settingsNotificationsWhenActiveButton setFont:[NSFont systemFontOfSize:13.0]];
    [self.settingsNotificationsWhenActiveButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsNotificationsWhenActiveButton];

    self.settingsDrawerHiddenButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 228, 260, 22)] autorelease];
    [self.settingsDrawerHiddenButton setButtonType:NSSwitchButton];
    [self.settingsDrawerHiddenButton setTitle:@"Hide side drawer"];
    [self.settingsDrawerHiddenButton setTarget:self];
    [self.settingsDrawerHiddenButton setAction:@selector(interfaceSettingChanged:)];
    [self.settingsDrawerHiddenButton setState:TGUserDefaultBoolWithDefault(TGDrawerHiddenDefaultsKey, NO) ? NSOnState : NSOffState];
    [self.settingsDrawerHiddenButton setFont:[NSFont systemFontOfSize:13.0]];
    [self.settingsDrawerHiddenButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsDrawerHiddenButton];

    self.settingsTypingIndicatorsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 204, 360, 22)] autorelease];
    [self.settingsTypingIndicatorsButton setButtonType:NSSwitchButton];
    [self.settingsTypingIndicatorsButton setTitle:@"Show when someone is typing"];
    [self.settingsTypingIndicatorsButton setTarget:self];
    [self.settingsTypingIndicatorsButton setAction:@selector(interfaceSettingChanged:)];
    [self.settingsTypingIndicatorsButton setState:TGUserDefaultBoolWithDefault(TGTypingIndicatorsEnabledDefaultsKey, YES) ? NSOnState : NSOffState];
    [self.settingsTypingIndicatorsButton setFont:[NSFont systemFontOfSize:13.0]];
    [self.settingsTypingIndicatorsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsTypingIndicatorsButton];

    [self buildResourceSettingsControlsInContentView:contentView];

    self.settingsLanguageLabel = [self labelWithFrame:NSMakeRect(64, 204, 100, 22)
                                                 text:@"Language"
                                                 font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.settingsLanguageLabel];

    self.settingsLanguagePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(164, 200, 190, 28) pullsDown:NO] autorelease];
    [self.settingsLanguagePopUpButton addItemWithTitle:@"Русский"];
    [[self.settingsLanguagePopUpButton lastItem] setRepresentedObject:@"ru"];
    [self.settingsLanguagePopUpButton addItemWithTitle:@"English"];
    [[self.settingsLanguagePopUpButton lastItem] setRepresentedObject:@"en"];
    [self.settingsLanguagePopUpButton addItemWithTitle:@"Беларуская"];
    [[self.settingsLanguagePopUpButton lastItem] setRepresentedObject:@"be"];
    [self.settingsLanguagePopUpButton setTarget:self];
    [self.settingsLanguagePopUpButton setAction:@selector(languageSelectionChanged:)];
    [self.settingsLanguagePopUpButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsLanguagePopUpButton];

    self.settingsMessagesAsBlocksButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 166, 260, 22)] autorelease];
    [self.settingsMessagesAsBlocksButton setButtonType:NSSwitchButton];
    [self.settingsMessagesAsBlocksButton setTitle:@"Messages as blocks"];
    [self.settingsMessagesAsBlocksButton setTarget:self];
    [self.settingsMessagesAsBlocksButton setAction:@selector(chatDisplaySettingChanged:)];
    [self.settingsMessagesAsBlocksButton setState:TGChatMessagesAsBlocksEnabled() ? NSOnState : NSOffState];
    [self.settingsMessagesAsBlocksButton setFont:[NSFont systemFontOfSize:13.0]];
    [self.settingsMessagesAsBlocksButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsMessagesAsBlocksButton];

    self.settingsChatTextSizeSectionField = [self labelWithFrame:NSMakeRect(64, 134, 130, 22)
                                                            text:@"Text size"
                                                            font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.settingsChatTextSizeSectionField];

    self.settingsChatTextSizeSlider = [[[NSSlider alloc] initWithFrame:NSMakeRect(164, 128, 190, 28)] autorelease];
    [self.settingsChatTextSizeSlider setMinValue:0.0];
    [self.settingsChatTextSizeSlider setMaxValue:3.0];
    [self.settingsChatTextSizeSlider setNumberOfTickMarks:4];
    [self.settingsChatTextSizeSlider setAllowsTickMarkValuesOnly:YES];
    [self.settingsChatTextSizeSlider setContinuous:NO];
    [self.settingsChatTextSizeSlider setTarget:self];
    [self.settingsChatTextSizeSlider setAction:@selector(chatDisplaySettingChanged:)];
    [self.settingsChatTextSizeSlider setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsChatTextSizeSlider];

    self.settingsChatTextSizeValueField = [self labelWithFrame:NSMakeRect(364, 134, 120, 22)
                                                          text:@"Normal"
                                                          font:[NSFont systemFontOfSize:12.0]];
    [self applyMutedLabelStyle:self.settingsChatTextSizeValueField];
    [contentView addSubview:self.settingsChatTextSizeValueField];
    [self refreshChatDisplayPreferenceControls];

    self.settingsActiveSessionsDetailField = [self labelWithFrame:NSMakeRect(64, 174, 420, 18)
                                                              text:@"Devices currently signed in to this account"
                                                              font:[NSFont systemFontOfSize:11.0]];
    [self applyMutedLabelStyle:self.settingsActiveSessionsDetailField];
    [contentView addSubview:self.settingsActiveSessionsDetailField];

    self.settingsActiveSessionsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 146, 260, 28)] autorelease];
    [self.settingsActiveSessionsButton setTitle:@"Open Active Sessions"];
    [self.settingsActiveSessionsButton setTarget:self];
    [self.settingsActiveSessionsButton setAction:@selector(showActiveSessionsWindow:)];
    [self applyUtilityButtonStyle:self.settingsActiveSessionsButton];
    [self.settingsActiveSessionsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsActiveSessionsButton];

    self.settingsDownloadFolderHelpField = [self labelWithFrame:NSMakeRect(64, 198, 360, 18)
                                                           text:@"Choose where downloaded files will be saved"
                                                           font:[NSFont systemFontOfSize:11.0]];
    [self applyMutedLabelStyle:self.settingsDownloadFolderHelpField];
    [contentView addSubview:self.settingsDownloadFolderHelpField];

    self.settingsDownloadFolderButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 178, 260, 22)] autorelease];
    [self.settingsDownloadFolderButton setTitle:@"Downloads folder"];
    [self.settingsDownloadFolderButton setTarget:self];
    [self.settingsDownloadFolderButton setAction:@selector(chooseDownloadFolder:)];
    [self applyUtilityButtonStyle:self.settingsDownloadFolderButton];
    [self.settingsDownloadFolderButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsDownloadFolderButton];

    self.settingsStorageUsageButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 150, 260, 22)] autorelease];
    [self.settingsStorageUsageButton setTitle:@"Storage usage"];
    [self.settingsStorageUsageButton setTarget:self];
    [self.settingsStorageUsageButton setAction:@selector(showStorageUsageWindow:)];
    [self applyUtilityButtonStyle:self.settingsStorageUsageButton];
    [self.settingsStorageUsageButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsStorageUsageButton];

    self.settingsDeleteLocalDataButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 120, 260, 22)] autorelease];
    [self.settingsDeleteLocalDataButton setTitle:@"Delete local data"];
    [self.settingsDeleteLocalDataButton setTarget:self];
    [self.settingsDeleteLocalDataButton setAction:@selector(deleteLocalData:)];
    [self applyDestructiveSettingsButtonStyle:self.settingsDeleteLocalDataButton];
    [self.settingsDeleteLocalDataButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsDeleteLocalDataButton];

    self.settingsCheckUpdatesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 152, 260, 22)] autorelease];
    [self.settingsCheckUpdatesButton setTitle:@"Check for Updates"];
    [self.settingsCheckUpdatesButton setTarget:self];
    [self.settingsCheckUpdatesButton setAction:@selector(checkForUpdatesManually:)];
    [self applyUtilityButtonStyle:self.settingsCheckUpdatesButton];
    [self.settingsCheckUpdatesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsCheckUpdatesButton];
    self.settingsUpdateDotView = [[[TGNotificationDotView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)] autorelease];
    [self.settingsUpdateDotView setHidden:YES];
    [self.settingsUpdateDotView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
    [self.settingsCheckUpdatesButton addSubview:self.settingsUpdateDotView];

    self.settingsAppearanceButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 328, 260, 40)] autorelease];
    [self.settingsAppearanceButton setTitle:@"Appearance"];
    [self.settingsAppearanceButton setToolTip:@"Open appearance settings"];
    [self.settingsAppearanceButton setTarget:self];
    [self.settingsAppearanceButton setAction:@selector(showAppearanceWindow:)];
    [self applyUtilityButtonStyle:self.settingsAppearanceButton];
    [self.settingsAppearanceButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsAppearanceButton];

    self.settingsLogsButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 276, 260, 40)] autorelease];
    [self.settingsLogsButton setTitle:@"Diagnostic Logs"];
    [self.settingsLogsButton setToolTip:@"Open diagnostic logs"];
    [self.settingsLogsButton setTarget:self];
    [self.settingsLogsButton setAction:@selector(showLogsWindow:)];
    [self applyUtilityButtonStyle:self.settingsLogsButton];
    [self.settingsLogsButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsLogsButton];

    self.settingsAboutButton = [[[NSButton alloc] initWithFrame:NSMakeRect(334, 276, 260, 40)] autorelease];
    [self.settingsAboutButton setTitle:@"About Telegraphica"];
    [self.settingsAboutButton setToolTip:@"Open application information"];
    [self.settingsAboutButton setTarget:self];
    [self.settingsAboutButton setAction:@selector(showAboutWindow:)];
    [self applyUtilityButtonStyle:self.settingsAboutButton];
    [self.settingsAboutButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsAboutButton];

    NSArray *settingsContentViews = [NSArray arrayWithObjects:
                                     self.settingsAccountCardView,
                                     self.settingsThemeCardView,
                                     self.settingsSessionCardView,
                                     self.settingsDrawerCardView,
                                     self.settingsResourceCardView,
                                     self.settingsFilesCardView,
                                     self.settingsHelpCardView,
                                     self.settingsStateField,
                                     self.settingsLibraryField,
                                     self.settingsStorageField,
                                     self.settingsDrawerSectionField,
                                     self.settingsResourceSectionField,
                                     self.settingsFilesSectionField,
                                     self.settingsHelpSectionField,
                                     self.settingsThemeCategoryLabel,
                                     self.themeCategoryPopUpButton,
                                     self.settingsThemeLabel,
                                     self.themePopUpButton,
                                     self.settingsNotificationsEnabledButton,
                                     self.settingsNotificationSoundButton,
                                     self.settingsNotificationBadgeButton,
                                     self.settingsNotificationPreviewButton,
                                     self.settingsNotificationsWhenActiveButton,
                                     self.settingsDrawerHiddenButton,
                                     self.settingsTypingIndicatorsButton,
                                     self.settingsEconomyModeButton,
                                     self.settingsAutoDownloadPhotosButton,
                                     self.settingsAutoDownloadVideosButton,
                                     self.settingsAutoDownloadDocumentsButton,
                                     self.settingsAutoplayAnimatedStickersButton,
                                     self.settingsStopInactiveAnimationsButton,
                                     self.settingsMaxAutoDownloadLabel,
                                     self.settingsMaxAutoDownloadPopUpButton,
                                     self.settingsMaxAnimationsLabel,
                                     self.settingsMaxAnimationsPopUpButton,
                                     self.settingsMediaCacheLimitLabel,
                                     self.settingsMediaCacheLimitPopUpButton,
                                     self.settingsResourceHintField,
                                     self.settingsLanguageLabel,
                                     self.settingsLanguagePopUpButton,
                                     self.settingsMessagesAsBlocksButton,
                                     self.settingsChatTextSizeSectionField,
                                     self.settingsChatTextSizeSlider,
                                     self.settingsChatTextSizeValueField,
                                     self.settingsActiveSessionsDetailField,
                                     self.settingsActiveSessionsButton,
                                     self.settingsDownloadFolderHelpField,
                                     self.settingsDownloadFolderButton,
                                     self.settingsStorageUsageButton,
                                     self.settingsDeleteLocalDataButton,
                                     self.settingsCheckUpdatesButton,
                                     self.settingsAppearanceButton,
                                     self.settingsLogsButton,
                                     self.settingsAboutButton,
                                     nil];
    NSUInteger settingsViewIndex = 0;
    for (settingsViewIndex = 0; settingsViewIndex < [settingsContentViews count]; settingsViewIndex++) {
        NSView *settingsView = [settingsContentViews objectAtIndex:settingsViewIndex];
        [settingsView removeFromSuperview];
        [self.settingsContentView addSubview:settingsView];
    }

    self.logoutButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 276, 132, 32)] autorelease];
    [self.logoutButton setTitle:TGLoc(@"profile.logout")];
    [self.logoutButton setTarget:self];
    [self.logoutButton setAction:@selector(logout:)];
    [self applyDestructiveSettingsButtonStyle:self.logoutButton];
    [self.logoutButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.logoutButton];

    self.profileRefreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 314, 220, 30)] autorelease];
    [self.profileRefreshButton setTitle:TGLoc(@"profile.refresh")];
    [self.profileRefreshButton setTarget:self];
    [self.profileRefreshButton setAction:@selector(refreshProfile:)];
    [self applyUtilityButtonStyle:self.profileRefreshButton];
    [self.profileRefreshButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.profileRefreshButton];

    NSArray *profileContentViews = [NSArray arrayWithObjects:
                                    self.profileSummaryCardView,
                                    self.profileInfoCardView,
                                    self.profileDetailsCardView,
                                    self.profileActionsCardView,
                                    self.profileAvatarView,
                                    self.profileNameField,
                                    self.profileUsernameField,
                                    self.profileIDField,
                                    self.profileStateField,
                                    self.profileAboutSectionField,
                                    self.profileAccountSectionField,
                                    self.profileUsernameRowTitleField,
                                    self.profileUsernameRowValueField,
                                    self.profilePhoneRowTitleField,
                                    self.profilePhoneRowValueField,
                                    self.profileIDRowTitleField,
                                    self.profileIDRowValueField,
                                    self.profileDetailsSeparatorOne,
                                    self.profileDetailsSeparatorTwo,
                                    self.profileRefreshButton,
                                    self.logoutButton,
                                    nil];
    NSUInteger profileViewIndex = 0;
    for (profileViewIndex = 0; profileViewIndex < [profileContentViews count]; profileViewIndex++) {
        NSView *profileView = [profileContentViews objectAtIndex:profileViewIndex];
        [profileView removeFromSuperview];
        [self.profileContentView addSubview:profileView];
    }

    self.aboutCardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(240, 230, 500, 310)] autorelease];
    [self.aboutCardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.aboutCardView];

    self.aboutIconView = [[[NSImageView alloc] initWithFrame:NSMakeRect(430, 396, 120, 120)] autorelease];
    NSImage *appIcon = [NSImage imageNamed:@"Telegraphica"];
    if (!appIcon) {
        appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
    }
    [self.aboutIconView setImage:appIcon];
    [self.aboutIconView setImageScaling:NSImageScaleProportionallyUpOrDown];
    [contentView addSubview:self.aboutIconView];

    self.aboutTitleField = [self labelWithFrame:NSMakeRect(240, 352, 500, 30)
                                           text:@"Telegraphica"
                                           font:[NSFont boldSystemFontOfSize:22.0]];
    [self.aboutTitleField setAlignment:NSCenterTextAlignment];
    [contentView addSubview:self.aboutTitleField];

    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
    NSString *build = [info objectForKey:@"CFBundleVersion"];
    NSString *versionText = [NSString stringWithFormat:@"Version %@ (%@)", version ? version : @"0.1.0", build ? build : @"0.1.0"];
    self.aboutVersionField = [self labelWithFrame:NSMakeRect(240, 324, 500, 22)
                                             text:versionText
                                             font:[NSFont systemFontOfSize:12.0]];
    [self.aboutVersionField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:self.aboutVersionField];
    [contentView addSubview:self.aboutVersionField];

    NSString *copyrightText = [NSString stringWithFormat:@"Copyright %@ Yura Menschikov. All rights reserved.", TGCurrentYearString()];
    self.aboutCopyrightField = [self labelWithFrame:NSMakeRect(240, 292, 500, 22)
                                               text:copyrightText
                                               font:[NSFont systemFontOfSize:12.0]];
    [self.aboutCopyrightField setAlignment:NSCenterTextAlignment];
    [self applyMutedLabelStyle:self.aboutCopyrightField];
    [contentView addSubview:self.aboutCopyrightField];

    self.aboutLinkField = [self labelWithFrame:NSMakeRect(240, 260, 500, 22)
                                          text:@"GitHub: https://github.com/MiChiRose/telegraphica"
                                          font:[NSFont systemFontOfSize:12.0]];
    [self.aboutLinkField setAlignment:NSCenterTextAlignment];
    [self.aboutLinkField setSelectable:YES];
    [self.aboutLinkField setTextColor:TGClassicLinkColor()];
    [contentView addSubview:self.aboutLinkField];

    [self refreshLocalizedText];
    [self refreshThemeAppearance];
    [self refreshProfileDisplay];
    [self rebuildDrawerFolderButtons];
    [self layoutContentView];
    [self updateVisibleSection];
}

- (NSString *)sectionIdentifierForNavigationTag:(NSInteger)navigationTag {
    if (navigationTag == 1) {
        return TGSectionProfile;
    }
    if (navigationTag == 2) {
        return TGSectionSettings;
    }
    if (navigationTag == 3) {
        return TGSectionAbout;
    }
    if (navigationTag == 4) {
        return TGSectionLogs;
    }
    return TGSectionChats;
}

- (NSInteger)navigationTagForSectionIdentifier:(NSString *)section {
    if ([section isEqualToString:TGSectionProfile]) {
        return 1;
    }
    if ([section isEqualToString:TGSectionSettings]) {
        return 2;
    }
    if ([section isEqualToString:TGSectionAbout]) {
        return 3;
    }
    if ([section isEqualToString:TGSectionLogs]) {
        return 4;
    }
    return 0;
}

- (void)updateDrawerFolderButtonStates {
    NSUInteger index = 0;
    BOOL drawerHidden = TGUserDefaultBoolWithDefault(TGDrawerHiddenDefaultsKey, NO);
    BOOL ready = [self.currentAuthState isEqualToString:@"ready"];
    for (index = 0; index < [self.drawerFolderButtons count]; index++) {
        NSButton *button = [self.drawerFolderButtons objectAtIndex:index];
        BOOL selected = NO;
        if ([button tag] < 0) {
            selected = (self.selectedChatFilterID == nil);
        } else if (self.selectedChatFilterID && [button tag] == [self.selectedChatFilterID integerValue]) {
            selected = YES;
        }
        [button setState:selected ? NSOnState : NSOffState];
        [button setHidden:(!ready || drawerHidden || !self.drawerOpen)];
    }
}

- (void)rebuildDrawerFolderButtons {
    NSView *contentView = [[self window] contentView];
    if (!contentView) {
        return;
    }

    NSUInteger index = 0;
    for (index = 0; index < [self.drawerFolderButtons count]; index++) {
        NSButton *button = [self.drawerFolderButtons objectAtIndex:index];
        [button removeFromSuperview];
    }

    NSMutableArray *buttons = [NSMutableArray array];
    NSMutableArray *folderItems = [NSMutableArray array];
    NSDictionary *allItem = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithInteger:-1], @"id",
                             TGLoc(@"drawer.all"), @"title",
                             nil];
    [folderItems addObject:allItem];
    if ([self.chatFilterInfos count] > 0) {
        [folderItems addObjectsFromArray:self.chatFilterInfos];
    }
    NSMutableArray *drawerTitles = [NSMutableArray array];

    for (index = 0; index < [folderItems count]; index++) {
        NSDictionary *folderInfo = [folderItems objectAtIndex:index];
        NSString *buttonTitle = [folderInfo objectForKey:@"title"];
        id filterID = [folderInfo objectForKey:@"id"];
        if (![buttonTitle isKindOfClass:[NSString class]] || [buttonTitle length] == 0 || ![filterID respondsToSelector:@selector(integerValue)]) {
            continue;
        }
        [drawerTitles addObject:buttonTitle];

        NSButton *folderButton = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 500 - (index * 48), 92, 42)] autorelease];
        TGNavigationButtonCell *folderCell = [[[TGNavigationButtonCell alloc] initTextCell:buttonTitle] autorelease];
        [folderCell setButtonType:NSToggleButton];
        [folderButton setCell:folderCell];
        [folderButton setTitle:buttonTitle];
        [folderButton setButtonType:NSToggleButton];
        [folderButton setBordered:NO];
        [folderButton setTag:[filterID integerValue]];
        [folderButton setToolTip:([filterID integerValue] < 0) ? TGLoc(@"drawer.all.tooltip") : [NSString stringWithFormat:@"%@ folder", buttonTitle]];
        [folderButton setTarget:self];
        [folderButton setAction:@selector(folderFilterChanged:)];
        [folderButton setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
        [contentView addSubview:folderButton];
        [buttons addObject:folderButton];
    }

    self.drawerFolderButtons = buttons;
    [self updateDrawerFolderButtonStates];
    [self layoutContentView];
    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Drawer: rebuilt %lu visible folder button(s) from %lu TDLib folder(s); drawerOpen=%@; titles=%@.",
                                  (unsigned long)[buttons count],
                                  (unsigned long)[self.chatFilterInfos count],
                                  self.drawerOpen ? @"yes" : @"no",
                                  drawerTitles]];
}

- (void)reloadChatFiltersIfReady {
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Drawer: skipped folder refresh because auth state is %@.",
                                      self.currentAuthState ? self.currentAuthState : @"unknown"]];
        return;
    }
    if (self.chatFilterRefreshInFlight) {
        self.chatFilterRefreshPending = YES;
        [[TGLogger sharedLogger] log:@"Drawer: skipped folder refresh because another refresh is in flight; queued follow-up."];
        return;
    }

    self.chatFilterRefreshInFlight = YES;
    [[TGLogger sharedLogger] log:@"Drawer: requesting chat folders for UI."];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSArray *filters = [[client chatFilterInfoItemsWithTimeout:1.5] retain];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client == client && [self.currentAuthState isEqualToString:@"ready"]) {
                self.chatFilterInfos = filters ? filters : [NSArray array];
                NSMutableArray *filterTitles = [NSMutableArray array];
                NSUInteger logFilterIndex = 0;
                for (logFilterIndex = 0; logFilterIndex < [self.chatFilterInfos count]; logFilterIndex++) {
                    NSDictionary *filterInfo = [self.chatFilterInfos objectAtIndex:logFilterIndex];
                    NSString *title = [filterInfo objectForKey:@"title"];
                    if ([title isKindOfClass:[NSString class]] && [title length] > 0) {
                        [filterTitles addObject:title];
                    }
                }
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"Drawer: received %lu TDLib folder(s) for UI; titles=%@.",
                                              (unsigned long)[self.chatFilterInfos count],
                                              filterTitles]];
                BOOL selectedFilterWasCleared = NO;
                if (self.selectedChatFilterID) {
                    BOOL selectedFilterStillExists = NO;
                    NSUInteger filterIndex = 0;
                    for (filterIndex = 0; filterIndex < [self.chatFilterInfos count]; filterIndex++) {
                        NSDictionary *filterInfo = [self.chatFilterInfos objectAtIndex:filterIndex];
                        id filterID = [filterInfo objectForKey:@"id"];
                        if ([filterID respondsToSelector:@selector(integerValue)] && [filterID integerValue] == [self.selectedChatFilterID integerValue]) {
                            selectedFilterStillExists = YES;
                            break;
                        }
                    }
                    if (!selectedFilterStillExists) {
                        self.selectedChatFilterID = nil;
                        selectedFilterWasCleared = YES;
                    }
                }
                [self rebuildDrawerFolderButtons];
                if ([self.chatFilterInfos count] > 0) {
                    self.chatFilterRefreshRetryCount = 0;
                }
                if (selectedFilterWasCleared) {
                    self.chatsExhausted = NO;
                    self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
                    [self.client invalidateMainChatListExhaustion];
                    [self reloadChatsInteractive:NO preserveSelection:NO requestedLimit:TGStatusChatPreviewInitialLimit];
                }
            }
            self.chatFilterRefreshInFlight = NO;
            if (self.chatFilterRefreshPending) {
                self.chatFilterRefreshPending = NO;
                [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                         selector:@selector(reloadChatFiltersIfReady)
                                                           object:nil];
                [self performSelector:@selector(reloadChatFiltersIfReady) withObject:nil afterDelay:0.05];
            }
            [filters release];
            [client release];
        });

        [pool drain];
    });
}

- (void)openProfileFromDrawer:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }
    self.activeSection = TGSectionProfile;
    [self updateVisibleSection];
    if (!self.profileSummaryLoaded && !self.profileSummaryLoading && !self.controlsBusy) {
        [self reloadProfileSummaryIfReady];
    }
}

- (void)updateNavigationButtonsForSection:(NSString *)section enabled:(BOOL)enabled {
    NSInteger selectedTag = [self navigationTagForSectionIdentifier:section];
    BOOL ready = [self.currentAuthState isEqualToString:@"ready"];
    BOOL drawerHidden = TGUserDefaultBoolWithDefault(TGDrawerHiddenDefaultsKey, NO);
    NSUInteger index = 0;
    for (index = 0; index < [self.navigationButtons count]; index++) {
        NSButton *button = [self.navigationButtons objectAtIndex:index];
        [button setEnabled:(enabled && ready)];
        [button setHidden:!ready];
        [button setState:([button tag] == selectedTag) ? NSOnState : NSOffState];
    }
    for (index = 0; index < [self.drawerFolderButtons count]; index++) {
        NSButton *button = [self.drawerFolderButtons objectAtIndex:index];
        [button setEnabled:(enabled && ready)];
        [button setHidden:(!ready || drawerHidden || !self.drawerOpen)];
    }
    [self updateDrawerFolderButtonStates];
}

- (void)navigationChanged:(id)sender {
    if ([sender respondsToSelector:@selector(tag)]) {
        NSInteger navigationTag = [sender tag];
        if (![self.currentAuthState isEqualToString:@"ready"]) {
            navigationTag = 0;
        }
        self.activeSection = [self sectionIdentifierForNavigationTag:navigationTag];
    }
    [self updateVisibleSection];
    if ([self.activeSection isEqualToString:TGSectionProfile] &&
        !self.profileSummaryLoaded && !self.profileSummaryLoading &&
        [self.currentAuthState isEqualToString:@"ready"] && !self.controlsBusy) {
        [self reloadProfileSummaryIfReady];
    }
}

- (void)folderFilterChanged:(id)sender {
    if (![self.currentAuthState isEqualToString:@"ready"] || ![sender respondsToSelector:@selector(tag)]) {
        [self updateDrawerFolderButtonStates];
        return;
    }

    NSInteger tag = [sender tag];
    NSNumber *filterID = nil;
    if (tag >= 0) {
        filterID = [NSNumber numberWithInteger:tag];
    }

    BOOL sameFilter = NO;
    if (!filterID && !self.selectedChatFilterID) {
        sameFilter = YES;
    } else if (filterID && self.selectedChatFilterID && [filterID integerValue] == [self.selectedChatFilterID integerValue]) {
        sameFilter = YES;
    }

    self.selectedChatFilterID = filterID;
    [self updateDrawerFolderButtonStates];
    if (sameFilter) {
        return;
    }

    [self clearForumTopicListState];
    self.chatsExhausted = NO;
    self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
    self.autoChatListLoadArmed = YES;
    self.autoChatListRefreshArmed = YES;
    if (!self.selectedChatFilterID) {
        [self.client invalidateMainChatListExhaustion];
    }
    [self reloadChatsInteractive:YES preserveSelection:NO requestedLimit:TGStatusChatPreviewInitialLimit];
}

- (void)toggleDrawer:(id)sender {
    (void)sender;
    if (TGUserDefaultBoolWithDefault(TGDrawerHiddenDefaultsKey, NO)) {
        self.drawerOpen = NO;
        return;
    }
    self.drawerOpen = !self.drawerOpen;
    [self layoutContentView];
    [self updateVisibleSection];
}

- (void)applyPointingHandCursorToButtonsInView:(NSView *)view {
    if (!view) {
        return;
    }
    NSArray *subviews = [[view subviews] copy];
    NSUInteger index = 0;
    for (index = 0; index < [subviews count]; index++) {
        NSView *subview = [subviews objectAtIndex:index];
        if ([subview isKindOfClass:[NSButton class]] &&
            [subview class] == [NSButton class] &&
            ![subview isKindOfClass:[TGPointingHandButton class]]) {
            object_setClass(subview, [TGPointingHandButton class]);
            [subview discardCursorRects];
        } else if ([subview isKindOfClass:[TGPointingHandButton class]]) {
            [subview discardCursorRects];
        }
        [self applyPointingHandCursorToButtonsInView:subview];
    }
    [subviews release];
}

- (NSButton *)modalCloseButtonWithFrame:(NSRect)frame {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    [button setTitle:@"Close"];
    [button setTarget:self];
    [button setAction:@selector(closeUtilityWindow:)];
    [self applyUtilityButtonStyle:button];
    return button;
}

- (void)closeUtilityWindow:(id)sender {
    if ([sender respondsToSelector:@selector(window)]) {
        [[sender window] close];
    }
}

#include "TGStatusWindowController+MediaWindows.inc"

#include "TGStatusWindowController+UtilityWindows.inc"

#include "TGStatusWindowController+Notifications.inc"

#include "TGStatusWindowController+ClosedChatNavigation.inc"

#include "TGStatusWindowController+SectionLayout.inc"

#include "TGStatusWindowController+ResourceSettings.inc"

#include "TGStatusWindowController+AuthComposerState.inc"

#include "TGStatusWindowController+MessageMediaHitTesting.inc"

#include "TGStatusWindowController+MessagingActions.inc"

#include "TGStatusWindowController+MessageMenus.inc"

#include "TGStatusWindowController+ChatSearchWindow.inc"

#include "TGStatusWindowController+SearchNavigation.inc"

#include "TGStatusWindowController+TableForumFlow.inc"

#include "TGStatusWindowController+MessageDataFlow.inc"

#include "TGStatusWindowController+ComposerMedia.inc"

#include "TGStatusWindowController+SessionLogout.inc"

- (void)dealloc {
    if ([[NSUserNotificationCenter defaultUserNotificationCenter] delegate] == self) {
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:nil];
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(consumePendingComposerRefocus:)
                                               object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(reloadChatFiltersIfReady)
                                               object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(checkForUpdatesOnLaunch)
                                               object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(refreshSelectedMessagesAfterMediaSend)
                                               object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(markCurrentSelectionReadAfterNotification)
                                               object:nil];
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(refreshInlineMediaPlayback)
                                               object:nil];
    [self stopLiveUpdateTimer];
    [self.inlineMediaPlaybackCoordinator invalidate];
    [self.stickerPickerPlaybackCoordinator invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self window] setDelegate:nil];
    [_chatTableView setDataSource:nil];
    [_chatTableView setDelegate:nil];
    [_messageTableView setDataSource:nil];
    [_messageTableView setDelegate:nil];
    [_searchResultsTableView setDataSource:nil];
    [_searchResultsTableView setDelegate:nil];
    [_chatSearchWindowTextField setDelegate:nil];
    [_chatSearchWindow close];
    [_messageContextMenu setDelegate:nil];
    [_chatContextMenu setDelegate:nil];
    [_sendTextField setDelegate:nil];
    [_authTextField setDelegate:nil];
    [_authSecureField setDelegate:nil];
    [_topPanelView release];
    [_sidebarPanelView release];
    [_conversationPanelView release];
    [_diagnosticsPanelView release];
    [_loginPanelView release];
    [_profilePanelView release];
    [_profileScrollView release];
    [_profileContentView release];
    [_settingsPanelView release];
    [_settingsScrollView release];
    [_settingsContentView release];
    [_aboutPanelView release];
    [_bottomNavigationView release];
    [_navigationButtons release];
    [_markAllChatsReadSpinner release];
    [_drawerFolderButtons release];
    [_chatFilterInfos release];
    [_accountBadgeView release];
    [_drawerButton release];
    [_profileSummaryCardView release];
    [_profileInfoCardView release];
    [_profileDetailsCardView release];
    [_profileActionsCardView release];
    [_profileAvatarView release];
    [_settingsAccountCardView release];
    [_settingsThemeCardView release];
    [_settingsSessionCardView release];
    [_settingsDrawerCardView release];
    [_settingsResourceCardView release];
    [_settingsFilesCardView release];
    [_settingsHelpCardView release];
    [_aboutCardView release];
    [_logsCardView release];
    [_diagnosticsLabel release];
    [_titleField release];
    [_statusField release];
    [_detailsScrollView release];
    [_detailsView release];
    [_checkButton release];
    [_loadChatsButton release];
    [_loadMoreChatsButton release];
    [_topicBackButton release];
    [_commentThreadBackButton release];
    [_loadMessagesButton release];
    [_loadOlderMessagesButton release];
    [_chatSearchButton release];
    [_conversationSearchButton release];
    [_searchPanelView release];
    [_searchTextField release];
    [_searchScopePopUpButton release];
    [_searchFilterPopUpButton release];
    [_searchCloseButton release];
    [_searchStatusField release];
    [_searchResultsScrollView release];
    [_searchResultsTableView release];
    [_searchResultItems release];
    [_searchDebounceTimer invalidate];
    [_searchDebounceTimer release];
    [_globalSearchOffset release];
    [_chatSearchWindow release];
    [_chatSearchWindowTextField release];
    [_chatSearchWindowScrollView release];
    [_chatSearchWindowResultsView release];
    [_chatSearchWindowStatusField release];
    [_chatSearchWindowResults release];
    [_chatSearchWindowResultButtons release];
    [_mediaCenterButton release];
    [_mediaCenterWindow release];
    [_mediaCenterContentCardView release];
    [_mediaCenterSearchField release];
    [_mediaCenterTabButtons release];
    [_mediaCenterFilterPopUpButton release];
    [_mediaCenterSortPopUpButton release];
    [_mediaCenterStatusField release];
    [_mediaCenterScrollView release];
    [_mediaCenterResultsView release];
    [_mediaCenterRefreshButton release];
    [_mediaCenterLoadingSpinner release];
    [_mediaCenterPreviewOverlayView release];
    [_mediaCenterPreviewImageView release];
    [_mediaCenterPreviewTitleField release];
    [_mediaCenterPreviewCloseButton release];
    [_mediaCenterItems release];
    [_mediaCenterPaginationAnchorsByFilter release];
    [_mediaCenterExhaustedFilterIdentifiers release];
    [_mediaCenterSeenKeys release];
    [_pinnedMessagePanelView release];
    [_pinnedMessageStripeField release];
    [_pinnedMessageLabelField release];
    [_pinnedMessageTextField release];
    [_pinnedMessageButton release];
    [_pinnedMessageItems release];
    [_pinnedMessageItem release];
    [_replyPanelView release];
    [_replyPanelTitleField release];
    [_replyPanelTextField release];
    [_replyPanelCancelButton release];
    [_replyTargetMessageItem release];
    [_replyTargetChatID release];
    [_replyTargetThreadID release];
    [_replyTargetTopicKind release];
    [_highlightedSearchMessageID release];
    [_searchHighlightTimer invalidate];
    [_searchHighlightTimer release];
    [_sendLabel release];
    [_sendTextFieldBackgroundView release];
    [_sendTextField release];
    [_attachPhotoButton release];
    [_stickerButton release];
    [_voiceRecordButton release];
    [_sendMessageButton release];
    [_authLabel release];
    [_authStateField release];
    [_loginIconView release];
    [_loginBrandField release];
    [_loginTitleField release];
    [_loginHintField release];
    [_authTextFieldBackgroundView release];
    [_authTextField release];
    [_authSecureField release];
    [_authButton release];
    [_busySpinner release];
    [_loginLogsButton release];
    [_loginLanguageButtons release];
    [_loginErrorLocalizationKey release];
    [_chatsLabel release];
    [_messagesLabel release];
    [_selectedChatField release];
    [_typingIndicatorField release];
    [_selectedChatAvatarView release];
    [_selectedChatProfileButton release];
    [_closedChatPlaceholderView release];
    [_closedChatTitleField release];
    [_closedChatHintField release];
    [_closedChatSuggestionViews release];
    [_closedChatSuggestionItems release];
    [_chatScrollSurfaceView release];
    [_chatScrollView release];
    [_chatTableView release];
    [_chatItems release];
    [_chatItemsBeforeTopicList release];
    [_messageScrollSurfaceView release];
    [_messageScrollView release];
    [_messageLoadingSpinner release];
    [_messageJumpToNewestButton release];
    if ([_messageTableView isKindOfClass:[TGMessageTableView class]]) {
        [(TGMessageTableView *)_messageTableView setDropOverlayTarget:nil];
    }
    [_inlineMediaPlaybackCoordinator release];
    [_inlineMediaPlaybackDiagnosticKeys release];
    [_messageTableView release];
    [_messageDropOverlayView release];
    [_messageItems release];
    [_composerDraftsByTargetKey release];
    [_composerDraftSyncTimer invalidate];
    [_composerDraftSyncTimer release];
    [_composerDraftSyncChatID release];
    [_composerDraftSyncThreadID release];
    [_composerDraftSyncTopicKind release];
    [_composerDraftSyncText release];
    [_composerDraftSyncReplyMessageID release];
    [_notificationChatInfoByChatID release];
    [_localMuteUnreadCountsByChatID release];
    [_profileTitleField release];
    [_profileNameField release];
    [_profileUsernameField release];
    [_profileIDField release];
    [_profileStateField release];
    [_profileAboutSectionField release];
    [_profileAccountSectionField release];
    [_profileUsernameRowTitleField release];
    [_profileUsernameRowValueField release];
    [_profilePhoneRowTitleField release];
    [_profilePhoneRowValueField release];
    [_profileIDRowTitleField release];
    [_profileIDRowValueField release];
    [_profileDetailsSeparatorOne release];
    [_profileDetailsSeparatorTwo release];
    [_settingsTitleField release];
    [_settingsStateField release];
    [_settingsLibraryField release];
    [_settingsStorageField release];
    [_settingsDrawerSectionField release];
    [_settingsResourceSectionField release];
    [_settingsFilesSectionField release];
    [_settingsHelpSectionField release];
    [_settingsThemeCategoryLabel release];
    [_themeCategoryPopUpButton release];
    [_settingsThemeLabel release];
    [_themePopUpButton release];
    [_settingsAppearanceButton release];
    [_settingsLogsButton release];
    [_settingsAboutButton release];
    [_settingsNotificationsEnabledButton release];
    [_settingsNotificationSoundButton release];
    [_settingsNotificationBadgeButton release];
    [_settingsNotificationPreviewButton release];
    [_settingsNotificationsWhenActiveButton release];
    [_settingsDrawerHiddenButton release];
    [_settingsTypingIndicatorsButton release];
    [_settingsEconomyModeButton release];
    [_settingsAutoDownloadPhotosButton release];
    [_settingsAutoDownloadVideosButton release];
    [_settingsAutoDownloadDocumentsButton release];
    [_settingsAutoplayAnimatedStickersButton release];
    [_settingsStopInactiveAnimationsButton release];
    [_settingsMaxAutoDownloadLabel release];
    [_settingsMaxAutoDownloadPopUpButton release];
    [_settingsMaxAnimationsLabel release];
    [_settingsMaxAnimationsPopUpButton release];
    [_settingsMediaCacheLimitLabel release];
    [_settingsMediaCacheLimitPopUpButton release];
    [_settingsResourceHintField release];
    [_settingsActiveSessionsButton release];
    [_settingsActiveSessionsDetailField release];
    [_settingsLanguageLabel release];
    [_settingsLanguagePopUpButton release];
    [_settingsMessagesAsBlocksButton release];
    [_settingsChatTextSizeSectionField release];
    [_settingsChatTextSizeSlider release];
    [_settingsChatTextSizeValueField release];
    [_settingsDownloadFolderHelpField release];
    [_settingsDownloadFolderButton release];
    [_settingsStorageUsageButton release];
    [_settingsDeleteLocalDataButton release];
    [_settingsCheckUpdatesButton release];
    [_settingsUpdateDotView release];
    [_storageUsageWindowController release];
    [_logoutButton release];
    [_profileRefreshButton release];
    [_aboutIconView release];
    [_aboutTitleField release];
    [_aboutVersionField release];
    [_aboutCopyrightField release];
    [_aboutLinkField release];
    [_selectedChatID release];
    [_selectedChatTitle release];
    [_selectedChatTypeSummary release];
    [_selectedChatAvatarLocalPath release];
    [_selectedChatLastReadOutboxMessageID release];
    [_selectedMessageThreadID release];
    [_selectedMessageTopicKind release];
    [_commentThreadParentTitle release];
    [_commentThreadParentTypeSummary release];
    [_commentThreadParentAvatarLocalPath release];
    [_topicParentChatID release];
    [_topicParentTitle release];
    [_topicParentAvatarLocalPath release];
    [_selectedChatFilterID release];
    [_client release];
    [_currentAuthState release];
    [_activeSection release];
    [_liveUpdateTimer release];
    [_profileDisplayName release];
    [_profileFirstName release];
    [_profileLastName release];
    [_profileUsername release];
    [_profilePhoneNumber release];
    [_profileUserID release];
    [_profileAvatarLocalPath release];
    [_profileBio release];
    [_lastLogSection release];
    [_availableUpdateVersion release];
    [_logsWindow close];
    [_aboutWindow close];
    [_appearanceWindow close];
    [_activeSessionsWindow close];
    [[_messageViewersWindowController window] close];
    [_mediaPreviewWindow setDelegate:nil];
    [_mediaPreviewWindow close];
    [_mediaPlaybackWindow setDelegate:nil];
    [_mediaPlaybackPlayer pause];
    [_mediaPlaybackTimer invalidate];
    [_mediaPlaybackLayer removeFromSuperlayer];
    [_mediaPlaybackWindow close];
    [_photoSendPreviewWindow setDelegate:nil];
    [_photoSendCaptionField setDelegate:nil];
    [_photoSendPreviewWindow close];
    [_stickerPickerWindow setDelegate:nil];
    [_stickerPickerWindow close];
    [_voiceRecorder stop];
    [_voicePreviewPlayer stop];
    [_voicePreviewTimer invalidate];
    [_voicePreviewWindow setDelegate:nil];
    [_voicePreviewWindow close];
    [_logsWindow release];
    [_aboutWindow release];
    [_appearanceWindow release];
    [_activeSessionsWindow release];
    [_activeSessionsTextView release];
    [_activeSessionsTableView release];
    [_activeSessionsSelectableSessions release];
    [_activeSessionsStatusField release];
    [_activeSessionsRefreshButton release];
    [_activeSessionsTerminatePopup release];
    [_activeSessionsTerminateButton release];
    [_activeSessionsCloseButton release];
    [_activeSessionsSummary release];
    [_mediaPreviewWindow release];
    [_mediaPreviewScrollView release];
    [_mediaPreviewImageView release];
    [_mediaPreviewZoomOutButton release];
    [_mediaPreviewFitButton release];
    [_mediaPreviewZoomInButton release];
    [_mediaPlaybackWindow release];
    [_mediaPlaybackContainerView release];
    [_mediaPlaybackTitleField release];
    [_mediaPlaybackPlayPauseButton release];
    [_mediaPlaybackProgressSlider release];
    [_mediaPlaybackTimeField release];
    [_mediaPlaybackCloseButton release];
    [_mediaPlaybackPlayer release];
    [_mediaPlaybackLayer release];
    [_mediaPlaybackTimer release];
    [_messageViewersWindowController release];
    [_photoSendPreviewWindow release];
    [_photoSendPreviewImageView release];
    [_photoSendCaptionBackgroundView release];
    [_photoSendCaptionField release];
    [_photoSendTitleField release];
    [_photoSendErrorField release];
    [_photoSendMetaField release];
    [_photoSendSendButton release];
    [_photoSendQueueScrollView release];
    [_photoSendQueueContentView release];
    [_pendingPhotoSendPath release];
    [_pendingAttachmentDescriptor release];
    [_pendingAttachmentDescriptors release];
    [_pendingAttachmentTransferState release];
    [_pendingAttachmentQueueItems release];
    [_pendingPhotoSendChatID release];
    [_pendingPhotoSendThreadID release];
    [_pendingPhotoSendTopicKind release];
    [_stickerPickerWindow release];
    [_stickerPickerScrollView release];
    [_stickerPickerContentView release];
    [_stickerPickerRecentButton release];
    [_stickerPickerFavoriteButton release];
    [_stickerPickerSearchField release];
    [_stickerPickerSetScrollView release];
    [_stickerPickerSetContentView release];
    [_stickerPickerItems release];
    [_stickerPickerStickerSets release];
    [_stickerPickerSetCache release];
    [_stickerPickerRailPreviewState release];
    [_stickerPickerSelectedSetID release];
    [_stickerPickerStatusField release];
    [_stickerPickerPlaybackCoordinator release];
    [_voiceRecorder release];
    [_voicePreviewPlayer release];
    [_voiceRecordingPath release];
    [_voiceRecordingStartDate release];
    [_voicePreviewWindow release];
    [_voicePreviewTitleField release];
    [_voicePreviewPlayButton release];
    [_voicePreviewStopButton release];
    [_voicePreviewProgressSlider release];
    [_voicePreviewTimeField release];
    [_voicePreviewCancelButton release];
    [_voicePreviewSendButton release];
    [_voicePreviewErrorField release];
    [_voicePreviewTimer release];
    [_voiceRecordingIndicatorField release];
    [_messageContextMenu release];
    [_chatContextMenu release];
    [_chatsNavigationContextMenu release];
    [_mediaPreviewPath release];
    [_logsWindowDetailsView release];
    [_logsCheckButton release];
    [_appearanceThemePopUpButton release];
    [_typingClearTimer invalidate];
    [_typingClearTimer release];
    [_typingChatID release];
    [_typingIndicatorText release];
    [_pendingNotificationChatID release];
    [_pendingNotificationThreadID release];
    [_suppressedForumTopicAutoOpenChatID release];
    [super dealloc];
}

@end

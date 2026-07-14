#import "TGStatusWindowController.h"
#import "TGActiveSessionsPresentation.h"
#import "TGLocalization.h"
#import "TGMessageActionDialogs.h"
#import "TGMessageLayoutSupport.h"
#import "TGProfilePresentation.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGStatusSupport.h"
#import "TGStickerPickerLayout.h"
#import "TGStatusWindowStyling.h"
#import "TGTheme.h"
#import "TGTypingIndicatorPresentation.h"
#import "TGUpdateSupport.h"
#import "../Media/TGInlineMediaPlaybackCoordinator.h"
#import "../Media/TGMediaImageLoader.h"
#import "../Media/TGMediaItemSupport.h"
#import "../Core/TGChatItem.h"
#import "../Core/TGMessageItem.h"
#import "../Core/TGTDLibClient.h"
#import "../Services/TGLogger.h"
#import <AVFoundation/AVFoundation.h>
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
static NSString * const TGMicrophoneConsentDefaultsKey = @"TelegraphicaMicrophoneConsent";
static NSString * const TGProjectURLString = @"https://github.com/MiChiRose/telegraphica";
static NSString * const TGAuthorURLString = @"https://www.instagram.com/yuramenschikov/";


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
@property (nonatomic, retain) TGGroupedCardView *settingsFilesCardView;
@property (nonatomic, retain) TGGroupedCardView *settingsHelpCardView;
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
@property (nonatomic, retain) NSButton *loadMessagesButton;
@property (nonatomic, retain) NSButton *loadOlderMessagesButton;
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
@property (nonatomic, retain) NSButton *loginLogsButton;
@property (nonatomic, retain) NSArray *loginLanguageButtons;
@property (nonatomic, retain) NSTextField *chatsLabel;
@property (nonatomic, retain) NSTextField *messagesLabel;
@property (nonatomic, retain) NSTextField *selectedChatField;
@property (nonatomic, retain) NSTextField *typingIndicatorField;
@property (nonatomic, retain) TGProfileAvatarView *selectedChatAvatarView;
@property (nonatomic, retain) NSButton *selectedChatProfileButton;
@property (nonatomic, retain) NSView *chatScrollSurfaceView;
@property (nonatomic, retain) NSScrollView *chatScrollView;
@property (nonatomic, retain) NSTableView *chatTableView;
@property (nonatomic, retain) NSMutableArray *chatItems;
@property (nonatomic, retain) NSArray *chatItemsBeforeTopicList;
@property (nonatomic, retain) NSView *messageScrollSurfaceView;
@property (nonatomic, retain) NSScrollView *messageScrollView;
@property (nonatomic, retain) NSTableView *messageTableView;
@property (nonatomic, retain) TGInlineMediaPlaybackCoordinator *inlineMediaPlaybackCoordinator;
@property (nonatomic, retain) TGDropOverlayView *messageDropOverlayView;
@property (nonatomic, retain) NSMutableArray *messageItems;
@property (nonatomic, retain) NSMutableDictionary *composerDraftsByTargetKey;
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
@property (nonatomic, retain) NSTextField *settingsFilesSectionField;
@property (nonatomic, retain) NSTextField *settingsHelpSectionField;
@property (nonatomic, retain) NSTextField *settingsThemeLabel;
@property (nonatomic, retain) NSPopUpButton *themePopUpButton;
@property (nonatomic, retain) NSButton *settingsNotificationsEnabledButton;
@property (nonatomic, retain) NSButton *settingsNotificationSoundButton;
@property (nonatomic, retain) NSButton *settingsNotificationBadgeButton;
@property (nonatomic, retain) NSButton *settingsNotificationPreviewButton;
@property (nonatomic, retain) NSButton *settingsNotificationsWhenActiveButton;
@property (nonatomic, retain) NSButton *settingsDrawerHiddenButton;
@property (nonatomic, retain) NSButton *settingsTypingIndicatorsButton;
@property (nonatomic, retain) NSButton *settingsActiveSessionsButton;
@property (nonatomic, retain) NSTextField *settingsActiveSessionsDetailField;
@property (nonatomic, retain) NSTextField *settingsLanguageLabel;
@property (nonatomic, retain) NSPopUpButton *settingsLanguagePopUpButton;
@property (nonatomic, retain) NSTextField *settingsDownloadFolderHelpField;
@property (nonatomic, retain) NSButton *settingsDownloadFolderButton;
@property (nonatomic, retain) NSButton *settingsCheckUpdatesButton;
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
@property (nonatomic, retain) NSTextField *activeSessionsStatusField;
@property (nonatomic, retain) NSButton *activeSessionsRefreshButton;
@property (nonatomic, retain) NSButton *activeSessionsCloseButton;
@property (nonatomic, assign) NSUInteger activeSessionsRequestGeneration;
@property (nonatomic, retain) NSWindow *mediaPreviewWindow;
@property (nonatomic, retain) NSScrollView *mediaPreviewScrollView;
@property (nonatomic, retain) NSImageView *mediaPreviewImageView;
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
@property (nonatomic, retain) NSWindow *photoSendPreviewWindow;
@property (nonatomic, retain) NSImageView *photoSendPreviewImageView;
@property (nonatomic, retain) NSView *photoSendCaptionBackgroundView;
@property (nonatomic, retain) NSTextField *photoSendCaptionField;
@property (nonatomic, retain) NSTextField *photoSendTitleField;
@property (nonatomic, retain) NSTextField *photoSendErrorField;
@property (nonatomic, retain) NSButton *photoSendSendButton;
@property (nonatomic, copy) NSString *pendingPhotoSendPath;
@property (nonatomic, retain) NSNumber *pendingPhotoSendChatID;
@property (nonatomic, retain) NSNumber *pendingPhotoSendThreadID;
@property (nonatomic, copy) NSString *pendingPhotoSendTopicKind;
@property (nonatomic, retain) NSWindow *stickerPickerWindow;
@property (nonatomic, retain) NSScrollView *stickerPickerScrollView;
@property (nonatomic, retain) NSView *stickerPickerContentView;
@property (nonatomic, copy) NSArray *stickerPickerItems;
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
@property (nonatomic, retain) NSSlider *voicePreviewProgressSlider;
@property (nonatomic, retain) NSTextField *voicePreviewTimeField;
@property (nonatomic, retain) NSButton *voicePreviewSendButton;
@property (nonatomic, retain) NSTextField *voicePreviewErrorField;
@property (nonatomic, retain) NSTimer *voicePreviewTimer;
@property (nonatomic, retain) NSTextField *voiceRecordingIndicatorField;
@property (nonatomic, retain) NSMenu *messageContextMenu;
@property (nonatomic, retain) NSMenu *chatContextMenu;
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
@property (nonatomic, assign) BOOL pendingLiveChatRefresh;
@property (nonatomic, assign) BOOL pendingLiveMessageRefresh;
@property (nonatomic, assign) NSUInteger chatPreviewLimit;
@property (nonatomic, assign) BOOL chatsExhausted;
@property (nonatomic, assign) BOOL olderMessagesExhausted;
@property (nonatomic, assign) BOOL autoOlderMessagesLoadArmed;
@property (nonatomic, assign) BOOL autoChatListLoadArmed;
@property (nonatomic, assign) BOOL autoChatListRefreshArmed;
@property (nonatomic, assign) BOOL forceMessageScrollToNewest;
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
@property (nonatomic, assign) BOOL chatFilterRefreshInFlight;
@property (nonatomic, assign) NSUInteger chatFilterRefreshRetryCount;
@property (nonatomic, assign) BOOL forumTopicRefreshInFlight;
@property (nonatomic, assign) BOOL suppressChatSelectionHandling;
@property (nonatomic, assign) BOOL showingForumTopicList;
@property (nonatomic, assign) CGFloat mediaPreviewZoomScale;
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
@end

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
@synthesize settingsFilesCardView = _settingsFilesCardView;
@synthesize settingsHelpCardView = _settingsHelpCardView;
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
@synthesize loadMessagesButton = _loadMessagesButton;
@synthesize loadOlderMessagesButton = _loadOlderMessagesButton;
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
@synthesize inlineMediaPlaybackCoordinator = _inlineMediaPlaybackCoordinator;
@synthesize messageDropOverlayView = _messageDropOverlayView;
@synthesize messageItems = _messageItems;
@synthesize composerDraftsByTargetKey = _composerDraftsByTargetKey;
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
@synthesize settingsFilesSectionField = _settingsFilesSectionField;
@synthesize settingsHelpSectionField = _settingsHelpSectionField;
@synthesize settingsThemeLabel = _settingsThemeLabel;
@synthesize themePopUpButton = _themePopUpButton;
@synthesize settingsNotificationsEnabledButton = _settingsNotificationsEnabledButton;
@synthesize settingsNotificationSoundButton = _settingsNotificationSoundButton;
@synthesize settingsNotificationBadgeButton = _settingsNotificationBadgeButton;
@synthesize settingsNotificationPreviewButton = _settingsNotificationPreviewButton;
@synthesize settingsNotificationsWhenActiveButton = _settingsNotificationsWhenActiveButton;
@synthesize settingsDrawerHiddenButton = _settingsDrawerHiddenButton;
@synthesize settingsTypingIndicatorsButton = _settingsTypingIndicatorsButton;
@synthesize settingsActiveSessionsButton = _settingsActiveSessionsButton;
@synthesize settingsActiveSessionsDetailField = _settingsActiveSessionsDetailField;
@synthesize settingsLanguageLabel = _settingsLanguageLabel;
@synthesize settingsLanguagePopUpButton = _settingsLanguagePopUpButton;
@synthesize settingsDownloadFolderHelpField = _settingsDownloadFolderHelpField;
@synthesize settingsDownloadFolderButton = _settingsDownloadFolderButton;
@synthesize settingsCheckUpdatesButton = _settingsCheckUpdatesButton;
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
@synthesize activeSessionsStatusField = _activeSessionsStatusField;
@synthesize activeSessionsRefreshButton = _activeSessionsRefreshButton;
@synthesize activeSessionsCloseButton = _activeSessionsCloseButton;
@synthesize activeSessionsRequestGeneration = _activeSessionsRequestGeneration;
@synthesize mediaPreviewWindow = _mediaPreviewWindow;
@synthesize mediaPreviewScrollView = _mediaPreviewScrollView;
@synthesize mediaPreviewImageView = _mediaPreviewImageView;
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
@synthesize photoSendPreviewWindow = _photoSendPreviewWindow;
@synthesize photoSendPreviewImageView = _photoSendPreviewImageView;
@synthesize photoSendCaptionBackgroundView = _photoSendCaptionBackgroundView;
@synthesize photoSendCaptionField = _photoSendCaptionField;
@synthesize photoSendTitleField = _photoSendTitleField;
@synthesize photoSendErrorField = _photoSendErrorField;
@synthesize photoSendSendButton = _photoSendSendButton;
@synthesize pendingPhotoSendPath = _pendingPhotoSendPath;
@synthesize pendingPhotoSendChatID = _pendingPhotoSendChatID;
@synthesize pendingPhotoSendThreadID = _pendingPhotoSendThreadID;
@synthesize pendingPhotoSendTopicKind = _pendingPhotoSendTopicKind;
@synthesize stickerPickerWindow = _stickerPickerWindow;
@synthesize stickerPickerScrollView = _stickerPickerScrollView;
@synthesize stickerPickerContentView = _stickerPickerContentView;
@synthesize stickerPickerItems = _stickerPickerItems;
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
@synthesize voicePreviewProgressSlider = _voicePreviewProgressSlider;
@synthesize voicePreviewTimeField = _voicePreviewTimeField;
@synthesize voicePreviewSendButton = _voicePreviewSendButton;
@synthesize voicePreviewErrorField = _voicePreviewErrorField;
@synthesize voicePreviewTimer = _voicePreviewTimer;
@synthesize voiceRecordingIndicatorField = _voiceRecordingIndicatorField;
@synthesize messageContextMenu = _messageContextMenu;
@synthesize chatContextMenu = _chatContextMenu;
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
@synthesize pendingLiveChatRefresh = _pendingLiveChatRefresh;
@synthesize pendingLiveMessageRefresh = _pendingLiveMessageRefresh;
@synthesize chatPreviewLimit = _chatPreviewLimit;
@synthesize chatsExhausted = _chatsExhausted;
@synthesize olderMessagesExhausted = _olderMessagesExhausted;
@synthesize autoOlderMessagesLoadArmed = _autoOlderMessagesLoadArmed;
@synthesize autoChatListLoadArmed = _autoChatListLoadArmed;
@synthesize autoChatListRefreshArmed = _autoChatListRefreshArmed;
@synthesize forceMessageScrollToNewest = _forceMessageScrollToNewest;
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
@synthesize chatFilterRefreshInFlight = _chatFilterRefreshInFlight;
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
@synthesize mediaPreviewZoomScale = _mediaPreviewZoomScale;
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
        self.client = [[[TGTDLibClient alloc] init] autorelease];
        TGSetActiveThemeIdentifier([[NSUserDefaults standardUserDefaults] stringForKey:TGThemeDefaultsKey]);
        self.chatItems = [NSMutableArray array];
        self.messageItems = [NSMutableArray array];
        self.composerDraftsByTargetKey = [NSMutableDictionary dictionary];
        self.notificationChatInfoByChatID = [NSMutableDictionary dictionary];
        self.localMuteUnreadCountsByChatID = [NSMutableDictionary dictionary];
        self.chatFilterInfos = [NSArray array];
        self.chatPreviewLimit = TGStatusChatPreviewInitialLimit;
        self.activeSection = TGSectionChats;
        self.mediaPreviewZoomScale = 1.0;
        self.autoChatListLoadArmed = YES;
        self.autoChatListRefreshArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
        [self buildContentView];
        [self startLiveUpdateTimerIfNeeded];
        [self performSelector:@selector(connectOnLaunch:) withObject:nil afterDelay:0.15];
        [self performSelector:@selector(checkForUpdatesOnLaunch) withObject:nil afterDelay:3.0];
    }
    return self;
}

- (void)applyTransparentChatTableStyle {
    [self.chatTableView setBackgroundColor:[NSColor clearColor]];
    [self.chatTableView setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
    [self.chatTableView setGridColor:TGClassicTableGridColor()];
    [self.chatTableView setUsesAlternatingRowBackgroundColors:NO];
    [self.chatTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [[self.chatScrollView contentView] setDrawsBackground:NO];
    [[self.chatScrollView contentView] setBackgroundColor:[NSColor clearColor]];
}

- (void)selectThemePopUpItemForIdentifier:(NSString *)identifier {
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
    } else if ([state isEqualToString:@"waitCode"]) {
        [[self.authTextField cell] setPlaceholderString:label];
    } else if ([state isEqualToString:@"waitPassword"]) {
        [[self.authSecureField cell] setPlaceholderString:label];
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
    [self.settingsLibraryField setStringValue:TGLoc(@"settings.appearance")];
    [self.settingsStorageField setStringValue:TGLoc(@"settings.section.sessions")];
    [self.settingsFilesSectionField setStringValue:TGLoc(@"settings.section.files")];
    [self.settingsHelpSectionField setStringValue:TGLoc(@"settings.section.help")];
    [self.settingsThemeLabel setStringValue:TGLoc(@"settings.theme")];
    [self.settingsLanguageLabel setStringValue:TGLoc(@"settings.language")];
    [self.settingsDownloadFolderHelpField setStringValue:TGLoc(@"settings.downloads.help")];
    [self.settingsActiveSessionsDetailField setStringValue:TGLoc(@"settings.sessions.help")];
    [self.settingsActiveSessionsButton setTitle:TGLoc(@"settings.sessions.open")];
    [self.activeSessionsWindow setTitle:TGLoc(@"settings.section.sessions")];
    [self.activeSessionsRefreshButton setTitle:TGLoc(@"settings.sessions.refresh")];
    [self.activeSessionsCloseButton setTitle:TGLoc(@"close")];
    [self.profileRefreshButton setTitle:TGLoc(@"profile.refresh")];
    [self.settingsCheckUpdatesButton setTitle:TGLoc(@"settings.update")];
    [self.settingsAppearanceButton setTitle:@""];
    [self.settingsLogsButton setTitle:TGLoc(@"settings.logs")];
    [self.settingsAboutButton setTitle:TGLoc(@"settings.about")];
    [self.loginLogsButton setTitle:TGLoc(@"login.logs")];
    [self.loginLogsButton setToolTip:TGLoc(@"settings.logs")];
    [self refreshLoginLocalizedText];
    [self refreshDownloadFolderButtonTitle];
    [self selectLanguagePopUpItemForCode:TGLanguageCode()];
    [self refreshLoginLanguageButtons];

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
    [self.titleField setTextColor:TGClassicNavigationTextColor(1.0)];
    [self applyPanelHeaderDetailStyle:self.statusField];
    [self applyPanelHeaderLabelStyle:self.diagnosticsLabel];
    [self applyPanelHeaderLabelStyle:self.chatsLabel];
    [self applyPanelHeaderLabelStyle:self.messagesLabel];
    [self applyPanelHeaderLabelStyle:self.profileTitleField];
    [self applyPanelHeaderLabelStyle:self.settingsTitleField];
    [self applyPanelHeaderDetailStyle:self.selectedChatField];

    [self.loginBrandField setTextColor:TGClassicNavigationTextColor(1.0)];
    [self.loginTitleField setTextColor:TGClassicInkColor()];
    [self.sendLabel setTextColor:TGClassicInkColor()];
    [self.profileNameField setTextColor:TGClassicInkColor()];
    [self.profileNameField setFont:[NSFont boldSystemFontOfSize:18.0]];
    [self.profileUsernameField setFont:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsStateField];
    [self applyMutedLabelStyle:self.settingsDrawerSectionField];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [self applyMutedLabelStyle:self.settingsFilesSectionField];
    [self applyMutedLabelStyle:self.settingsHelpSectionField];
    [self.aboutTitleField setTextColor:TGClassicInkColor()];
    [self applyMutedLabelStyle:self.loginHintField];
    [self applyMutedLabelStyle:self.authLabel];
    [self applyMutedLabelStyle:self.authSecondaryLabel];
    if (self.loginErrorVisible) {
        [self.authStateField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    } else {
        [self applyMutedLabelStyle:self.authStateField];
    }
    [self applyMutedLabelStyle:self.profileUsernameField];
    [self applyMutedLabelStyle:self.profileIDField];
    [self applyMutedLabelStyle:self.profileStateField];
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
    [self.profileUsernameRowTitleField setTextColor:TGClassicInkColor()];
    [self.profilePhoneRowTitleField setTextColor:TGClassicInkColor()];
    [self.profileIDRowTitleField setTextColor:TGClassicInkColor()];
    [self applyMutedLabelStyle:self.profileUsernameRowValueField];
    [self applyMutedLabelStyle:self.profilePhoneRowValueField];
    [self applyMutedLabelStyle:self.profileIDRowValueField];
    [self applyMutedLabelStyle:self.settingsLibraryField];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [self applyMutedLabelStyle:self.settingsDownloadFolderHelpField];
    [self applyMutedLabelStyle:self.settingsActiveSessionsDetailField];
    [self.settingsThemeLabel setTextColor:TGClassicInkColor()];
    [self.settingsLanguageLabel setTextColor:TGClassicInkColor()];
    [self applyMutedLabelStyle:self.aboutVersionField];
    [self applyMutedLabelStyle:self.aboutCopyrightField];
    [self.aboutLinkField setTextColor:TGClassicLinkColor()];
    [self applyDestructiveSettingsButtonStyle:self.logoutButton];

    [self applyComposerTextFieldStyle:self.authTextField];
    [self applyComposerTextFieldStyle:self.authSecureField];
    [self.authTextFieldBackgroundView setNeedsDisplay:YES];
    [self.authSecondaryTextFieldBackgroundView setNeedsDisplay:YES];
    [self applyComposerTextFieldStyle:self.sendTextField];
    [self.sendTextFieldBackgroundView setNeedsDisplay:YES];
    [self applyComposerTextFieldStyle:self.photoSendCaptionField];
    [self.photoSendCaptionBackgroundView setNeedsDisplay:YES];
    [self.voiceRecordingIndicatorField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    [self.settingsAppearanceButton setNeedsDisplay:YES];
    [self.settingsLogsButton setNeedsDisplay:YES];
    [self.settingsAboutButton setNeedsDisplay:YES];
    [self.settingsDownloadFolderButton setNeedsDisplay:YES];
    [self.settingsCheckUpdatesButton setNeedsDisplay:YES];
    [self.settingsActiveSessionsButton setNeedsDisplay:YES];
    [self.profileRefreshButton setNeedsDisplay:YES];
    [self.settingsAccountCardView setNeedsDisplay:YES];
    [self.settingsDrawerCardView setNeedsDisplay:YES];
    [self.settingsThemeCardView setNeedsDisplay:YES];
    [self.settingsSessionCardView setNeedsDisplay:YES];
    [self.settingsFilesCardView setNeedsDisplay:YES];
    [self.settingsHelpCardView setNeedsDisplay:YES];
    [self.bottomNavigationView setNeedsDisplay:YES];
    [self.chatScrollSurfaceView setNeedsDisplay:YES];
    [self.messageScrollSurfaceView setNeedsDisplay:YES];
    [self applySkeuomorphicScrollStyle:self.detailsScrollView];
    [self applySkeuomorphicScrollStyle:self.chatScrollView];
    [self applySkeuomorphicScrollStyle:self.messageScrollView];
    [self.detailsView setTextColor:TGClassicMutedInkColor()];
    [self.detailsView setBackgroundColor:TGClassicTablePaperColor()];

    [self applySkeuomorphicTableStyle:self.chatTableView];
    [self applySkeuomorphicTableStyle:self.messageTableView];
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
    [self.chatsLabel setStringValue:@"Chats"];
    [self.loadChatsButton setToolTip:@"Refresh chats"];
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
        [contentView addSubview:navigationButton];
        [navigationButtons addObject:navigationButton];
    }
    self.navigationButtons = navigationButtons;

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
                                      text:@"Chats"
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

    self.messageDropOverlayView = [[[TGDropOverlayView alloc] initWithFrame:NSMakeRect(42, 90, 672, 84)] autorelease];
    [self.messageDropOverlayView setHidden:YES];
    [self.messageDropOverlayView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:self.messageDropOverlayView];

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

    self.settingsStateField = [self labelWithFrame:NSMakeRect(64, 458, 760, 24)
                                              text:@"Interface & notifications"
                                              font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsStateField];
    [contentView addSubview:self.settingsStateField];

    self.settingsLibraryField = [self labelWithFrame:NSMakeRect(64, 424, 760, 24)
                                                text:@""
                                                font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsLibraryField];
    [[self.settingsLibraryField cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
    [contentView addSubview:self.settingsLibraryField];

    self.settingsStorageField = [self labelWithFrame:NSMakeRect(64, 380, 760, 44)
                                                text:@""
                                                font:[NSFont systemFontOfSize:12.0]];
    [[self.settingsStorageField cell] setLineBreakMode:NSLineBreakByWordWrapping];
    [self applyMutedLabelStyle:self.settingsStorageField];
    [contentView addSubview:self.settingsStorageField];

    self.settingsDrawerSectionField = [self labelWithFrame:NSMakeRect(64, 356, 760, 18)
                                                      text:@"Drawer"
                                                      font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsDrawerSectionField];
    [contentView addSubview:self.settingsDrawerSectionField];

    self.settingsFilesSectionField = [self labelWithFrame:NSMakeRect(64, 206, 760, 18)
                                                     text:@"Files"
                                                     font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsFilesSectionField];
    [contentView addSubview:self.settingsFilesSectionField];

    self.settingsHelpSectionField = [self labelWithFrame:NSMakeRect(64, 126, 760, 18)
                                                    text:@"Help"
                                                    font:[NSFont systemFontOfSize:13.0]];
    [self applyMutedLabelStyle:self.settingsHelpSectionField];
    [contentView addSubview:self.settingsHelpSectionField];

    self.settingsThemeLabel = [self labelWithFrame:NSMakeRect(64, 332, 88, 24)
                                              text:@"Theme"
                                              font:[NSFont systemFontOfSize:13.0]];
    [contentView addSubview:self.settingsThemeLabel];

    self.themePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(154, 326, 300, 30) pullsDown:NO] autorelease];
    NSArray *themeIdentifiers = TGThemeIdentifiers();
    NSUInteger themeIndex = 0;
    for (themeIndex = 0; themeIndex < [themeIdentifiers count]; themeIndex++) {
        NSString *themeIdentifier = [themeIdentifiers objectAtIndex:themeIndex];
        [self.themePopUpButton addItemWithTitle:TGThemeDisplayNameForIdentifier(themeIdentifier)];
        [[self.themePopUpButton lastItem] setRepresentedObject:themeIdentifier];
    }
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

    self.settingsCheckUpdatesButton = [[[NSButton alloc] initWithFrame:NSMakeRect(64, 152, 260, 22)] autorelease];
    [self.settingsCheckUpdatesButton setTitle:@"Check for Updates"];
    [self.settingsCheckUpdatesButton setTarget:self];
    [self.settingsCheckUpdatesButton setAction:@selector(checkForUpdatesManually:)];
    [self applyUtilityButtonStyle:self.settingsCheckUpdatesButton];
    [self.settingsCheckUpdatesButton setAutoresizingMask:NSViewMaxYMargin];
    [contentView addSubview:self.settingsCheckUpdatesButton];

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
                                     self.settingsFilesCardView,
                                     self.settingsHelpCardView,
                                     self.settingsStateField,
                                     self.settingsLibraryField,
                                     self.settingsStorageField,
                                     self.settingsDrawerSectionField,
                                     self.settingsFilesSectionField,
                                     self.settingsHelpSectionField,
                                     self.settingsThemeLabel,
                                     self.themePopUpButton,
                                     self.settingsNotificationsEnabledButton,
                                     self.settingsNotificationSoundButton,
                                     self.settingsNotificationBadgeButton,
                                     self.settingsNotificationPreviewButton,
                                     self.settingsNotificationsWhenActiveButton,
                                     self.settingsDrawerHiddenButton,
                                     self.settingsTypingIndicatorsButton,
                                     self.settingsLanguageLabel,
                                     self.settingsLanguagePopUpButton,
                                     self.settingsActiveSessionsDetailField,
                                     self.settingsActiveSessionsButton,
                                     self.settingsDownloadFolderHelpField,
                                     self.settingsDownloadFolderButton,
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
                             @"All", @"title",
                             nil];
    [folderItems addObject:allItem];
    if ([self.chatFilterInfos count] > 0) {
        [folderItems addObjectsFromArray:self.chatFilterInfos];
    }

    for (index = 0; index < [folderItems count]; index++) {
        NSDictionary *folderInfo = [folderItems objectAtIndex:index];
        NSString *buttonTitle = [folderInfo objectForKey:@"title"];
        id filterID = [folderInfo objectForKey:@"id"];
        if (![buttonTitle isKindOfClass:[NSString class]] || [buttonTitle length] == 0 || ![filterID respondsToSelector:@selector(integerValue)]) {
            continue;
        }

        NSButton *folderButton = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 500 - (index * 48), 92, 42)] autorelease];
        TGNavigationButtonCell *folderCell = [[[TGNavigationButtonCell alloc] initTextCell:buttonTitle] autorelease];
        [folderCell setButtonType:NSToggleButton];
        [folderButton setCell:folderCell];
        [folderButton setTitle:buttonTitle];
        [folderButton setButtonType:NSToggleButton];
        [folderButton setBordered:NO];
        [folderButton setTag:[filterID integerValue]];
        [folderButton setToolTip:([filterID integerValue] < 0) ? @"All chats" : [NSString stringWithFormat:@"%@ folder", buttonTitle]];
        [folderButton setTarget:self];
        [folderButton setAction:@selector(folderFilterChanged:)];
        [folderButton setAutoresizingMask:(NSViewMaxXMargin | NSViewMinYMargin)];
        [contentView addSubview:folderButton];
        [buttons addObject:folderButton];
    }

    self.drawerFolderButtons = buttons;
    [self updateDrawerFolderButtonStates];
    [self layoutContentView];
}

- (void)reloadChatFiltersIfReady {
    if (![self.currentAuthState isEqualToString:@"ready"] || self.chatFilterRefreshInFlight) {
        return;
    }

    self.chatFilterRefreshInFlight = YES;
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSArray *filters = [[client chatFilterInfoItemsWithTimeout:1.5] retain];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client == client && [self.currentAuthState isEqualToString:@"ready"]) {
                self.chatFilterInfos = filters ? filters : [NSArray array];
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
            [filters release];
            [client release];
        });

        [pool drain];
    });
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

- (void)openSelectedChatProfile:(id)sender {
    (void)sender;
    if (!self.selectedChatID) {
        return;
    }

    NSString *title = ([self.selectedChatTitle length] > 0) ? self.selectedChatTitle : @"Selected chat";
    title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([title length] == 0) {
        title = @"Selected chat";
    }

    NSMutableString *details = [NSMutableString string];
    if ([self.selectedChatTypeSummary length] > 0) {
        [details appendFormat:@"%@\n", self.selectedChatTypeSummary];
    }
    if ([self.selectedChatID respondsToSelector:@selector(longLongValue)]) {
        [details appendFormat:@"Chat ID: %lld", [self.selectedChatID longLongValue]];
    }
    if ([self.selectedMessageThreadID respondsToSelector:@selector(longLongValue)]) {
        if ([details length] > 0) {
            [details appendString:@"\n"];
        }
        [details appendFormat:@"Topic ID: %lld", [self.selectedMessageThreadID longLongValue]];
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setMessageText:title];
    [alert setInformativeText:([details length] > 0) ? details : @"No additional profile fields are available yet."];
    [alert addButtonWithTitle:@"Close"];
    if ([self.selectedChatAvatarLocalPath length] > 0) {
        NSImage *avatarImage = [[[NSImage alloc] initWithContentsOfFile:self.selectedChatAvatarLocalPath] autorelease];
        if (avatarImage) {
            [alert setIcon:avatarImage];
        }
    }
    [alert runModal];
}

- (void)renderActiveSessionsSummary:(NSDictionary *)summary errorMessage:(NSString *)errorMessage {
    [self.activeSessionsRefreshButton setEnabled:YES];
    if ([errorMessage length] > 0 || ![summary isKindOfClass:[NSDictionary class]]) {
        NSString *message = [NSString stringWithFormat:TGLoc(@"settings.sessions.failed"),
                             ([errorMessage length] > 0 ? errorMessage : TGLoc(@"settings.sessions.unknownError"))];
        [self.activeSessionsStatusField setStringValue:message];
        [self.activeSessionsTextView setString:@""];
        return;
    }

    TGActiveSessionsLocalizationBlock localize = ^NSString *(NSString *key) {
        return TGLoc(key);
    };
    [self.activeSessionsStatusField setStringValue:[TGActiveSessionsPresentation statusTextForSummary:summary
                                                                                              localize:localize]];
    NSAttributedString *output = [TGActiveSessionsPresentation detailsTextForSummary:summary
                                                                         languageCode:TGLanguageCode()
                                                                             localize:localize
                                                                            textColor:TGClassicInkColor()
                                                                           mutedColor:TGClassicMutedInkColor()];
    [[self.activeSessionsTextView textStorage] setAttributedString:output];
}

- (void)reloadActiveSessions:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self.activeSessionsRefreshButton setEnabled:YES];
        return;
    }
    NSUInteger requestGeneration = self.activeSessionsRequestGeneration + 1;
    self.activeSessionsRequestGeneration = requestGeneration;
    [self.activeSessionsStatusField setStringValue:TGLoc(@"settings.sessions.loading")];
    [self.activeSessionsRefreshButton setEnabled:NO];
    [self.activeSessionsTextView setString:@""];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *sessionsError = nil;
        NSDictionary *summary = [[client activeSessionsSummaryWithTimeout:8.0 error:&sessionsError] retain];
        NSString *errorMessage = [[sessionsError localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (requestGeneration == self.activeSessionsRequestGeneration &&
                self.client == client &&
                [self.currentAuthState isEqualToString:@"ready"]) {
                [self renderActiveSessionsSummary:summary errorMessage:errorMessage];
            } else if (requestGeneration == self.activeSessionsRequestGeneration) {
                [self.activeSessionsRefreshButton setEnabled:YES];
            }
            [summary release];
            [errorMessage release];
            [client release];
        });
        [pool drain];
    });
}

- (void)showActiveSessionsWindow:(id)sender {
    (void)sender;
    if (!self.activeSessionsWindow) {
        NSRect frame = NSMakeRect(0, 0, 620, 480);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSResizableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:TGLoc(@"settings.section.sessions")];
        [window setMinSize:NSMakeSize(500.0, 360.0)];
        [window setReleasedWhenClosed:NO];
        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        NSTextField *statusField = [self labelWithFrame:NSMakeRect(24, 438, 440, 20)
                                                    text:TGLoc(@"settings.sessions.loading")
                                                    font:[NSFont systemFontOfSize:12.0]];
        [self applyMutedLabelStyle:statusField];
        [statusField setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [contentView addSubview:statusField];
        self.activeSessionsStatusField = statusField;

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 58, 584, 366)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [contentView addSubview:cardView];
        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30, 70, 560, 342)] autorelease];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [self applySkeuomorphicScrollStyle:scrollView];
        NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
        [textView setEditable:NO];
        [textView setSelectable:YES];
        [textView setDrawsBackground:NO];
        [scrollView setDocumentView:textView];
        [contentView addSubview:scrollView];
        self.activeSessionsTextView = textView;

        NSButton *refreshButton = [[[NSButton alloc] initWithFrame:NSMakeRect(350, 18, 120, 30)] autorelease];
        [refreshButton setTitle:TGLoc(@"settings.sessions.refresh")];
        [refreshButton setTarget:self];
        [refreshButton setAction:@selector(reloadActiveSessions:)];
        [self applyUtilityButtonStyle:refreshButton];
        [refreshButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:refreshButton];
        self.activeSessionsRefreshButton = refreshButton;

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(482, 18, 120, 30)];
        [closeButton setTitle:TGLoc(@"close")];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];
        self.activeSessionsCloseButton = closeButton;
        self.activeSessionsWindow = window;
    }
    [self.activeSessionsWindow setTitle:TGLoc(@"settings.section.sessions")];
    [self.activeSessionsRefreshButton setTitle:TGLoc(@"settings.sessions.refresh")];
    [self.activeSessionsWindow center];
    [self.activeSessionsWindow makeKeyAndOrderFront:nil];
    [self reloadActiveSessions:nil];
}

- (void)refreshProfile:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"] || self.controlsBusy) {
        [self.profileRefreshButton setEnabled:YES];
        return;
    }
    self.profileSummaryLoaded = NO;
    [self.profileRefreshButton setEnabled:NO];
    [self reloadProfileSummaryIfReady];
}

- (void)showAppearanceWindow:(id)sender {
    (void)sender;
    if (!self.appearanceWindow) {
        NSRect frame = NSMakeRect(0, 0, 480, 260);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:@"Appearance"];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(30, 72, 420, 124)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
        [contentView addSubview:cardView];

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(34, 214, 220, 22)
                                                  text:@"Appearance"
                                                  font:[NSFont boldSystemFontOfSize:14.0]];
        [titleField setAutoresizingMask:NSViewMinYMargin];
        [contentView addSubview:titleField];

        NSTextField *themeLabel = [self labelWithFrame:NSMakeRect(54, 142, 86, 22)
                                                  text:@"Theme"
                                                  font:[NSFont systemFontOfSize:13.0]];
        [contentView addSubview:themeLabel];

        NSPopUpButton *themePopUpButton = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(142, 136, 282, 30) pullsDown:NO] autorelease];
        NSArray *themeIdentifiers = TGThemeIdentifiers();
        NSUInteger themeIndex = 0;
        for (themeIndex = 0; themeIndex < [themeIdentifiers count]; themeIndex++) {
            NSString *themeIdentifier = [themeIdentifiers objectAtIndex:themeIndex];
            [themePopUpButton addItemWithTitle:TGThemeDisplayNameForIdentifier(themeIdentifier)];
            [[themePopUpButton lastItem] setRepresentedObject:themeIdentifier];
        }
        [themePopUpButton setTarget:self];
        [themePopUpButton setAction:@selector(themeSelectionChanged:)];
        [themePopUpButton setAutoresizingMask:NSViewMaxYMargin];
        [contentView addSubview:themePopUpButton];
        self.appearanceThemePopUpButton = themePopUpButton;

        NSTextField *hintField = [self labelWithFrame:NSMakeRect(54, 98, 370, 22)
                                                 text:@"Theme changes apply immediately."
                                                 font:[NSFont systemFontOfSize:12.0]];
        [self applyMutedLabelStyle:hintField];
        [contentView addSubview:hintField];

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(330, 22, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.appearanceWindow = window;
    }

    [self selectThemePopUpItemForIdentifier:TGCurrentThemeIdentifier()];
    [self.appearanceWindow center];
    [self.appearanceWindow makeKeyAndOrderFront:nil];
}

- (void)showLogsWindow:(id)sender {
    (void)sender;
    if (!self.logsWindow) {
        NSRect frame = NSMakeRect(0, 0, 660, 440);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:@"Diagnostic Logs"];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(18, 58, 624, 354)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [contentView addSubview:cardView];

        NSScrollView *scrollView = [[[NSScrollView alloc] initWithFrame:NSMakeRect(30, 70, 600, 330)] autorelease];
        [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [self applySkeuomorphicScrollStyle:scrollView];

        NSTextView *textView = [[[NSTextView alloc] initWithFrame:[[scrollView contentView] bounds]] autorelease];
        [textView setEditable:NO];
        [textView setSelectable:YES];
        [textView setFont:[NSFont userFixedPitchFontOfSize:11.0]];
        [textView setTextColor:TGClassicMutedInkColor()];
        [textView setBackgroundColor:TGClassicTablePaperColor()];
        [scrollView setDocumentView:textView];
        [contentView addSubview:scrollView];
        self.logsWindowDetailsView = textView;

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(22, 414, 300, 20)
                                                  text:@"Diagnostic Logs"
                                                  font:[NSFont boldSystemFontOfSize:13.0]];
        [titleField setAutoresizingMask:NSViewMinYMargin];
        [contentView addSubview:titleField];

        NSButton *checkButton = [[[NSButton alloc] initWithFrame:NSMakeRect(390, 18, 120, 30)] autorelease];
        [checkButton setTitle:@"Check"];
        [checkButton setTarget:self];
        [checkButton setAction:@selector(checkTDLib:)];
        [self applyUtilityButtonStyle:checkButton];
        [checkButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:checkButton];
        self.logsCheckButton = checkButton;

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(522, 18, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.logsWindow = window;
    }

    [self.logsCheckButton setEnabled:!self.controlsBusy];
    [self.logsWindowDetailsView setString:(self.detailsView ? [self.detailsView string] : @"")];
    NSRange endRange = NSMakeRange([[self.logsWindowDetailsView string] length], 0);
    [self.logsWindowDetailsView scrollRangeToVisible:endRange];
    [self.logsWindow center];
    [self.logsWindow makeKeyAndOrderFront:nil];
}

- (void)showAboutWindow:(id)sender {
    (void)sender;
    if (!self.aboutWindow) {
        NSRect frame = NSMakeRect(0, 0, 480, 440);
        NSWindow *window = [[[NSWindow alloc] initWithContentRect:frame
                                                        styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                          backing:NSBackingStoreBuffered
                                                            defer:NO] autorelease];
        [window setTitle:TGLoc(@"about.title")];
        [window setReleasedWhenClosed:NO];

        TGUtilityWindowView *contentView = [[[TGUtilityWindowView alloc] initWithFrame:frame] autorelease];
        [contentView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [window setContentView:contentView];

        TGGroupedCardView *cardView = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(30, 54, 420, 352)] autorelease];
        [cardView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
        [contentView addSubview:cardView];

        NSImageView *iconView = [[[NSImageView alloc] initWithFrame:NSMakeRect(190, 280, 100, 100)] autorelease];
        NSImage *appIcon = [NSImage imageNamed:@"Telegraphica"];
        if (!appIcon) {
            appIcon = [NSImage imageNamed:@"NSApplicationIcon"];
        }
        [iconView setImage:appIcon];
        [iconView setImageScaling:NSImageScaleProportionallyUpOrDown];
        [iconView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin)];
        [contentView addSubview:iconView];

        NSTextField *titleField = [self labelWithFrame:NSMakeRect(70, 242, 340, 30)
                                                  text:@"Telegraphica"
                                                  font:[NSFont boldSystemFontOfSize:22.0]];
        [titleField setAlignment:NSCenterTextAlignment];
        [contentView addSubview:titleField];

        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *version = [info objectForKey:@"CFBundleShortVersionString"];
        NSString *build = [info objectForKey:@"CFBundleVersion"];
        NSString *versionText = [NSString stringWithFormat:TGLoc(@"about.version"), version ? version : @"0.1.0", build ? build : @"0.1.0"];
        NSTextField *versionField = [self labelWithFrame:NSMakeRect(70, 212, 340, 22)
                                                    text:versionText
                                                    font:[NSFont systemFontOfSize:12.0]];
        [versionField setAlignment:NSCenterTextAlignment];
        [self applyMutedLabelStyle:versionField];
        [contentView addSubview:versionField];

        NSString *copyrightText = [NSString stringWithFormat:@"Copyright %@. %@", TGCurrentYearString(), TGLoc(@"about.rights")];
        NSTextField *copyrightField = [self labelWithFrame:NSMakeRect(60, 178, 360, 22)
                                                      text:copyrightText
                                                      font:[NSFont systemFontOfSize:12.0]];
        [copyrightField setAlignment:NSCenterTextAlignment];
        [[copyrightField cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [self applyMutedLabelStyle:copyrightField];
        [contentView addSubview:copyrightField];

        NSDictionary *linkAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                        TGClassicLinkColor(), NSForegroundColorAttributeName,
                                        [NSNumber numberWithInteger:NSUnderlineStyleSingle], NSUnderlineStyleAttributeName,
                                        nil];
        NSButton *authorButton = [[[NSButton alloc] initWithFrame:NSMakeRect(70, 140, 340, 24)] autorelease];
        [authorButton setAttributedTitle:[[[NSAttributedString alloc] initWithString:TGLoc(@"about.author") attributes:linkAttributes] autorelease]];
        [authorButton setBordered:NO];
        [authorButton setButtonType:NSMomentaryPushInButton];
        [authorButton setTarget:self];
        [authorButton setAction:@selector(openAuthorPage:)];
        [authorButton setToolTip:TGAuthorURLString];
        [[authorButton cell] setAlignment:NSCenterTextAlignment];
        [contentView addSubview:authorButton];

        NSButton *projectButton = [[[NSButton alloc] initWithFrame:NSMakeRect(70, 108, 340, 24)] autorelease];
        [projectButton setAttributedTitle:[[[NSAttributedString alloc] initWithString:TGLoc(@"about.project") attributes:linkAttributes] autorelease]];
        [projectButton setBordered:NO];
        [projectButton setButtonType:NSMomentaryPushInButton];
        [projectButton setTarget:self];
        [projectButton setAction:@selector(openProjectPage:)];
        [projectButton setToolTip:TGProjectURLString];
        [[projectButton cell] setAlignment:NSCenterTextAlignment];
        [contentView addSubview:projectButton];

        NSButton *closeButton = [self modalCloseButtonWithFrame:NSMakeRect(180, 18, 120, 30)];
        [closeButton setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewMaxYMargin)];
        [contentView addSubview:closeButton];

        self.aboutWindow = window;
    }

    [self.aboutWindow center];
    [self.aboutWindow makeKeyAndOrderFront:nil];
}

- (void)openProjectPage:(id)sender {
    (void)sender;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:TGProjectURLString]];
}

- (void)openAuthorPage:(id)sender {
    (void)sender;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:TGAuthorURLString]];
}

- (void)themeSelectionChanged:(id)sender {
    NSPopUpButton *sourcePopUpButton = [sender isKindOfClass:[NSPopUpButton class]] ? (NSPopUpButton *)sender : self.themePopUpButton;
    NSMenuItem *selectedItem = [sourcePopUpButton selectedItem];
    NSString *themeIdentifier = [selectedItem representedObject];
    if (!TGThemeIdentifierIsValid(themeIdentifier)) {
        themeIdentifier = TGThemeIdentifierVKBlue;
    }
    TGSetActiveThemeIdentifier(themeIdentifier);
    [[NSUserDefaults standardUserDefaults] setObject:themeIdentifier forKey:TGThemeDefaultsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self selectThemePopUpItemForIdentifier:themeIdentifier];
    [self refreshThemeAppearance];
    [self appendDetail:[NSString stringWithFormat:@"Theme changed: %@", TGThemeDisplayNameForIdentifier(themeIdentifier)]];
}

#include "TGStatusWindowController+Notifications.inc"

- (void)showView:(NSView *)view visible:(BOOL)visible {
    [view setHidden:!visible];
}

- (void)showMessageDropOverlay:(BOOL)visible {
    self.messageDropOverlayVisible = visible;
    BOOL showChats = ([self.currentAuthState isEqualToString:@"ready"] && [(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionChats]);
    [self showView:self.messageDropOverlayView visible:(visible && showChats)];
    [self.messageDropOverlayView setNeedsDisplay:YES];
}

- (void)messageTableViewDragDidEnd:(id)sender {
    (void)sender;
    [self showMessageDropOverlay:NO];
}

- (void)updateVisibleSection {
    BOOL ready = [self.currentAuthState isEqualToString:@"ready"];
    NSString *section = self.activeSection ? self.activeSection : TGSectionChats;
    if (!ready && ![section isEqualToString:TGSectionChats]) {
        section = TGSectionChats;
        self.activeSection = TGSectionChats;
    }
    BOOL showLogin = !ready;
    BOOL drawerHidden = TGUserDefaultBoolWithDefault(TGDrawerHiddenDefaultsKey, NO);

    [self updateNavigationButtonsForSection:section enabled:!self.controlsBusy];
    [self showView:self.topPanelView visible:(ready && !drawerHidden)];
    [self showView:self.drawerButton visible:(ready && !drawerHidden)];
    [self showView:self.accountBadgeView visible:(ready && !drawerHidden && self.drawerOpen)];
    [self showView:self.bottomNavigationView visible:ready];

    [self showView:self.loginPanelView visible:showLogin];
    [self showView:self.loginIconView visible:showLogin];
    [self showView:self.loginBrandField visible:showLogin];
    [self showView:self.loginTitleField visible:showLogin];
    [self showView:self.loginHintField visible:showLogin];

    [self showView:self.authLabel visible:showLogin];
    [self showView:self.authStateField visible:(showLogin && self.loginErrorVisible)];
    [self showView:self.authTextFieldBackgroundView visible:(showLogin && [self isAuthInputState:self.currentAuthState])];
    [self showView:self.authTextField visible:(showLogin && ([self.currentAuthState isEqualToString:@"waitPhoneNumber"] || [self.currentAuthState isEqualToString:@"waitCode"]))];
    [self showView:self.authSecondaryLabel visible:NO];
    [self showView:self.authSecondaryTextFieldBackgroundView visible:NO];
    [self showView:self.authSecureField visible:(showLogin && [self.currentAuthState isEqualToString:@"waitPassword"])];
    [self showView:self.authButton visible:(showLogin && [self isAuthInputState:self.currentAuthState])];
    [self showView:self.loginLogsButton visible:showLogin];
    NSUInteger loginLanguageIndex = 0;
    for (loginLanguageIndex = 0; loginLanguageIndex < [self.loginLanguageButtons count]; loginLanguageIndex++) {
        [self showView:[self.loginLanguageButtons objectAtIndex:loginLanguageIndex] visible:showLogin];
    }

    BOOL showChats = (ready && [section isEqualToString:TGSectionChats]);
    [self showView:self.sidebarPanelView visible:showChats];
    [self showView:self.conversationPanelView visible:showChats];
    [self showView:self.chatsLabel visible:showChats];
    [self showView:self.topicBackButton visible:(showChats && self.showingForumTopicList)];
    [self showView:self.loadChatsButton visible:showChats];
    [self showView:self.loadMoreChatsButton visible:NO];
    [self showView:self.chatScrollSurfaceView visible:showChats];
    [self showView:self.chatScrollView visible:showChats];
    [self showView:self.messagesLabel visible:NO];
    [self showView:self.loadMessagesButton visible:showChats];
    [self showView:self.loadOlderMessagesButton visible:NO];
    [self showView:self.selectedChatField visible:showChats];
    [self showView:self.typingIndicatorField visible:(showChats && [[self.typingIndicatorField stringValue] length] > 0)];
    BOOL showSelectedChatProfile = (showChats && self.selectedChatID != nil);
    [self showView:self.selectedChatAvatarView visible:showSelectedChatProfile];
    [self showView:self.selectedChatProfileButton visible:showSelectedChatProfile];
    [self showView:self.messageScrollSurfaceView visible:showChats];
    [self showView:self.messageScrollView visible:showChats];
    if (showChats) {
        [self scheduleInlineMediaPlaybackRefresh];
    } else {
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
    }
    if (!showChats) {
        self.messageDropOverlayVisible = NO;
    }
    [self showView:self.messageDropOverlayView visible:(showChats && self.messageDropOverlayVisible)];
    [self showView:self.sendLabel visible:NO];
    [self showView:self.attachPhotoButton visible:showChats];
    [self showView:self.stickerButton visible:showChats];
    [self showView:self.voiceRecordButton visible:showChats];
    [self showView:self.voiceRecordingIndicatorField visible:(showChats && [self.voiceRecorder isRecording])];
    [self showView:self.sendTextFieldBackgroundView visible:showChats];
    [self showView:self.sendTextField visible:showChats];
    [self showView:self.sendMessageButton visible:showChats];

    BOOL showProfile = (ready && [section isEqualToString:TGSectionProfile]);
    BOOL profileHasBio = ([[self.profileStateField stringValue] length] > 0);
    BOOL profileHasUsername = ([[self.profileUsernameRowValueField stringValue] length] > 0);
    BOOL profileHasPhone = ([[self.profilePhoneRowValueField stringValue] length] > 0);
    BOOL profileHasID = ([[self.profileIDRowValueField stringValue] length] > 0);
    NSUInteger profileDetailRows = (profileHasUsername ? 1 : 0) + (profileHasPhone ? 1 : 0) + (profileHasID ? 1 : 0);
    BOOL showProfileDetails = (showProfile && profileDetailRows > 0);
    [self showView:self.profilePanelView visible:showProfile];
    [self showView:self.profileScrollView visible:showProfile];
    [self showView:self.profileSummaryCardView visible:showProfile];
    [self showView:self.profileInfoCardView visible:(showProfile && profileHasBio)];
    [self showView:self.profileDetailsCardView visible:showProfileDetails];
    [self showView:self.profileActionsCardView visible:showProfile];
    [self showView:self.profileAvatarView visible:showProfile];
    [self showView:self.profileTitleField visible:showProfile];
    [self showView:self.profileNameField visible:(showProfile && [[self.profileNameField stringValue] length] > 0)];
    [self showView:self.profileUsernameField visible:(showProfile && [[self.profileUsernameField stringValue] length] > 0)];
    [self showView:self.profileIDField visible:NO];
    [self showView:self.profileStateField visible:(showProfile && profileHasBio)];
    [self showView:self.profileAboutSectionField visible:(showProfile && profileHasBio)];
    [self showView:self.profileAccountSectionField visible:showProfileDetails];
    [self showView:self.profileUsernameRowTitleField visible:(showProfile && profileHasUsername)];
    [self showView:self.profileUsernameRowValueField visible:(showProfile && profileHasUsername)];
    [self showView:self.profilePhoneRowTitleField visible:(showProfile && profileHasPhone)];
    [self showView:self.profilePhoneRowValueField visible:(showProfile && profileHasPhone)];
    [self showView:self.profileIDRowTitleField visible:(showProfile && profileHasID)];
    [self showView:self.profileIDRowValueField visible:(showProfile && profileHasID)];
    [self showView:self.profileDetailsSeparatorOne visible:(showProfileDetails && profileDetailRows > 1)];
    [self showView:self.profileDetailsSeparatorTwo visible:(showProfileDetails && profileDetailRows > 2)];
    [self showView:self.profileRefreshButton visible:NO];
    [self showView:self.logoutButton visible:showProfile];

    BOOL showSettings = (ready && [section isEqualToString:TGSectionSettings]);
    [self showView:self.settingsPanelView visible:showSettings];
    [self showView:self.settingsScrollView visible:showSettings];
    [self showView:self.settingsAccountCardView visible:showSettings];
    [self showView:self.settingsDrawerCardView visible:showSettings];
    [self showView:self.settingsThemeCardView visible:showSettings];
    [self showView:self.settingsFilesCardView visible:showSettings];
    [self showView:self.settingsHelpCardView visible:showSettings];
    [self showView:self.settingsSessionCardView visible:showSettings];
    [self showView:self.settingsTitleField visible:showSettings];
    [self showView:self.settingsStateField visible:showSettings];
    [self showView:self.settingsDrawerSectionField visible:showSettings];
    [self showView:self.settingsLibraryField visible:showSettings];
    [self showView:self.settingsFilesSectionField visible:showSettings];
    [self showView:self.settingsHelpSectionField visible:showSettings];
    [self showView:self.settingsStorageField visible:showSettings];
    [self showView:self.settingsThemeLabel visible:showSettings];
    [self showView:self.themePopUpButton visible:showSettings];
    [self showView:self.settingsNotificationsEnabledButton visible:showSettings];
    [self showView:self.settingsNotificationSoundButton visible:showSettings];
    [self showView:self.settingsNotificationBadgeButton visible:showSettings];
    [self showView:self.settingsNotificationPreviewButton visible:showSettings];
    [self showView:self.settingsNotificationsWhenActiveButton visible:showSettings];
    [self showView:self.settingsDrawerHiddenButton visible:showSettings];
    [self showView:self.settingsTypingIndicatorsButton visible:showSettings];
    [self showView:self.settingsLanguageLabel visible:showSettings];
    [self showView:self.settingsLanguagePopUpButton visible:showSettings];
    [self showView:self.settingsActiveSessionsDetailField visible:showSettings];
    [self showView:self.settingsActiveSessionsButton visible:showSettings];
    [self showView:self.settingsDownloadFolderHelpField visible:showSettings];
    [self showView:self.settingsDownloadFolderButton visible:showSettings];
    [self showView:self.settingsCheckUpdatesButton visible:showSettings];
    [self showView:self.settingsAppearanceButton visible:NO];
    [self showView:self.settingsLogsButton visible:showSettings];
    [self showView:self.settingsAboutButton visible:showSettings];

    [self showView:self.aboutPanelView visible:NO];
    [self showView:self.aboutCardView visible:NO];
    [self showView:self.aboutIconView visible:NO];
    [self showView:self.aboutTitleField visible:NO];
    [self showView:self.aboutVersionField visible:NO];
    [self showView:self.aboutCopyrightField visible:NO];
    [self showView:self.aboutLinkField visible:NO];

    [self showView:self.diagnosticsPanelView visible:NO];
    [self showView:self.logsCardView visible:NO];
    [self showView:self.diagnosticsLabel visible:NO];
    [self showView:self.detailsScrollView visible:NO];
    [self showView:self.checkButton visible:NO];
}

- (CGFloat)composerInputHeightForWidth:(CGFloat)width {
    if (width < 80.0) {
        width = 80.0;
    }

    NSString *text = [self.sendTextField stringValue];
    if ([text length] == 0) {
        return TGComposerMinimumInputHeight();
    }

    NSFont *font = [self.sendTextField font];
    if (!font) {
        font = [NSFont systemFontOfSize:13.0];
    }

    NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraphStyle setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                font, NSFontAttributeName,
                                paragraphStyle, NSParagraphStyleAttributeName,
                                nil];
    NSRect measuredRect = [text boundingRectWithSize:NSMakeSize(width, 1000.0)
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:attributes];
    CGFloat measuredHeight = ceil(NSHeight(measuredRect)) + 4.0;

    NSUInteger explicitLines = 1;
    NSUInteger index = 0;
    for (index = 0; index < [text length]; index++) {
        if ([text characterAtIndex:index] == '\n') {
            explicitLines++;
        }
    }
    CGFloat explicitHeight = 4.0 + ((CGFloat)explicitLines * TGComposerLineHeight());
    CGFloat height = MAX(measuredHeight, explicitHeight);
    if (height < TGComposerMinimumInputHeight()) {
        height = TGComposerMinimumInputHeight();
    }
    if (height > TGComposerMaximumInputHeight()) {
        height = TGComposerMaximumInputHeight();
    }
    return height;
}

- (void)layoutContentView {
    NSView *contentView = [[self window] contentView];
    NSRect bounds = [contentView bounds];
    CGFloat width = NSWidth(bounds);
    CGFloat height = NSHeight(bounds);
    CGFloat margin = 10.0;
    BOOL drawerHidden = TGUserDefaultBoolWithDefault(TGDrawerHiddenDefaultsKey, NO);
    CGFloat railGutter = drawerHidden ? 0.0 : 10.0;
    CGFloat panelGutter = 10.0;
    CGFloat railWidth = drawerHidden ? 0.0 : (self.drawerOpen ? 108.0 : 44.0);
    CGFloat railX = margin;
    CGFloat railY = margin;
    CGFloat railHeight = height - (margin * 2.0);
    CGFloat railTop = railY + railHeight;
    CGFloat mainX = drawerHidden ? margin : (railX + railWidth + railGutter);
    CGFloat mainY = margin;
    CGFloat mainWidth = width - mainX - margin;
    CGFloat mainHeight = railHeight;
    CGFloat mainTop = mainY + mainHeight;
    CGFloat sidebarWidth = 292.0;

    if (railHeight < 520.0) {
        railHeight = 520.0;
        railTop = railY + railHeight;
        mainHeight = railHeight;
        mainTop = mainY + mainHeight;
    }
    if (width < 900.0) {
        sidebarWidth = 248.0;
    } else if (width < 1040.0) {
        sidebarWidth = 272.0;
    }

    CGFloat conversationX = mainX + sidebarWidth + panelGutter;
    CGFloat conversationWidth = width - conversationX - margin;
    if (conversationWidth < 320.0) {
        CGFloat reduction = 320.0 - conversationWidth;
        sidebarWidth -= reduction;
        if (sidebarWidth < 220.0) {
            sidebarWidth = 220.0;
        }
        conversationX = mainX + sidebarWidth + panelGutter;
        conversationWidth = width - conversationX - margin;
    }
    if (mainWidth < 420.0) {
        mainWidth = 420.0;
    }

    [self.topPanelView setFrame:NSMakeRect(railX, railY, railWidth, railHeight)];
    [self.sidebarPanelView setFrame:NSMakeRect(mainX, mainY, sidebarWidth, mainHeight)];
    [self.conversationPanelView setFrame:NSMakeRect(conversationX, mainY, conversationWidth, mainHeight)];
    [self.diagnosticsPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.profilePanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.settingsPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];
    [self.aboutPanelView setFrame:NSMakeRect(mainX, mainY, mainWidth, mainHeight)];

    [self.drawerButton setFrame:NSMakeRect(railX + 5.0, railTop - 39.0, 34.0, 34.0)];
    CGFloat accountBadgeWidth = railWidth - 48.0;
    if (accountBadgeWidth < 0.0) {
        accountBadgeWidth = 0.0;
    }
    [self.accountBadgeView setFrame:NSMakeRect(railX + 24.0, railTop - 124.0, accountBadgeWidth, 60.0)];
    [self.titleField setFont:[NSFont boldSystemFontOfSize:13.0]];
    [[self.titleField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.titleField setFrame:NSMakeRect(railX + 9.0, railTop - 48.0, railWidth - 18.0, 18.0)];
    [self.statusField setFont:[NSFont systemFontOfSize:9.0]];
    [[self.statusField cell] setLineBreakMode:NSLineBreakByTruncatingTail];
    [self.statusField setFrame:NSMakeRect(railX + 9.0, railTop - 66.0, railWidth - 18.0, 14.0)];

    CGFloat drawerFolderButtonHeight = 46.0;
    CGFloat drawerFolderButtonGap = 8.0;
    CGFloat drawerFolderButtonY = railTop - 196.0;
    NSUInteger navigationIndex = 0;
    for (navigationIndex = 0; navigationIndex < [self.drawerFolderButtons count]; navigationIndex++) {
        NSButton *folderButton = [self.drawerFolderButtons objectAtIndex:navigationIndex];
        [folderButton setFrame:NSMakeRect(railX + 8.0, drawerFolderButtonY, railWidth - 16.0, drawerFolderButtonHeight)];
        drawerFolderButtonY -= (drawerFolderButtonHeight + drawerFolderButtonGap);
    }

    CGFloat bottomNavigationHeight = 62.0;
    CGFloat bottomNavigationX = mainX + 8.0;
    CGFloat bottomNavigationY = mainY + 8.0;
    CGFloat bottomNavigationWidth = sidebarWidth - 16.0;
    if (bottomNavigationWidth < 204.0) {
        bottomNavigationWidth = sidebarWidth - 8.0;
        bottomNavigationX = mainX + 4.0;
    }
    [self.bottomNavigationView setFrame:NSMakeRect(bottomNavigationX,
                                                   bottomNavigationY,
                                                   bottomNavigationWidth,
                                                   bottomNavigationHeight)];
    CGFloat bottomNavigationInnerX = bottomNavigationX + 8.0;
    CGFloat bottomNavigationButtonGap = 6.0;
    CGFloat bottomNavigationButtonHeight = 48.0;
    CGFloat bottomNavigationButtonY = bottomNavigationY + floor((bottomNavigationHeight - bottomNavigationButtonHeight) / 2.0);
    CGFloat bottomNavigationButtonWidth = floor((bottomNavigationWidth - 16.0 - (bottomNavigationButtonGap * 2.0)) / 3.0);
    if (bottomNavigationButtonWidth < 58.0) {
        bottomNavigationButtonWidth = 58.0;
    }
    for (navigationIndex = 0; navigationIndex < [self.navigationButtons count]; navigationIndex++) {
        NSButton *navigationButton = [self.navigationButtons objectAtIndex:navigationIndex];
        CGFloat buttonX = bottomNavigationInnerX + ((bottomNavigationButtonWidth + bottomNavigationButtonGap) * navigationIndex);
        [navigationButton setFrame:NSMakeRect(buttonX,
                                              bottomNavigationButtonY,
                                              bottomNavigationButtonWidth,
                                              bottomNavigationButtonHeight)];
    }
    BOOL readyForMainShell = [self.currentAuthState isEqualToString:@"ready"];
    CGFloat loginAreaX = readyForMainShell ? mainX : margin;
    CGFloat loginAreaY = margin;
    CGFloat loginAreaWidth = readyForMainShell ? mainWidth : (width - (margin * 2.0));
    CGFloat loginAreaHeight = height - (margin * 2.0);
    CGFloat loginWidth = loginAreaWidth - 96.0;
    if (loginWidth > 580.0) {
        loginWidth = 580.0;
    }
    if (loginWidth < 390.0) {
        loginWidth = loginAreaWidth - 24.0;
    }
    CGFloat loginHeight = 276.0;
    CGFloat loginX = loginAreaX + floor((loginAreaWidth - loginWidth) / 2.0);
    CGFloat centeredLoginY = loginAreaY + floor((loginAreaHeight - loginHeight) / 2.0) - 8.0;
    CGFloat brandIconSide = 68.0;
    CGFloat brandIconY = centeredLoginY + loginHeight + 24.0;
    CGFloat brandTitleY = brandIconY - 30.0;
    if (brandIconY + brandIconSide > loginAreaY + loginAreaHeight - 12.0) {
        brandIconY = loginAreaY + loginAreaHeight - brandIconSide - 12.0;
        brandTitleY = brandIconY - 30.0;
    }
    CGFloat loginY = brandTitleY - loginHeight - 18.0;
    if (loginY < loginAreaY + 18.0) {
        loginY = loginAreaY + 18.0;
    }
    [self.loginIconView setFrame:NSMakeRect(loginAreaX + floor((loginAreaWidth - brandIconSide) / 2.0),
                                            brandIconY,
                                            brandIconSide,
                                            brandIconSide)];
    [self.loginBrandField setFrame:NSMakeRect(loginAreaX + floor((loginAreaWidth - 360.0) / 2.0),
                                              brandTitleY,
                                              360.0,
                                              26.0)];
    [self.loginPanelView setFrame:NSMakeRect(loginX, loginY, loginWidth, loginHeight)];
    [self.loginTitleField setFrame:NSMakeRect(loginX + 36.0, loginY + loginHeight - 58.0, loginWidth - 72.0, 28.0)];
    [self.loginHintField setFrame:NSMakeRect(loginX + 54.0, loginY + loginHeight - 112.0, loginWidth - 108.0, 44.0)];
    [self.authLabel setFrame:NSMakeRect(loginX + 54.0, loginY + 114.0, loginWidth - 108.0, 18.0)];
    [self.authSecondaryLabel setFrame:NSMakeRect(loginX + 54.0, loginY + 94.0, loginWidth - 108.0, 18.0)];
    CGFloat loginButtonWidth = 92.0;
    CGFloat loginInputX = loginX + 54.0;
    CGFloat loginButtonX = loginX + loginWidth - 54.0 - loginButtonWidth;
    CGFloat loginInputWidth = loginButtonX - loginInputX - 12.0;
    if (loginInputWidth < 180.0) {
        loginInputWidth = 180.0;
    }
    CGFloat primaryInputY = loginY + 82.0;
    CGFloat secondaryInputY = loginY + 62.0;
    CGFloat loginErrorHeight = 28.0;
    CGFloat loginErrorGap = 4.0;
    CGFloat loginErrorY = primaryInputY - loginErrorGap - loginErrorHeight;
    [self.authStateField setFrame:NSMakeRect(loginX + 54.0, loginErrorY, loginWidth - 108.0, loginErrorHeight)];
    [self.authTextFieldBackgroundView setFrame:NSMakeRect(loginInputX, primaryInputY, loginInputWidth, 32.0)];
    [self.authTextField setFrame:NSMakeRect(loginInputX + 9.0, primaryInputY + 7.0, loginInputWidth - 18.0, 18.0)];
    [self.authSecondaryTextFieldBackgroundView setFrame:NSMakeRect(loginInputX, secondaryInputY, loginInputWidth, 32.0)];
    [self.authSecureField setFrame:NSMakeRect(loginInputX + 9.0, primaryInputY + 7.0, loginInputWidth - 18.0, 18.0)];
    [self.authButton setFrame:NSMakeRect(loginButtonX, primaryInputY, loginButtonWidth, 32.0)];
    [self.loginLogsButton setFrame:NSMakeRect(width - margin - 74.0, margin + 6.0, 74.0, 28.0)];
    CGFloat loginLanguageX = margin;
    NSUInteger loginLanguageIndex = 0;
    for (loginLanguageIndex = 0; loginLanguageIndex < [self.loginLanguageButtons count]; loginLanguageIndex++) {
        NSButton *languageButton = [self.loginLanguageButtons objectAtIndex:loginLanguageIndex];
        [languageButton setFrame:NSMakeRect(loginLanguageX + (loginLanguageIndex * 48.0), margin + 6.0, 42.0, 28.0)];
    }

    CGFloat headerButtonSize = 30.0;
    CGFloat sectionHeaderVisualOffset = -2.0;
    CGFloat headerButtonY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - headerButtonSize) / 2.0) + sectionHeaderVisualOffset;
    CGFloat headerLabelY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - 20.0) / 2.0) + sectionHeaderVisualOffset;
    CGFloat chatHeaderTitleX = self.showingForumTopicList ? (mainX + 52.0) : (mainX + 16.0);
    [self.topicBackButton setFrame:NSMakeRect(mainX + 12.0, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.chatsLabel setFrame:NSMakeRect(chatHeaderTitleX, headerLabelY, sidebarWidth - (chatHeaderTitleX - mainX) - 58.0, 20.0)];
    [self.loadMoreChatsButton setFrame:NSMakeRect(mainX + sidebarWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.loadChatsButton setFrame:NSMakeRect(mainX + sidebarWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    CGFloat chatListX = mainX + 8.0;
    CGFloat chatListBottom = bottomNavigationY + bottomNavigationHeight + 9.0;
    CGFloat chatListTop = mainTop - TGPanelHeaderHeight - 7.0;
    CGFloat chatListHeight = chatListTop - chatListBottom;
    if (chatListHeight < 128.0) {
        chatListHeight = 128.0;
    }
    CGFloat chatListWidth = sidebarWidth - 16.0;
    if (chatListWidth < 132.0) {
        chatListWidth = 132.0;
    }
    NSRect chatSurfaceFrame = NSMakeRect(chatListX, chatListBottom, chatListWidth, chatListHeight);
    [self.chatScrollSurfaceView setFrame:chatSurfaceFrame];
    [self.chatScrollView setFrame:NSInsetRect(chatSurfaceFrame, 5.0, 5.0)];
    NSTableColumn *chatColumn = [self.chatTableView tableColumnWithIdentifier:@"chat"];
    if (chatColumn) {
        [self.chatScrollView tile];
        CGFloat chatWidth = NSWidth([[self.chatScrollView contentView] bounds]);
        if (chatWidth < 132.0) {
            chatWidth = 132.0;
        }
        [chatColumn setWidth:chatWidth];
    }

    [self.loadOlderMessagesButton setFrame:NSMakeRect(conversationX + conversationWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.loadMessagesButton setFrame:NSMakeRect(conversationX + conversationWidth - 12.0 - headerButtonSize, headerButtonY, headerButtonSize, headerButtonSize)];
    [self.messagesLabel setFrame:NSMakeRect(conversationX + 16.0, headerLabelY, 0.0, 20.0)];
    CGFloat selectedAvatarSize = 24.0;
    CGFloat selectedAvatarX = conversationX + 16.0;
    CGFloat selectedAvatarY = mainTop - TGPanelHeaderHeight + floor((TGPanelHeaderHeight - selectedAvatarSize) / 2.0) + sectionHeaderVisualOffset;
    [self.selectedChatAvatarView setFrame:NSMakeRect(selectedAvatarX, selectedAvatarY, selectedAvatarSize, selectedAvatarSize)];
    CGFloat selectedTitleX = NSMaxX([self.selectedChatAvatarView frame]) + 8.0;
    CGFloat selectedTitleWidth = NSMinX([self.loadMessagesButton frame]) - selectedTitleX - 12.0;
    if (selectedTitleWidth < 120.0) {
        selectedTitleWidth = 120.0;
    }
    BOOL hasTypingText = ([[self.typingIndicatorField stringValue] length] > 0);
    CGFloat selectedTitleY = hasTypingText ? (headerLabelY + 4.0) : headerLabelY;
    [self.selectedChatField setFrame:NSMakeRect(selectedTitleX,
                                                selectedTitleY,
                                                selectedTitleWidth,
                                                17.0)];
    [self.typingIndicatorField setFrame:NSMakeRect(selectedTitleX,
                                                   headerLabelY - 8.0,
                                                   selectedTitleWidth,
                                                   14.0)];
    [self.selectedChatProfileButton setFrame:NSMakeRect(selectedAvatarX,
                                                        selectedAvatarY - 2.0,
                                                        NSMaxX([self.selectedChatField frame]) - selectedAvatarX,
                                                        selectedAvatarSize + 4.0)];

    BOOL voiceRecordingActive = [self.voiceRecorder isRecording];
    CGFloat estimatedSendFieldWidth = conversationWidth - 198.0;
    if (estimatedSendFieldWidth < 160.0) {
        estimatedSendFieldWidth = 160.0;
    }
    CGFloat composerInputHeight = [self composerInputHeightForWidth:(estimatedSendFieldWidth - 16.0)];
    CGFloat composerHeight = composerInputHeight + 16.0;
    if (composerHeight < 42.0) {
        composerHeight = 42.0;
    }
    if (voiceRecordingActive && composerHeight < 60.0) {
        composerHeight = 60.0;
    }
    CGFloat composerY = mainY + 8.0;
    CGFloat messageBottom = composerY + composerHeight + 4.0;
    CGFloat messageTop = mainTop - TGPanelHeaderHeight - 7.0;
    CGFloat messageHeight = messageTop - messageBottom;
    if (messageHeight < 160.0) {
        messageHeight = 160.0;
    }
    CGFloat messageScrollX = conversationX + 8.0;
    CGFloat messageScrollWidth = conversationWidth - 16.0;
    if (messageScrollWidth < 260.0) {
        messageScrollWidth = 260.0;
    }
    NSRect messageSurfaceFrame = NSMakeRect(messageScrollX, messageBottom, messageScrollWidth, messageHeight);
    [self.messageScrollSurfaceView setFrame:messageSurfaceFrame];
    [self.messageScrollView setFrame:NSInsetRect(messageSurfaceFrame, 5.0, 5.0)];
    CGFloat dropOverlayInset = (NSHeight(messageSurfaceFrame) > 130.0) ? 24.0 : 12.0;
    [self.messageDropOverlayView setFrame:NSInsetRect(messageSurfaceFrame, dropOverlayInset, dropOverlayInset)];
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    if (bubbleColumn) {
        [self.messageScrollView tile];
        CGFloat bubbleWidth = NSWidth([[self.messageScrollView contentView] bounds]);
        if (bubbleWidth < 260.0) {
            bubbleWidth = 260.0;
        }
        [bubbleColumn setWidth:bubbleWidth];
    }

    CGFloat sendButtonWidth = 38.0;
    CGFloat attachButtonWidth = 38.0;
    CGFloat smallComposerButtonWidth = 34.0;
    CGFloat composerButtonGap = 6.0;
    CGFloat attachButtonX = conversationX + 12.0;
    CGFloat sendButtonX = conversationX + conversationWidth - sendButtonWidth - 12.0;
    CGFloat voiceButtonX = sendButtonX - composerButtonGap - smallComposerButtonWidth;
    CGFloat stickerButtonX = voiceButtonX - composerButtonGap - smallComposerButtonWidth;
    CGFloat sendFieldX = attachButtonX + attachButtonWidth + 8.0;
    CGFloat sendFieldWidth = stickerButtonX - sendFieldX - 10.0;
    if (sendFieldWidth < 160.0) {
        sendFieldWidth = 160.0;
    }
    CGFloat composerInnerHeight = composerInputHeight + 10.0;
    CGFloat composerControlY = composerY + floor((composerHeight - 32.0) / 2.0);
    CGFloat composerInputBackgroundY = composerY + floor((composerHeight - composerInnerHeight) / 2.0);
    [self.sendLabel setFrame:NSMakeRect(conversationX + 14.0, composerY + 8.0, 0.0, 22.0)];
    [self.attachPhotoButton setFrame:NSMakeRect(attachButtonX, composerControlY, attachButtonWidth, 32.0)];
    [self.sendTextFieldBackgroundView setFrame:NSMakeRect(sendFieldX, composerInputBackgroundY, sendFieldWidth, composerInnerHeight)];
    [self.sendTextField setFrame:NSMakeRect(sendFieldX + 8.0, composerInputBackgroundY + 5.0, sendFieldWidth - 16.0, composerInputHeight)];
    [self.stickerButton setFrame:NSMakeRect(stickerButtonX, composerControlY, smallComposerButtonWidth, 32.0)];
    [self.voiceRecordButton setFrame:NSMakeRect(voiceButtonX, composerControlY, smallComposerButtonWidth, 32.0)];
    [self.sendMessageButton setFrame:NSMakeRect(sendButtonX, composerControlY, sendButtonWidth, 32.0)];
    if (voiceRecordingActive) {
        [self.voiceRecordingIndicatorField setFrame:NSMakeRect(sendFieldX + 2.0, composerY + composerHeight + 2.0, conversationWidth - (sendFieldX - conversationX) - 28.0, 16.0)];
    } else {
        [self.voiceRecordingIndicatorField setFrame:NSMakeRect(sendFieldX + 2.0, composerY + composerHeight + 2.0, 0.0, 0.0)];
    }

    CGFloat panelTitleY = headerLabelY;
    CGFloat contentTop = mainTop - TGPanelHeaderHeight;
    CGFloat groupedWidth = mainWidth - 56.0;
    if (groupedWidth > 760.0) {
        groupedWidth = 760.0;
    }
    if (groupedWidth < 360.0) {
        groupedWidth = mainWidth - 32.0;
    }
    [self.profileTitleField setFrame:NSMakeRect(mainX + 18.0, panelTitleY, 240.0, 22.0)];
    CGFloat profileScrollBottom = bottomNavigationY + bottomNavigationHeight + 10.0;
    CGFloat profileScrollTop = mainTop - TGPanelHeaderHeight - 8.0;
    CGFloat profileScrollHeight = profileScrollTop - profileScrollBottom;
    if (profileScrollHeight < 180.0) {
        profileScrollHeight = 180.0;
    }
    CGFloat profileScrollX = mainX + 8.0;
    CGFloat profileScrollWidth = mainWidth - 16.0;
    if (profileScrollWidth < 360.0) {
        profileScrollWidth = 360.0;
    }
    [self.profileScrollView setFrame:NSMakeRect(profileScrollX,
                                                profileScrollBottom,
                                                profileScrollWidth,
                                                profileScrollHeight)];

    CGFloat profileDocWidth = profileScrollWidth - 18.0;
    if (profileDocWidth < 340.0) {
        profileDocWidth = profileScrollWidth;
    }
    CGFloat profileGroupedWidth = profileDocWidth - 56.0;
    if (profileGroupedWidth > 760.0) {
        profileGroupedWidth = 760.0;
    }
    if (profileGroupedWidth < 300.0) {
        profileGroupedWidth = profileDocWidth - 24.0;
    }
    CGFloat profileGroupedX = floor((profileDocWidth - profileGroupedWidth) / 2.0);
    CGFloat profileLabelHeight = 16.0;
    CGFloat profileLabelGap = 7.0;
    CGFloat profileGroupGap = 12.0;
    CGFloat profileNextY = 18.0;

    CGFloat profileSummaryHeight = 190.0;
    CGFloat profileSummaryY = profileNextY;
    [self.profileSummaryCardView setFrame:NSMakeRect(profileGroupedX, profileSummaryY, profileGroupedWidth, profileSummaryHeight)];
    CGFloat profileAvatarSize = 96.0;
    CGFloat profileAvatarX = profileGroupedX + floor((profileGroupedWidth - profileAvatarSize) / 2.0);
    CGFloat profileAvatarY = profileSummaryY + 18.0;
    [self.profileAvatarView setFrame:NSMakeRect(profileAvatarX,
                                                profileAvatarY,
                                                profileAvatarSize,
                                                profileAvatarSize)];
    CGFloat profileTextX = profileGroupedX + 22.0;
    CGFloat profileTextWidth = profileGroupedWidth - 44.0;
    [self.profileNameField setFrame:NSMakeRect(profileTextX, profileSummaryY + 124.0, profileTextWidth, 26.0)];
    [self.profileUsernameField setFrame:NSMakeRect(profileTextX, profileSummaryY + 154.0, profileTextWidth, 20.0)];

    BOOL profileHasBio = ([[self.profileStateField stringValue] length] > 0);
    BOOL profileHasUsername = ([[self.profileUsernameRowValueField stringValue] length] > 0);
    BOOL profileHasPhone = ([[self.profilePhoneRowValueField stringValue] length] > 0);
    BOOL profileHasID = ([[self.profileIDRowValueField stringValue] length] > 0);
    NSUInteger profileDetailRows = (profileHasUsername ? 1 : 0) + (profileHasPhone ? 1 : 0) + (profileHasID ? 1 : 0);
    profileNextY = profileSummaryY + profileSummaryHeight + profileGroupGap;

    if (profileHasBio) {
        [self.profileAboutSectionField setFrame:NSMakeRect(profileGroupedX + 20.0, profileNextY, profileGroupedWidth - 40.0, profileLabelHeight)];
        NSDictionary *bioAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSFont systemFontOfSize:13.0], NSFontAttributeName,
                                       nil];
        NSString *bioText = [self.profileStateField stringValue];
        NSRect bioRect = [bioText boundingRectWithSize:NSMakeSize(profileGroupedWidth - 44.0, 1000.0)
                                               options:NSStringDrawingUsesLineFragmentOrigin
                                            attributes:bioAttributes];
        CGFloat bioTextHeight = ceil(NSHeight(bioRect));
        CGFloat profileInfoHeight = bioTextHeight + 28.0;
        if (profileInfoHeight < 54.0) {
            profileInfoHeight = 54.0;
        }
        if (profileInfoHeight > 112.0) {
            profileInfoHeight = 112.0;
        }
        CGFloat profileInfoY = profileNextY + profileLabelHeight + profileLabelGap;
        [self.profileInfoCardView setFrame:NSMakeRect(profileGroupedX, profileInfoY, profileGroupedWidth, profileInfoHeight)];
        [self.profileStateField setFrame:NSMakeRect(profileGroupedX + 22.0, profileInfoY + 13.0, profileGroupedWidth - 44.0, profileInfoHeight - 26.0)];
        profileNextY = profileInfoY + profileInfoHeight + profileGroupGap;
    } else {
        [self.profileAboutSectionField setFrame:NSMakeRect(profileGroupedX + 20.0, profileNextY, profileGroupedWidth - 40.0, 0.0)];
        [self.profileInfoCardView setFrame:NSMakeRect(profileGroupedX, profileNextY, profileGroupedWidth, 0.0)];
        [self.profileStateField setFrame:NSMakeRect(profileGroupedX + 22.0, profileNextY, profileGroupedWidth - 44.0, 0.0)];
    }

    if (profileDetailRows > 0) {
        CGFloat rowHeight = 44.0;
        CGFloat detailsHeight = ((CGFloat)profileDetailRows * rowHeight) + 10.0;
        CGFloat accountSectionY = profileNextY;
        CGFloat detailsY = accountSectionY + profileLabelHeight + profileLabelGap;
        [self.profileAccountSectionField setFrame:NSMakeRect(profileGroupedX + 20.0, accountSectionY, profileGroupedWidth - 40.0, profileLabelHeight)];
        [self.profileDetailsCardView setFrame:NSMakeRect(profileGroupedX, detailsY, profileGroupedWidth, detailsHeight)];

        CGFloat rowTitleX = profileGroupedX + 22.0;
        CGFloat rowValueX = profileGroupedX + 208.0;
        CGFloat rowValueWidth = profileGroupedWidth - 230.0;
        if (rowValueWidth < 160.0) {
            rowValueX = profileGroupedX + 148.0;
            rowValueWidth = profileGroupedWidth - 170.0;
        }
        CGFloat rowY = detailsY + 11.0;
        NSUInteger laidOutRows = 0;
        CGFloat separatorOneY = 0.0;
        CGFloat separatorTwoY = 0.0;

        if (profileHasUsername) {
            [self.profileUsernameRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profileUsernameRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
            separatorOneY = rowY + 32.0;
            rowY += rowHeight;
        } else {
            [self.profileUsernameRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profileUsernameRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileHasPhone) {
            [self.profilePhoneRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profilePhoneRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
            if (laidOutRows == 1) {
                separatorOneY = rowY + 32.0;
            } else {
                separatorTwoY = rowY + 32.0;
            }
            rowY += rowHeight;
        } else {
            [self.profilePhoneRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profilePhoneRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileHasID) {
            [self.profileIDRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 150.0, 20.0)];
            [self.profileIDRowValueField setFrame:NSMakeRect(rowValueX, rowY, rowValueWidth, 20.0)];
            laidOutRows++;
        } else {
            [self.profileIDRowTitleField setFrame:NSMakeRect(rowTitleX, rowY, 0.0, 0.0)];
            [self.profileIDRowValueField setFrame:NSMakeRect(rowValueX, rowY, 0.0, 0.0)];
        }
        if (profileDetailRows > 1) {
            [self.profileDetailsSeparatorOne setFrame:NSMakeRect(profileGroupedX + 22.0, separatorOneY, profileGroupedWidth - 44.0, 1.0)];
        }
        if (profileDetailRows > 2) {
            if (separatorTwoY <= 0.0) {
                separatorTwoY = separatorOneY + rowHeight;
            }
            [self.profileDetailsSeparatorTwo setFrame:NSMakeRect(profileGroupedX + 22.0, separatorTwoY, profileGroupedWidth - 44.0, 1.0)];
        }
        profileNextY = detailsY + detailsHeight + profileGroupGap;
    } else {
        [self.profileAccountSectionField setFrame:NSMakeRect(profileGroupedX + 20.0, profileNextY, profileGroupedWidth - 40.0, 0.0)];
        [self.profileDetailsCardView setFrame:NSMakeRect(profileGroupedX, profileNextY, profileGroupedWidth, 0.0)];
        [self.profileUsernameRowTitleField setFrame:NSMakeRect(profileGroupedX + 22.0, profileNextY, 0.0, 0.0)];
        [self.profileUsernameRowValueField setFrame:NSMakeRect(profileGroupedX + 208.0, profileNextY, 0.0, 0.0)];
        [self.profilePhoneRowTitleField setFrame:NSMakeRect(profileGroupedX + 22.0, profileNextY, 0.0, 0.0)];
        [self.profilePhoneRowValueField setFrame:NSMakeRect(profileGroupedX + 208.0, profileNextY, 0.0, 0.0)];
        [self.profileIDRowTitleField setFrame:NSMakeRect(profileGroupedX + 22.0, profileNextY, 0.0, 0.0)];
        [self.profileIDRowValueField setFrame:NSMakeRect(profileGroupedX + 208.0, profileNextY, 0.0, 0.0)];
    }

    CGFloat profileActionsHeight = 52.0;
    CGFloat profileActionsY = profileNextY;
    [self.profileActionsCardView setFrame:NSMakeRect(profileGroupedX, profileActionsY, profileGroupedWidth, profileActionsHeight)];
    [self.profileRefreshButton setFrame:NSMakeRect(profileGroupedX + 22.0, profileActionsY, 0.0, 0.0)];
    [self.logoutButton setFrame:NSMakeRect(profileGroupedX + 22.0, profileActionsY + 11.0, profileGroupedWidth - 44.0, 30.0)];
    [self.profileIDField setFrame:NSMakeRect(profileGroupedX + 22.0, profileActionsY, 0.0, 0.0)];
    profileNextY = profileActionsY + profileActionsHeight + 18.0;

    CGFloat profileDocHeight = profileNextY;
    if (profileDocHeight < profileScrollHeight) {
        profileDocHeight = profileScrollHeight;
    }
    [self.profileContentView setFrame:NSMakeRect(0.0, 0.0, profileDocWidth, profileDocHeight)];

    [self.settingsTitleField setFrame:NSMakeRect(mainX + 18.0, panelTitleY, 240.0, 22.0)];

    CGFloat settingsScrollBottom = bottomNavigationY + bottomNavigationHeight + 10.0;
    CGFloat settingsScrollTop = mainTop - TGPanelHeaderHeight - 8.0;
    CGFloat settingsScrollHeight = settingsScrollTop - settingsScrollBottom;
    if (settingsScrollHeight < 180.0) {
        settingsScrollHeight = 180.0;
    }
    CGFloat settingsScrollX = mainX + 8.0;
    CGFloat settingsScrollWidth = mainWidth - 16.0;
    if (settingsScrollWidth < 360.0) {
        settingsScrollWidth = 360.0;
    }
    [self.settingsScrollView setFrame:NSMakeRect(settingsScrollX,
                                                 settingsScrollBottom,
                                                 settingsScrollWidth,
                                                 settingsScrollHeight)];

    CGFloat settingsDocWidth = settingsScrollWidth - 18.0;
    if (settingsDocWidth < 340.0) {
        settingsDocWidth = settingsScrollWidth;
    }
    CGFloat settingsDocHeight = 850.0;
    if (settingsDocHeight < settingsScrollHeight) {
        settingsDocHeight = settingsScrollHeight;
    }
    [self.settingsContentView setFrame:NSMakeRect(0.0, 0.0, settingsDocWidth, settingsDocHeight)];

    CGFloat settingsLabelHeight = 16.0;
    CGFloat settingsLabelGap = 7.0;
    CGFloat settingsGroupGap = 12.0;
    CGFloat settingsGroupedWidth = settingsDocWidth - 56.0;
    if (settingsGroupedWidth > 760.0) {
        settingsGroupedWidth = 760.0;
    }
    if (settingsGroupedWidth < 300.0) {
        settingsGroupedWidth = settingsDocWidth - 24.0;
    }
    CGFloat settingsGroupedX = floor((settingsDocWidth - settingsGroupedWidth) / 2.0);
    CGFloat rowLeft = settingsGroupedX + 22.0;
    CGFloat rowWidth = settingsGroupedWidth - 44.0;
    CGFloat settingsNextY = 18.0;

    CGFloat notificationCardHeight = 140.0;
    [self.settingsStateField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat notificationCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsAccountCardView setFrame:NSMakeRect(settingsGroupedX, notificationCardY, settingsGroupedWidth, notificationCardHeight)];
    [self.settingsNotificationsEnabledButton setFrame:NSMakeRect(rowLeft, notificationCardY + 12.0, rowWidth, 22.0)];
    [self.settingsNotificationSoundButton setFrame:NSMakeRect(rowLeft, notificationCardY + 36.0, rowWidth, 22.0)];
    [self.settingsNotificationBadgeButton setFrame:NSMakeRect(rowLeft, notificationCardY + 60.0, rowWidth, 22.0)];
    [self.settingsNotificationPreviewButton setFrame:NSMakeRect(rowLeft, notificationCardY + 84.0, rowWidth, 22.0)];
    [self.settingsNotificationsWhenActiveButton setFrame:NSMakeRect(rowLeft, notificationCardY + 108.0, rowWidth, 22.0)];
    settingsNextY = notificationCardY + notificationCardHeight + settingsGroupGap;

    [self.settingsDrawerSectionField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat drawerCardHeight = 78.0;
    CGFloat drawerCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsDrawerCardView setFrame:NSMakeRect(settingsGroupedX, drawerCardY, settingsGroupedWidth, drawerCardHeight)];
    [self.settingsDrawerHiddenButton setFrame:NSMakeRect(rowLeft, drawerCardY + 12.0, rowWidth, 22.0)];
    [self.settingsTypingIndicatorsButton setFrame:NSMakeRect(rowLeft, drawerCardY + 42.0, rowWidth, 22.0)];
    settingsNextY = drawerCardY + drawerCardHeight + settingsGroupGap;

    [self.settingsLibraryField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat interfaceCardHeight = 88.0;
    CGFloat interfaceCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsThemeCardView setFrame:NSMakeRect(settingsGroupedX, interfaceCardY, settingsGroupedWidth, interfaceCardHeight)];
    [self.settingsAppearanceButton setFrame:NSMakeRect(rowLeft, interfaceCardY, 0.0, 0.0)];

    CGFloat popupWidth = 210.0;
    if (popupWidth > settingsGroupedWidth - 150.0) {
        popupWidth = settingsGroupedWidth - 150.0;
    }
    CGFloat labelWidth = 88.0;
    CGFloat popupX = rowLeft + labelWidth + 8.0;
    [self.settingsThemeLabel setFrame:NSMakeRect(rowLeft, interfaceCardY + 16.0, labelWidth, 22.0)];
    [self.themePopUpButton setFrame:NSMakeRect(popupX, interfaceCardY + 12.0, popupWidth, 28.0)];
    [self.settingsLanguageLabel setFrame:NSMakeRect(rowLeft, interfaceCardY + 50.0, labelWidth, 22.0)];
    [self.settingsLanguagePopUpButton setFrame:NSMakeRect(popupX, interfaceCardY + 46.0, popupWidth, 28.0)];
    settingsNextY = interfaceCardY + interfaceCardHeight + settingsGroupGap;

    [self.settingsStorageField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat sessionsCardHeight = 72.0;
    CGFloat sessionsCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsSessionCardView setFrame:NSMakeRect(settingsGroupedX, sessionsCardY, settingsGroupedWidth, sessionsCardHeight)];
    [self.settingsActiveSessionsDetailField setFrame:NSMakeRect(rowLeft, sessionsCardY + 10.0, rowWidth, 18.0)];
    [self.settingsActiveSessionsButton setFrame:NSMakeRect(rowLeft, sessionsCardY + 34.0, rowWidth, 28.0)];
    settingsNextY = sessionsCardY + sessionsCardHeight + settingsGroupGap;

    [self.settingsFilesSectionField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat filesCardHeight = 76.0;
    CGFloat filesCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsFilesCardView setFrame:NSMakeRect(settingsGroupedX, filesCardY, settingsGroupedWidth, filesCardHeight)];
    [self.settingsDownloadFolderHelpField setFrame:NSMakeRect(rowLeft, filesCardY + 12.0, rowWidth, 18.0)];
    [self.settingsDownloadFolderButton setFrame:NSMakeRect(rowLeft, filesCardY + 38.0, rowWidth, 28.0)];
    settingsNextY = filesCardY + filesCardHeight + settingsGroupGap;

    [self.settingsHelpSectionField setFrame:NSMakeRect(settingsGroupedX + 20.0, settingsNextY, settingsGroupedWidth - 40.0, settingsLabelHeight)];
    CGFloat helpCardHeight = 112.0;
    CGFloat helpCardY = settingsNextY + settingsLabelHeight + settingsLabelGap;
    [self.settingsHelpCardView setFrame:NSMakeRect(settingsGroupedX, helpCardY, settingsGroupedWidth, helpCardHeight)];
    [self.settingsLogsButton setFrame:NSMakeRect(rowLeft, helpCardY + 10.0, rowWidth, 28.0)];
    [self.settingsAboutButton setFrame:NSMakeRect(rowLeft, helpCardY + 42.0, rowWidth, 28.0)];
    [self.settingsCheckUpdatesButton setFrame:NSMakeRect(rowLeft, helpCardY + 74.0, rowWidth, 28.0)];

    CGFloat aboutWidth = groupedWidth;
    if (aboutWidth > 560.0) {
        aboutWidth = 560.0;
    }
    CGFloat aboutX = mainX + floor((mainWidth - aboutWidth) / 2.0);
    CGFloat aboutHeight = 326.0;
    CGFloat aboutY = contentTop - aboutHeight - 24.0;
    [self.aboutCardView setFrame:NSMakeRect(aboutX, aboutY, aboutWidth, aboutHeight)];
    CGFloat aboutIconSize = 118.0;
    CGFloat aboutCenterX = aboutX + (aboutWidth / 2.0);
    [self.aboutIconView setFrame:NSMakeRect(aboutCenterX - (aboutIconSize / 2.0), aboutY + aboutHeight - aboutIconSize - 26.0, aboutIconSize, aboutIconSize)];
    [self.aboutTitleField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 134.0, aboutWidth - 72.0, 30.0)];
    [self.aboutVersionField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 104.0, aboutWidth - 72.0, 22.0)];
    [self.aboutCopyrightField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 72.0, aboutWidth - 72.0, 22.0)];
    [self.aboutLinkField setFrame:NSMakeRect(aboutX + 36.0, aboutY + 40.0, aboutWidth - 72.0, 22.0)];

    [self.diagnosticsLabel setFrame:NSMakeRect(mainX + 18.0, panelTitleY, 160.0, 18.0)];
    [self.checkButton setFrame:NSMakeRect(mainX + mainWidth - 166.0, headerButtonY, 150.0, headerButtonSize)];
    CGFloat logsCardX = mainX + 18.0;
    CGFloat logsCardY = mainY + 18.0;
    CGFloat logsCardWidth = mainWidth - 36.0;
    CGFloat logsCardHeight = mainHeight - TGPanelHeaderHeight - 36.0;
    [self.logsCardView setFrame:NSMakeRect(logsCardX, logsCardY, logsCardWidth, logsCardHeight)];
    [self.detailsScrollView setFrame:NSMakeRect(logsCardX + 12.0, logsCardY + 12.0, logsCardWidth - 24.0, logsCardHeight - 24.0)];
}

- (void)windowDidResize:(NSNotification *)notification {
    if ([notification object] == self.mediaPlaybackWindow) {
        [self layoutMediaPlaybackLayer];
        return;
    }
    if ([notification object] != [self window]) {
        return;
    }
    [self layoutContentView];
    [self.messageTableView reloadData];
    [self updateVisibleSection];
    [self scheduleInlineMediaPlaybackRefresh];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    if ([notification object] == [self window] && ![self.currentAuthState isEqualToString:@"ready"]) {
        [self scheduleLoginInputFocus];
    }
}

- (void)tearDownClosedMediaPreviewWindow:(NSWindow *)closingWindow {
    if (closingWindow != self.mediaPreviewWindow) {
        return;
    }
    self.mediaPreviewPath = nil;
    self.mediaPreviewZoomScale = 1.0;
    [self.mediaPreviewImageView setImage:nil];
    [closingWindow setDelegate:nil];
    self.mediaPreviewImageView = nil;
    self.mediaPreviewScrollView = nil;
    self.mediaPreviewWindow = nil;
}

- (void)windowWillClose:(NSNotification *)notification {
    if ([notification object] == self.mediaPreviewWindow) {
        NSWindow *closingWindow = [(NSWindow *)[notification object] retain];
        self.mediaPreviewRequestGeneration = self.mediaPreviewRequestGeneration + 1;
        self.mediaPreviewPath = nil;
        self.mediaPreviewZoomScale = 1.0;
        [self.mediaPreviewImageView setImage:nil];
        [closingWindow setDelegate:nil];
        [self performSelector:@selector(tearDownClosedMediaPreviewWindow:)
                   withObject:closingWindow
                   afterDelay:0.0];
        [closingWindow release];
    }
    if ([notification object] == self.mediaPlaybackWindow) {
        [self resetMediaPlaybackState];
        [self.mediaPlaybackWindow setDelegate:nil];
        self.mediaPlaybackContainerView = nil;
        self.mediaPlaybackTitleField = nil;
        self.mediaPlaybackPlayPauseButton = nil;
        self.mediaPlaybackProgressSlider = nil;
        self.mediaPlaybackTimeField = nil;
        self.mediaPlaybackCloseButton = nil;
        self.mediaPlaybackWindow = nil;
    }
    if ([notification object] == self.voicePreviewWindow) {
        [self invalidateVoicePreviewTimer];
        [self.voicePreviewPlayer stop];
        self.voicePreviewPlayer = nil;
        if ([self.voiceRecordingPath length] > 0) {
            [[NSFileManager defaultManager] removeItemAtPath:self.voiceRecordingPath error:NULL];
        }
        self.voiceRecordingPath = nil;
        self.voiceRecordingStartDate = nil;
        [self.voicePreviewWindow setDelegate:nil];
        self.voicePreviewWindow = nil;
    }
    if ([notification object] == self.stickerPickerWindow) {
        [self.stickerPickerPlaybackCoordinator removeAllPlayback];
        [self scheduleInlineMediaPlaybackRefresh];
    }
}

- (void)startLiveUpdateTimerIfNeeded {
    if (self.liveUpdateTimer) {
        return;
    }

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(pollLiveUpdates:)
                                                    userInfo:nil
                                                     repeats:YES];
    self.liveUpdateTimer = timer;
}

- (void)stopLiveUpdateTimer {
    if (!self.liveUpdateTimer) {
        return;
    }

    [self.liveUpdateTimer invalidate];
    self.liveUpdateTimer = nil;
}

- (void)prepareForApplicationTermination {
    [self stopLiveUpdateTimer];
    [self setControlsBusy:YES];
    [self.client shutdownWithTimeout:3.0];
}

- (BOOL)isAuthInputState:(NSString *)state {
    return [state isEqualToString:@"waitPhoneNumber"] ||
           [state isEqualToString:@"waitCode"] ||
           [state isEqualToString:@"waitPassword"];
}

- (BOOL)isTerminalAuthorizationState:(NSString *)state {
    return [state isEqualToString:@"loggingOut"] ||
           [state isEqualToString:@"closing"] ||
           [state isEqualToString:@"closed"];
}

- (void)recoverTDLibClientAfterAuthorizationState:(NSString *)state
                                    expectedClient:(TGTDLibClient *)expectedClient {
    if (![self isTerminalAuthorizationState:state] || !expectedClient || self.client != expectedClient || self.authClientRecoveryInFlight) {
        return;
    }

    if (self.authClientRecoveryAttemptCount >= 3) {
        [self.statusField setStringValue:@"Sign-in restart required"];
        [self appendDetail:@"TDLib sign-in recovery paused after three attempts. Use Try Again to retry without deleting local configuration."];
        [self updateAuthControlsForState:state];
        [self setControlsBusy:NO];
        return;
    }

    self.authClientRecoveryInFlight = YES;
    self.authClientRecoveryAttemptCount++;
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Restarting Telegram connection..."];
    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state %@ requires a fresh client (attempt %lu of 3).",
                        state,
                        (unsigned long)self.authClientRecoveryAttemptCount]];

    TGTDLibClient *clientToRecover = [expectedClient retain];
    NSString *initialState = [state copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSString *observedState = initialState;
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:6.0];

        while ([self isTerminalAuthorizationState:observedState] &&
               ![observedState isEqualToString:@"closed"] &&
               [[NSDate date] compare:deadline] == NSOrderedAscending) {
            NSError *stateError = nil;
            NSString *nextState = [clientToRecover authorizationStateSummaryWithTimeout:1.0 error:&stateError];
            if ([nextState length] > 0) {
                observedState = nextState;
            } else if ([[stateError localizedDescription] rangeOfString:@"shutting down" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                break;
            }
            if (![observedState isEqualToString:@"closed"]) {
                [NSThread sleepForTimeInterval:0.15];
            }
        }

        [clientToRecover shutdownWithTimeout:1.0];
        [NSThread sleepForTimeInterval:0.2 * self.authClientRecoveryAttemptCount];
        TGTDLibClient *replacementClient = [[[TGTDLibClient alloc] init] autorelease];
        NSString *lastObservedState = [observedState copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client == clientToRecover) {
                self.client = replacementClient;
                self.initialConnectStarted = NO;
                self.authClientRecoveryInFlight = NO;
                [self appendDetail:[NSString stringWithFormat:@"TDLib client recreated after auth state %@.",
                                    [lastObservedState length] > 0 ? lastObservedState : initialState]];
                [self setControlsBusy:NO];
                [self performSelector:@selector(connectOnLaunch:) withObject:nil afterDelay:0.15];
            } else {
                self.authClientRecoveryInFlight = NO;
            }
        });

        [lastObservedState release];
        [initialState release];
        [clientToRecover release];
        [pool drain];
    });
}

- (void)updateSendControls {
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    BOOL canTargetChat = [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget;
    NSString *text = [self.sendTextField stringValue];
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.attachPhotoButton setEnabled:canTargetChat];
    [self.stickerButton setEnabled:canTargetChat];
    [self.voiceRecordButton setEnabled:canTargetChat];
    [self.sendTextField setEnabled:canTargetChat];
    [self.sendMessageButton setEnabled:(canTargetChat && [trimmedText length] > 0 && [text length] <= 4096)];
}

- (NSString *)composerDraftKeyForChatID:(NSNumber *)chatID
                        messageThreadID:(NSNumber *)messageThreadID
                         messageTopicKind:(NSString *)messageTopicKind {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return nil;
    }

    long long threadValue = ([messageThreadID respondsToSelector:@selector(longLongValue)] ? [messageThreadID longLongValue] : 0);
    NSString *topicKind = ([messageTopicKind length] > 0) ? messageTopicKind : @"main";
    return [NSString stringWithFormat:@"%lld|%lld|%@", [chatID longLongValue], threadValue, topicKind];
}

- (NSString *)currentComposerDraftKey {
    return [self composerDraftKeyForChatID:self.selectedChatID
                           messageThreadID:self.selectedMessageThreadID
                            messageTopicKind:self.selectedMessageTopicKind];
}

- (void)setComposerTextWithoutSavingDraft:(NSString *)text {
    BOOL previousSuppress = self.suppressComposerDraftSave;
    self.suppressComposerDraftSave = YES;
    [self.sendTextField setStringValue:(text ? text : @"")];
    self.suppressComposerDraftSave = previousSuppress;
    [self updateSendControls];
    [self layoutContentView];
}

- (void)saveComposerDraftForChatID:(NSNumber *)chatID
                   messageThreadID:(NSNumber *)messageThreadID
                    messageTopicKind:(NSString *)messageTopicKind {
    NSString *key = [self composerDraftKeyForChatID:chatID
                                    messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind];
    if ([key length] == 0) {
        return;
    }

    NSString *text = [self.sendTextField stringValue];
    if ([text length] > 0) {
        [self.composerDraftsByTargetKey setObject:text forKey:key];
    } else {
        [self.composerDraftsByTargetKey removeObjectForKey:key];
    }
}

- (void)saveCurrentComposerDraft {
    if (self.suppressComposerDraftSave) {
        return;
    }
    [self saveComposerDraftForChatID:self.selectedChatID
                     messageThreadID:self.selectedMessageThreadID
                      messageTopicKind:self.selectedMessageTopicKind];
}

- (void)restoreComposerDraftForChatID:(NSNumber *)chatID
                      messageThreadID:(NSNumber *)messageThreadID
                       messageTopicKind:(NSString *)messageTopicKind {
    NSString *key = [self composerDraftKeyForChatID:chatID
                                    messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind];
    NSString *draft = ([key length] > 0) ? [self.composerDraftsByTargetKey objectForKey:key] : nil;
    [self setComposerTextWithoutSavingDraft:draft];
}

- (void)removeComposerDraftForChatID:(NSNumber *)chatID
                     messageThreadID:(NSNumber *)messageThreadID
                      messageTopicKind:(NSString *)messageTopicKind {
    NSString *key = [self composerDraftKeyForChatID:chatID
                                    messageThreadID:messageThreadID
                                     messageTopicKind:messageTopicKind];
    if ([key length] > 0) {
        [self.composerDraftsByTargetKey removeObjectForKey:key];
    }
}

- (void)refocusComposerIfPossible {
    if (![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        (self.showingForumTopicList && self.selectedMessageThreadID == nil) ||
        [self.sendTextField isHidden]) {
        return;
    }
    [self updateSendControls];
    [self.sendTextField setEnabled:YES];
    [[self window] makeFirstResponder:self.sendTextField];
}

- (void)consumePendingComposerRefocus:(id)sender {
    (void)sender;
    if (!self.composerRefocusPending) {
        return;
    }
    if (self.controlsBusy || self.backgroundMessageRefreshInFlight) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(consumePendingComposerRefocus:)
                                                   object:nil];
        [self performSelector:@selector(consumePendingComposerRefocus:)
                    withObject:nil
                    afterDelay:0.12];
        return;
    }
    self.composerRefocusPending = NO;
    [self refocusComposerIfPossible];
}

- (void)requestComposerRefocus {
    self.composerRefocusPending = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(consumePendingComposerRefocus:)
                                               object:nil];
    [self performSelector:@selector(consumePendingComposerRefocus:)
                withObject:nil
                afterDelay:0.05];
}

- (BOOL)canLoadMoreChats {
    return (!self.controlsBusy &&
            [self.currentAuthState isEqualToString:@"ready"] &&
            !self.showingForumTopicList &&
            [self.chatItems count] > 0 &&
            !self.chatsExhausted &&
            [self.chatItems count] < TGStatusChatPreviewMaximumLimit);
}

- (void)updateOutgoingReadStateForVisibleMessages {
    long long lastReadOutboxMessageID = 0;
    if ([self.selectedChatLastReadOutboxMessageID respondsToSelector:@selector(longLongValue)]) {
        lastReadOutboxMessageID = [self.selectedChatLastReadOutboxMessageID longLongValue];
    }

    NSUInteger index = 0;
    BOOL changed = NO;
    for (index = 0; index < [self.messageItems count]; index++) {
        id candidate = [self.messageItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *item = (TGMessageItem *)candidate;
        BOOL read = NO;
        if ([item outgoing] && ![item sending] && [[item messageID] respondsToSelector:@selector(longLongValue)] && lastReadOutboxMessageID > 0) {
            read = ([[item messageID] longLongValue] <= lastReadOutboxMessageID);
        }
        if ([item outgoingRead] != read) {
            [item setOutgoingRead:read];
            changed = YES;
        }
    }
    if (changed) {
        [self.messageTableView reloadData];
    }
}

- (void)setLoginErrorMessage:(NSString *)message {
    self.loginErrorLocalizationKey = nil;
    BOOL hasMessage = ([message length] > 0);
    self.loginErrorVisible = hasMessage;
    [self.authStateField setStringValue:(hasMessage ? message : @"")];
    if (hasMessage) {
        [self.authStateField setTextColor:[NSColor colorWithCalibratedRed:0.760 green:0.160 blue:0.130 alpha:1.0]];
    } else {
        [self applyMutedLabelStyle:self.authStateField];
    }
    if ([self.authTextFieldBackgroundView isKindOfClass:[TGAuthInputBackgroundView class]]) {
        [(TGAuthInputBackgroundView *)self.authTextFieldBackgroundView setErrorState:hasMessage];
    }
    if ([self.authSecondaryTextFieldBackgroundView isKindOfClass:[TGAuthInputBackgroundView class]]) {
        [(TGAuthInputBackgroundView *)self.authSecondaryTextFieldBackgroundView setErrorState:hasMessage];
    }
}

- (void)setLoginErrorWithLocalizationKey:(NSString *)key {
    [self setLoginErrorMessage:([key length] > 0 ? TGLoc(key) : nil)];
    self.loginErrorLocalizationKey = key;
}

- (NSString *)loginErrorLocalizationKeyForAuthState:(NSString *)state {
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        return @"login.error.phone";
    }
    if ([state isEqualToString:@"waitCode"]) {
        return @"login.error.code";
    }
    if ([state isEqualToString:@"waitPassword"]) {
        return @"login.error.password";
    }
    return @"login.error.general";
}

- (void)focusLoginInputIfNeeded {
    if (self.controlsBusy || [self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }
    NSTextField *inputField = [self.currentAuthState isEqualToString:@"waitPassword"] ? (NSTextField *)self.authSecureField : self.authTextField;
    if (!inputField || [inputField isHidden] || ![inputField isEnabled]) {
        return;
    }
    [[self window] makeFirstResponder:inputField];
}

- (void)scheduleLoginInputFocus {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(focusLoginInputIfNeeded) object:nil];
    [self performSelector:@selector(focusLoginInputIfNeeded) withObject:nil afterDelay:0.05];
}

- (void)updateAuthControlsForState:(NSString *)state {
    NSString *previousState = [self.currentAuthState copy];
    self.currentAuthState = state;
    BOOL authStateChanged = (!previousState || ![previousState isEqualToString:state]);
    BOOL authInputsEnabled = !(self.controlsBusy || self.authSubmissionInFlight);
    if (authStateChanged) {
        [self setLoginErrorMessage:nil];
        [self.authTextField setStringValue:@""];
        [self.authSecureField setStringValue:@""];
    }
    [self.loadChatsButton setEnabled:NO];
    [self.loadMoreChatsButton setEnabled:NO];
    [self.loadMessagesButton setEnabled:NO];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.attachPhotoButton setEnabled:NO];
    [self.stickerButton setEnabled:NO];
    [self.voiceRecordButton setEnabled:NO];
    [self.sendMessageButton setEnabled:NO];
    if (![state isEqualToString:@"ready"] && ([self.chatItems count] > 0 || [self.messageItems count] > 0 || self.selectedChatID != nil)) {
        [self.chatItems removeAllObjects];
        [self.messageItems removeAllObjects];
        [self.chatTableView deselectAll:nil];
        [self.chatTableView reloadData];
        [self.messageTableView reloadData];
        [self updateApplicationBadge];
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        self.selectedChatTypeSummary = nil;
        self.selectedChatAvatarLocalPath = nil;
        self.selectedChatLastReadOutboxMessageID = nil;
        self.selectedMessageThreadID = nil;
        self.selectedMessageTopicKind = nil;
        [self clearForumTopicListState];
        self.chatsExhausted = NO;
        [self.client invalidateMainChatListExhaustion];
        self.autoChatListLoadArmed = YES;
        self.autoChatListRefreshArmed = YES;
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self refreshSelectedChatHeaderDisplay];
        [self setComposerTextWithoutSavingDraft:nil];
        self.activeSection = TGSectionChats;
    }

    if (![state isEqualToString:@"ready"]) {
        self.accountUnreadCount = 0;
        self.hasAccountUnreadCount = NO;
        [self.localMuteUnreadCountsByChatID removeAllObjects];
        [self updateApplicationBadge];
        self.activeSection = TGSectionChats;
        self.drawerOpen = NO;
        [self clearForumTopicListState];
        self.chatsExhausted = NO;
        self.selectedChatFilterID = nil;
        self.chatFilterInfos = [NSArray array];
        self.chatFilterRefreshRetryCount = 0;
        [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(reloadChatFiltersIfReady)
                                                   object:nil];
        self.profileSummaryLoaded = NO;
        [self clearProfileDisplayCache];
        [self.client invalidateMainChatListExhaustion];
        self.pendingLiveChatRefresh = NO;
        self.pendingLiveMessageRefresh = NO;
    } else if (![previousState isEqualToString:@"ready"]) {
        self.activeSection = TGSectionChats;
        self.chatFilterRefreshRetryCount = 0;
        if ([self.chatItems count] == 0) {
            self.pendingLiveChatRefresh = YES;
            [self handlePendingLiveRefreshesIfPossible];
        }
    }

    if ([state isEqualToString:@"waitApiCredentials"]) {
        [self.statusField setStringValue:TGLoc(@"login.config.title")];
        [self refreshLoginLocalizedText];
        [self.authStateField setStringValue:TGLoc(@"login.config.missing")];
        [self.authStateField setHidden:NO];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:YES];
        [self.authSecondaryLabel setHidden:YES];
        [self.authSecondaryTextFieldBackgroundView setHidden:YES];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.authButton setEnabled:NO];
        [self.authButton setHidden:YES];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    if ([self isTerminalAuthorizationState:state]) {
        [self.statusField setStringValue:@"Restarting Telegram connection..."];
        [self.loginTitleField setStringValue:TGLoc(@"login.connecting.title")];
        [self.loginHintField setStringValue:TGLoc(@"login.recovering.hint")];
        [self.authLabel setStringValue:TGLoc(@"login.status")];
        [self.authStateField setStringValue:@""];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:YES];
        [self.authSecondaryLabel setHidden:YES];
        [self.authSecondaryTextFieldBackgroundView setHidden:YES];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:TGLoc(@"login.retry")];
        [self.authButton setEnabled:(!self.controlsBusy && !self.authClientRecoveryInFlight && self.authClientRecoveryAttemptCount >= 3)];
        [self.authButton setHidden:(self.authClientRecoveryAttemptCount < 3)];
        [self updateVisibleSection];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self.statusField setStringValue:@"Sign in required"];
        [self.loginTitleField setStringValue:TGLoc(@"login.title")];
        [self.loginHintField setStringValue:TGLoc(@"login.phone.hint")];
        [self.authLabel setStringValue:TGLoc(@"login.phone.label")];
        [[self.authTextField cell] setPlaceholderString:@"+123456789"];
        [[self.authSecureField cell] setPlaceholderString:@""];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:authInputsEnabled];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:(self.authSubmissionInFlight ? TGLoc(@"login.sending") : TGLoc(@"login.send"))];
        [self.authButton setEnabled:authInputsEnabled];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [self scheduleLoginInputFocus];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitCode"]) {
        [self.statusField setStringValue:@"Login code required"];
        [self.loginTitleField setStringValue:TGLoc(@"login.code.title")];
        [self.loginHintField setStringValue:TGLoc(@"login.code.hint")];
        [self.authLabel setStringValue:TGLoc(@"login.code.label")];
        [[self.authTextField cell] setPlaceholderString:@"12345"];
        [[self.authSecureField cell] setPlaceholderString:@""];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:NO];
        [self.authSecureField setHidden:YES];
        [self.authTextField setEnabled:authInputsEnabled];
        [self.authSecureField setEnabled:NO];
        [self.authButton setTitle:(self.authSubmissionInFlight ? TGLoc(@"login.sending") : TGLoc(@"login.send"))];
        [self.authButton setEnabled:authInputsEnabled];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [self scheduleLoginInputFocus];
        [previousState release];
        return;
    }

    if ([state isEqualToString:@"waitPassword"]) {
        [self.statusField setStringValue:@"Password required"];
        [self.loginTitleField setStringValue:TGLoc(@"login.password.title")];
        [self.loginHintField setStringValue:TGLoc(@"login.password.hint")];
        [self.authLabel setStringValue:TGLoc(@"login.password.label")];
        [[self.authTextField cell] setPlaceholderString:@""];
        [[self.authSecureField cell] setPlaceholderString:TGLoc(@"login.password.label")];
        [self.authStateField setHidden:YES];
        [self.authTextField setHidden:YES];
        [self.authSecureField setHidden:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:authInputsEnabled];
        [self.authButton setTitle:(self.authSubmissionInFlight ? TGLoc(@"login.sending") : TGLoc(@"login.send"))];
        [self.authButton setEnabled:authInputsEnabled];
        [self.authButton setHidden:NO];
        [self updateVisibleSection];
        [self scheduleLoginInputFocus];
        [previousState release];
        return;
    }

    [self.authLabel setStringValue:TGLoc(@"login.status")];
    if ([state isEqualToString:@"ready"]) {
        [self.statusField setStringValue:@"Connected"];
        [self.authStateField setStringValue:@""];
    } else if ([state length] > 0) {
        [self.statusField setStringValue:@"Connecting..."];
        [self.authStateField setStringValue:@""];
    } else {
        [self.statusField setStringValue:@"Connecting..."];
        [self.authStateField setStringValue:@""];
    }
    [self.authStateField setHidden:NO];
    [self.authTextField setHidden:YES];
    [self.authSecureField setHidden:YES];
    [self.authSecondaryLabel setHidden:YES];
    [self.authSecondaryTextFieldBackgroundView setHidden:YES];
    [self.authTextField setEnabled:NO];
    [self.authSecureField setEnabled:NO];
    [[self.authTextField cell] setPlaceholderString:@""];
    [[self.authSecureField cell] setPlaceholderString:@""];
    [self.authButton setTitle:TGLoc(@"login.send")];
    [self.authButton setEnabled:NO];
    [self.authButton setHidden:YES];
    [self.loadChatsButton setEnabled:[state isEqualToString:@"ready"]];
    [self.loadMoreChatsButton setEnabled:NO];
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    [self.loadMessagesButton setEnabled:([state isEqualToString:@"ready"] && hasMessageTarget)];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.logoutButton setEnabled:([state isEqualToString:@"ready"] && !self.controlsBusy)];
    [self updateSendControls];
    [self refreshProfileDisplay];
    [self updateVisibleSection];
    if ([state isEqualToString:@"ready"] && !self.profileSummaryLoaded && !self.controlsBusy) {
        [self reloadProfileSummaryIfReady];
    }

    [previousState release];
}

- (void)setControlsBusy:(BOOL)busy {
    _controlsBusy = busy;
    NSUInteger loginLanguageIndex = 0;
    for (loginLanguageIndex = 0; loginLanguageIndex < [self.loginLanguageButtons count]; loginLanguageIndex++) {
        [[self.loginLanguageButtons objectAtIndex:loginLanguageIndex] setEnabled:YES];
    }
    [self.checkButton setEnabled:!busy];
    [self.logsCheckButton setEnabled:!busy];
    [self.logoutButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self updateNavigationButtonsForSection:(self.activeSection ? self.activeSection : TGSectionChats) enabled:!busy];
    [self.loadChatsButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"])];
    [self.loadMoreChatsButton setEnabled:NO];
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    [self.loadMessagesButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.loadOlderMessagesButton setEnabled:NO];
    [self.attachPhotoButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.stickerButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.voiceRecordButton setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.sendTextField setEnabled:(!busy && [self.currentAuthState isEqualToString:@"ready"] && hasMessageTarget)];
    [self.sendMessageButton setEnabled:NO];
    if (busy) {
        [self.authButton setEnabled:NO];
        [self.authTextField setEnabled:NO];
        [self.authSecureField setEnabled:NO];
        [self.loadChatsButton setEnabled:NO];
        [self.loadMoreChatsButton setEnabled:NO];
        [self.loadMessagesButton setEnabled:NO];
        [self.loadOlderMessagesButton setEnabled:NO];
        [self.logoutButton setEnabled:NO];
        [self.chatTableView setEnabled:NO];
        [self.messageTableView setEnabled:NO];
        [self.attachPhotoButton setEnabled:NO];
        [self.stickerButton setEnabled:NO];
        [self.voiceRecordButton setEnabled:NO];
        [self.sendTextField setEnabled:NO];
        [self.sendMessageButton setEnabled:NO];
    } else {
        [self.chatTableView setEnabled:YES];
        [self.messageTableView setEnabled:YES];
        [self updateAuthControlsForState:self.currentAuthState];
        [self handlePendingLiveRefreshesIfPossible];
    }
    [self updateVisibleSection];
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if ([notification object] == self.sendTextField) {
        [self saveCurrentComposerDraft];
        [self updateSendControls];
        [self layoutContentView];
    } else if ([notification object] == self.authTextField || [notification object] == self.authSecureField) {
        if (self.loginErrorVisible) {
            [self setLoginErrorMessage:nil];
            [self updateVisibleSection];
        }
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (control == self.sendTextField &&
        (commandSelector == @selector(insertNewline:) ||
         commandSelector == @selector(insertLineBreak:) ||
         commandSelector == @selector(insertNewlineIgnoringFieldEditor:))) {
        NSUInteger modifierFlags = [[[NSApplication sharedApplication] currentEvent] modifierFlags];
        BOOL wantsLineBreak = (commandSelector == @selector(insertLineBreak:) ||
                               (modifierFlags & NSShiftKeyMask) != 0);
        if (wantsLineBreak) {
            [textView insertNewline:nil];
            [self layoutContentView];
            [self updateSendControls];
            return YES;
        }
        [self sendMessage:control];
        return YES;
    }
    if ((control == self.authTextField || control == self.authSecureField) && commandSelector == @selector(insertNewline:)) {
        [self submitAuthInput:control];
        return YES;
    }
    return NO;
}

- (void)appendDetail:(NSString *)detail {
    if (![detail isKindOfClass:[NSString class]] || [detail length] == 0) {
        return;
    }
    NSString *current = [self.detailsView string];
    NSString *section = TGLogSectionForDetail(detail);
    NSMutableString *addition = [NSMutableString string];
    if (![self.lastLogSection isEqualToString:section]) {
        [addition appendFormat:@"%@%@\n", ([current length] > 0 ? @"\n" : @""), section];
        self.lastLogSection = section;
    }
    [addition appendFormat:@"%@  %@\n", TGLogTimestampString(), detail];
    [self.detailsView setString:[current stringByAppendingString:addition]];
    NSRange endRange = NSMakeRange([[self.detailsView string] length], 0);
    [self.detailsView scrollRangeToVisible:endRange];
    if (self.logsWindowDetailsView) {
        [self.logsWindowDetailsView setString:[self.detailsView string]];
        NSRange logsEndRange = NSMakeRange([[self.logsWindowDetailsView string] length], 0);
        [self.logsWindowDetailsView scrollRangeToVisible:logsEndRange];
    }
}

- (void)setOfflineModeActive:(BOOL)active reason:(NSString *)reason {
    if (active) {
        [self.statusField setStringValue:@"Offline"];
        if (!self.offlineModeActive && [reason length] > 0) {
            [self appendDetail:reason];
        }
    } else if (self.offlineModeActive) {
        [self appendDetail:@"Network connection restored."];
    }
    self.offlineModeActive = active;
}

- (NSRect)messageBubbleCellFrameForRow:(NSInteger)row {
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return NSZeroRect;
    }
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    if (!bubbleColumn) {
        return NSZeroRect;
    }
    NSUInteger columnIndex = [[self.messageTableView tableColumns] indexOfObject:bubbleColumn];
    if (columnIndex == NSNotFound) {
        return NSZeroRect;
    }
    return [self.messageTableView frameOfCellAtColumn:(NSInteger)columnIndex row:row];
}

- (NSArray *)mediaLayoutEntriesForItem:(TGMessageItem *)item inCellFrame:(NSRect)cellFrame {
    if (![item isKindOfClass:[TGMessageItem class]] || ![item isVisualMediaMessage] || NSIsEmptyRect(cellFrame)) {
        return [NSArray array];
    }

    NSString *messageText = ([item isStickerMessage] || TGMessageItemIsNonVisualPlayableMedia(item)) ? @"" : TGDisplayTextForMessageItem(item);
    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    BOOL showSenderDetails = [self shouldShowGroupSenderDetailsForMessageItem:item];
    CGFloat avatarGutter = (!outgoing && showSenderDetails) ? 34.0 : 0.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));

    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
            NSString *statusDots = TGOutgoingStatusDotsInlineTextForItem(item);
            if ([statusDots length] > 0) {
                NSMutableDictionary *statusAttributes = [NSMutableDictionary dictionaryWithDictionary:timeAttributes];
                [statusAttributes setObject:[NSFont boldSystemFontOfSize:7.0] forKey:NSFontAttributeName];
                [statusAttributes setObject:[NSColor colorWithCalibratedWhite:0.470 alpha:0.78] forKey:NSForegroundColorAttributeName];
                NSString *statusSuffix = [NSString stringWithFormat:@" %@", statusDots];
                NSAttributedString *statusSuffixText = [[[NSAttributedString alloc] initWithString:statusSuffix attributes:statusAttributes] autorelease];
                [composedMessageText appendAttributedString:statusSuffixText];
            }
        }
    }

    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [composedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 1000.0)
                                                         options:NSStringDrawingUsesLineFragmentOrigin];
    }

    NSSize photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    CGFloat photoBubbleWidth = photoSize.width + 16.0;
    if (photoBubbleWidth > bubbleWidth) {
        bubbleWidth = photoBubbleWidth;
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }

    CGFloat mediaFooterHeight = TGMessageMediaFooterHeightForItem(item);
    CGFloat senderHeaderHeight = TGMessageSenderHeaderHeightForItem(item, showSenderDetails);
    CGFloat bubbleHeight = photoSize.height + 24.0 + mediaFooterHeight + senderHeaderHeight;
    if (NSHeight(measuredRect) > 0.0) {
        bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }
    bubbleHeight += TGReactionBandHeightForMessageItem(item);

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding + avatarGutter);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
    CGFloat contentTop = NSMaxY(bubbleRect) - 9.0;
    contentTop -= senderHeaderHeight;
    CGFloat reactionBandHeight = TGReactionBandHeightForMessageItem(item);
    contentTop -= reactionBandHeight;
    if ([messageText length] == 0 && mediaFooterHeight > 0.0) {
        contentTop -= mediaFooterHeight;
    }
    NSRect imageRect = NSMakeRect(NSMinX(bubbleRect) + floor((NSWidth(bubbleRect) - photoSize.width) / 2.0),
                                  contentTop - photoSize.height,
                                  photoSize.width,
                                  photoSize.height);
    NSArray *mediaItems = [item visualMediaItems];
    NSArray *tileRects = TGMediaTileRectsForMessageItem(item, imageRect);
    NSMutableArray *entries = [NSMutableArray array];
    NSUInteger tileIndex = 0;
    NSUInteger tileCount = [tileRects count];
    NSUInteger mediaCount = [mediaItems count];
    for (tileIndex = 0; tileIndex < tileCount && tileIndex < mediaCount; tileIndex++) {
        NSRect tileRect = [[tileRects objectAtIndex:tileIndex] rectValue];
        id mediaObject = [mediaItems objectAtIndex:tileIndex];
        if (![mediaObject isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        [entries addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                            mediaObject, @"media_item",
                            [NSValue valueWithRect:tileRect], @"frame",
                            [NSNumber numberWithUnsignedInteger:tileIndex], @"tile_index",
                            nil]];
    }
    return entries;
}

- (NSDictionary *)mediaItemForItem:(TGMessageItem *)item inCellFrame:(NSRect)cellFrame atPoint:(NSPoint)tablePoint {
    NSArray *entries = [self mediaLayoutEntriesForItem:item inCellFrame:cellFrame];
    NSUInteger index = 0;
    for (index = 0; index < [entries count]; index++) {
        NSDictionary *entry = [entries objectAtIndex:index];
        NSRect tileRect = [[entry objectForKey:@"frame"] rectValue];
        if (NSPointInRect(tablePoint, tileRect)) {
            return [entry objectForKey:@"media_item"];
        }
    }
    return nil;
}

- (void)scheduleInlineMediaPlaybackRefresh {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(refreshInlineMediaPlayback)
                                               object:nil];
    [self performSelector:@selector(refreshInlineMediaPlayback) withObject:nil afterDelay:0.0];
}

- (void)refreshInlineMediaPlayback {
    BOOL chatsVisible = ([self.currentAuthState isEqualToString:@"ready"] &&
                         [(self.activeSection ? self.activeSection : TGSectionChats) isEqualToString:TGSectionChats] &&
                         ![self.messageScrollView isHidden] &&
                         ![self.messageTableView isHidden]);
    if (!chatsVisible || [self.messageItems count] == 0 || [self.stickerPickerWindow isVisible]) {
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
        return;
    }

    NSRect visibleRect = [[self.messageScrollView contentView] bounds];
    NSRange visibleRows = [self.messageTableView rowsInRect:visibleRect];
    if (visibleRows.location == NSNotFound || visibleRows.length == 0) {
        [self.inlineMediaPlaybackCoordinator removeAllPlayback];
        return;
    }

    NSMutableArray *descriptors = [NSMutableArray array];
    NSUInteger lastRow = NSMaxRange(visibleRows);
    if (lastRow > [self.messageItems count]) {
        lastRow = [self.messageItems count];
    }
    NSUInteger row = 0;
    for (row = visibleRows.location; row < lastRow && [descriptors count] < 5; row++) {
        id candidate = [self.messageItems objectAtIndex:row];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *item = (TGMessageItem *)candidate;
        NSArray *entries = [self mediaLayoutEntriesForItem:item inCellFrame:[self messageBubbleCellFrameForRow:(NSInteger)row]];
        NSUInteger entryIndex = 0;
        for (entryIndex = 0; entryIndex < [entries count] && [descriptors count] < 5; entryIndex++) {
            NSDictionary *entry = [entries objectAtIndex:entryIndex];
            NSDictionary *mediaItem = [entry objectForKey:@"media_item"];
            NSRect frame = [[entry objectForKey:@"frame"] rectValue];
            NSString *path = TGInlinePlaybackPathForMediaItem(mediaItem);
            NSString *contentType = TGMediaItemContentType(mediaItem);
            NSString *extension = [[path pathExtension] lowercaseString];
            NSString *playbackKind = TGInlinePlaybackKindForMediaItem(mediaItem);
            BOOL animation = ([contentType isEqualToString:@"messageAnimation"] ||
                              [extension isEqualToString:@"gif"] ||
                              [playbackKind isEqualToString:TGInlineMediaKindTGS]);
            if (!animation || [path length] == 0 || !NSIntersectsRect(frame, visibleRect)) {
                continue;
            }
            id messageID = [mediaItem objectForKey:@"message_id"];
            if (![messageID respondsToSelector:@selector(longLongValue)]) {
                messageID = [item messageID];
            }
            NSNumber *tileIndex = [entry objectForKey:@"tile_index"];
            NSString *identifier = [NSString stringWithFormat:@"%@:%@:%@",
                                    messageID ? messageID : [NSNumber numberWithUnsignedInteger:row],
                                    tileIndex ? tileIndex : [NSNumber numberWithUnsignedInteger:entryIndex],
                                    path];
            [descriptors addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                    identifier, TGInlineMediaIdentifierKey,
                                    path, TGInlineMediaPathKey,
                                    [NSValue valueWithRect:frame], TGInlineMediaFrameKey,
                                    playbackKind, TGInlineMediaKindKey,
                                    nil]];
        }
    }
    [self.inlineMediaPlaybackCoordinator updateWithDescriptors:descriptors];
}

- (NSURL *)messageLinkURLForItem:(TGMessageItem *)item inCellFrame:(NSRect)cellFrame atPoint:(NSPoint)tablePoint {
    if (![item isKindOfClass:[TGMessageItem class]] || NSIsEmptyRect(cellFrame)) {
        return nil;
    }
    if (TGMessageItemIsNonVisualPlayableMedia(item)) {
        return nil;
    }
    NSString *messageText = TGDisplayTextForMessageItem(item);
    if ([messageText length] == 0 || !TGFirstURLInMessageItem(item)) {
        return nil;
    }

    BOOL outgoing = [item outgoing];
    CGFloat sidePadding = 14.0;
    BOOL showSenderDetails = [self shouldShowGroupSenderDetailsForMessageItem:item];
    CGFloat avatarGutter = (!outgoing && showSenderDetails) ? 34.0 : 0.0;
    CGFloat maximumBubbleWidth = TGMaximumBubbleWidthForItem(item, NSWidth(cellFrame));

    NSMutableParagraphStyle *paragraph = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraph setLineBreakMode:NSLineBreakByWordWrapping];
    NSDictionary *textAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12.0], NSFontAttributeName,
                                    TGClassicInkColor(), NSForegroundColorAttributeName,
                                    paragraph, NSParagraphStyleAttributeName,
                                    nil];
    NSString *timeString = TGShortTimeStringFromDateValue([item date]);
    NSDictionary *timeAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:9.0], NSFontAttributeName,
                                    TGClassicTimeTextColor(), NSForegroundColorAttributeName,
                                    nil];
    NSMutableAttributedString *composedMessageText = [[[NSMutableAttributedString alloc] init] autorelease];
    if ([messageText length] > 0) {
        NSMutableAttributedString *baseText = [[TGAttributedMessageString(messageText, textAttributes) mutableCopy] autorelease];
        [composedMessageText appendAttributedString:baseText];
        if ([timeString length] > 0) {
            NSString *timeSuffix = [NSString stringWithFormat:@"  %@", timeString];
            NSAttributedString *timeSuffixText = [[[NSAttributedString alloc] initWithString:timeSuffix attributes:timeAttributes] autorelease];
            [composedMessageText appendAttributedString:timeSuffixText];
        }
    }
    NSAttributedString *attributedMessageText = composedMessageText;
    NSRect measuredRect = NSZeroRect;
    if ([messageText length] > 0) {
        measuredRect = [attributedMessageText boundingRectWithSize:NSMakeSize(maximumBubbleWidth - 24.0, 1000.0)
                                                           options:NSStringDrawingUsesLineFragmentOrigin];
    } else {
        measuredRect = NSZeroRect;
    }
    NSSize photoSize = NSZeroSize;
    BOOL visualMediaMessage = [item isVisualMediaMessage];
    if (visualMediaMessage) {
        photoSize = TGPhotoDisplaySizeForMessageItem(item, maximumBubbleWidth - 16.0);
    }

    CGFloat bubbleWidth = ceil(NSWidth(measuredRect)) + 28.0;
    if (visualMediaMessage) {
        CGFloat photoBubbleWidth = photoSize.width + 16.0;
        if (photoBubbleWidth > bubbleWidth) {
            bubbleWidth = photoBubbleWidth;
        }
    }
    if (bubbleWidth < 96.0) {
        bubbleWidth = 96.0;
    }
    if (bubbleWidth > maximumBubbleWidth) {
        bubbleWidth = maximumBubbleWidth;
    }

    CGFloat senderHeaderHeight = TGMessageSenderHeaderHeightForItem(item, showSenderDetails);
    CGFloat bubbleHeight = ceil(NSHeight(measuredRect)) + 26.0 + senderHeaderHeight;
    if (visualMediaMessage) {
        bubbleHeight = photoSize.height + 24.0 + senderHeaderHeight;
        if (NSHeight(measuredRect) > 0.0) {
            bubbleHeight += ceil(NSHeight(measuredRect)) + 8.0;
        }
    }
    if (bubbleHeight < 42.0) {
        bubbleHeight = 42.0;
    }
    bubbleHeight += TGReactionBandHeightForMessageItem(item);

    CGFloat bubbleX = outgoing ? (NSMaxX(cellFrame) - bubbleWidth - sidePadding) : (NSMinX(cellFrame) + sidePadding + avatarGutter);
    NSRect bubbleRect = NSMakeRect(bubbleX, NSMinY(cellFrame) + 5.0, bubbleWidth, bubbleHeight);
    CGFloat contentTop = NSMaxY(bubbleRect) - 9.0;
    contentTop -= senderHeaderHeight;
    if (visualMediaMessage) {
        NSRect imageRect = NSMakeRect(NSMinX(bubbleRect) + floor((NSWidth(bubbleRect) - photoSize.width) / 2.0),
                                      contentTop - photoSize.height,
                                      photoSize.width,
                                      photoSize.height);
        contentTop = NSMinY(imageRect) - 8.0;
    }

    CGFloat textHeight = ceil(NSHeight(measuredRect));
    if (textHeight <= 0.0) {
        return nil;
    }
    NSRect textRect = NSMakeRect(NSMinX(bubbleRect) + 12.0,
                                 contentTop - textHeight,
                                 NSWidth(bubbleRect) - 24.0,
                                 textHeight + 2.0);
    if (!NSPointInRect(tablePoint, textRect)) {
        return nil;
    }

    NSTextStorage *textStorage = [[[NSTextStorage alloc] initWithAttributedString:attributedMessageText] autorelease];
    NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
    NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize:NSMakeSize(NSWidth(textRect), 1000.0)] autorelease];
    [textContainer setLineFragmentPadding:0.0];
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];
    [layoutManager glyphRangeForTextContainer:textContainer];

    NSPoint textPoint = NSMakePoint(tablePoint.x - NSMinX(textRect), tablePoint.y - NSMinY(textRect));
    CGFloat fraction = 0.0;
    NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:textPoint
                                               inTextContainer:textContainer
                        fractionOfDistanceThroughGlyph:&fraction];
    if (glyphIndex >= [layoutManager numberOfGlyphs]) {
        return nil;
    }
    NSRect glyphRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                                inTextContainer:textContainer];
    if (!NSPointInRect(textPoint, NSInsetRect(glyphRect, -3.0, -4.0))) {
        return nil;
    }
    NSUInteger characterIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
    if (characterIndex >= [messageText length]) {
        return nil;
    }
    return TGURLAtCharacterIndexInString(messageText, characterIndex);
}

- (void)openMessageLink:(id)sender {
    (void)sender;
    NSInteger row = [self.messageTableView clickedRow];
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return;
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return;
    }
    NSEvent *event = [NSApp currentEvent];
    if (!event) {
        return;
    }
    NSPoint tablePoint = [self.messageTableView convertPoint:[event locationInWindow] fromView:nil];
    NSRect cellFrame = [self messageBubbleCellFrameForRow:row];
    NSDictionary *mediaItem = [self mediaItemForItem:(TGMessageItem *)item
                                        inCellFrame:cellFrame
                                            atPoint:tablePoint];
    if (mediaItem) {
        [self openMediaPreviewForMediaItem:mediaItem];
        return;
    }
    if (TGMessageItemIsNonVisualPlayableMedia((TGMessageItem *)item)) {
        NSRect bubbleRect = TGMessageBubbleRectForItem((TGMessageItem *)item, cellFrame, [self shouldShowGroupSenderDetailsForMessageItem:(TGMessageItem *)item]);
        if (!NSIsEmptyRect(bubbleRect) && NSPointInRect(tablePoint, bubbleRect)) {
            [self openPlayableMediaForMessageItem:(TGMessageItem *)item];
            return;
        }
    }

    NSURL *url = [self messageLinkURLForItem:(TGMessageItem *)item
                                 inCellFrame:cellFrame
                                     atPoint:tablePoint];
    if (!url) {
        return;
    }
    if ([[NSWorkspace sharedWorkspace] openURL:url]) {
        [self appendDetail:@"Opened message link in default browser."];
    } else {
        [self appendDetail:@"Could not open message link in default browser."];
    }
}

#include "TGStatusWindowController+MessageMenus.inc"

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    if (tableView == self.messageTableView) {
        return (NSInteger)[self.messageItems count];
    }
    return (NSInteger)[self.chatItems count];
}

- (BOOL)shouldShowGroupSenderDetailsForMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]] || [item outgoing] || [[item senderDisplayName] length] == 0) {
        return NO;
    }
    NSString *type = [self.selectedChatTypeSummary lowercaseString];
    if ([type length] == 0 && !self.selectedMessageThreadID) {
        return NO;
    }
    BOOL groupLike = ([type rangeOfString:@"group"].location != NSNotFound ||
                      [type rangeOfString:@"forum"].location != NSNotFound ||
                      [type rangeOfString:@"thread"].location != NSNotFound ||
                      [type rangeOfString:@"topic"].location != NSNotFound ||
                      self.selectedMessageThreadID != nil);
    return groupLike;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (tableView != self.messageTableView) {
        return [tableView rowHeight];
    }
    if (row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return [tableView rowHeight];
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return [tableView rowHeight];
    }
    NSTableColumn *bubbleColumn = [self.messageTableView tableColumnWithIdentifier:@"bubble"];
    CGFloat availableWidth = bubbleColumn ? [bubbleColumn width] : NSWidth([self.messageScrollView frame]);
    return TGMessageBubbleHeightForItem((TGMessageItem *)item, availableWidth, [self shouldShowGroupSenderDetailsForMessageItem:(TGMessageItem *)item]);
}

- (NSString *)tableView:(NSTableView *)tableView
      toolTipForCell:(NSCell *)cell
                rect:(NSRectPointer)rect
         tableColumn:(NSTableColumn *)tableColumn
                 row:(NSInteger)row
       mouseLocation:(NSPoint)mouseLocation {
    (void)cell;
    (void)rect;
    (void)tableColumn;
    (void)mouseLocation;
    if (tableView != self.messageTableView || row < 0 || (NSUInteger)row >= [self.messageItems count]) {
        return nil;
    }
    id item = [self.messageItems objectAtIndex:(NSUInteger)row];
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }
    NSRect cellFrame = [self messageBubbleCellFrameForRow:row];
    NSDictionary *mediaItem = [self mediaItemForItem:(TGMessageItem *)item
                                        inCellFrame:cellFrame
                                            atPoint:mouseLocation];
    if (mediaItem) {
        if (!TGMediaItemSupportsPreview(mediaItem)) {
            return nil;
        }
        return TGMediaItemIsPlayable(mediaItem) ? @"Play media" : @"Open media preview";
    }
    if (TGMessageItemIsNonVisualPlayableMedia((TGMessageItem *)item)) {
        NSRect bubbleRect = TGMessageBubbleRectForItem((TGMessageItem *)item, cellFrame, [self shouldShowGroupSenderDetailsForMessageItem:(TGMessageItem *)item]);
        if (!NSIsEmptyRect(bubbleRect) && NSPointInRect(mouseLocation, bubbleRect)) {
            return @"Play media";
        }
    }
    NSURL *url = [self messageLinkURLForItem:(TGMessageItem *)item
                                 inCellFrame:cellFrame
                                     atPoint:mouseLocation];
    return url ? @"Open link in default browser" : nil;
}

- (NSDragOperation)tableView:(NSTableView *)tableView
                validateDrop:(id <NSDraggingInfo>)info
                  proposedRow:(NSInteger)row
        proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    (void)row;
    (void)dropOperation;
    if (tableView != self.messageTableView) {
        return NSDragOperationNone;
    }
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget || self.controlsBusy) {
        [self showMessageDropOverlay:NO];
        return NSDragOperationNone;
    }
    NSString *photoPath = TGFirstSupportedPhotoPathFromPasteboard([info draggingPasteboard]);
    BOOL canDropPhoto = ([photoPath length] > 0);
    if (canDropPhoto) {
        [self.messageTableView setDropRow:-1 dropOperation:NSTableViewDropOn];
        [self showMessageDropOverlay:YES];
        return NSDragOperationCopy;
    }
    [self showMessageDropOverlay:NO];
    return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)tableView
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)dropOperation {
    (void)row;
    (void)dropOperation;
    [self showMessageDropOverlay:NO];
    if (tableView != self.messageTableView) {
        return NO;
    }
    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (![self.currentAuthState isEqualToString:@"ready"] || !hasMessageTarget || self.controlsBusy) {
        return NO;
    }
    NSString *photoPath = TGFirstSupportedPhotoPathFromPasteboard([info draggingPasteboard]);
    if ([photoPath length] == 0) {
        return NO;
    }
    [self sendPhotoAtPath:photoPath];
    return YES;
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    if (![cell isKindOfClass:[NSTextFieldCell class]]) {
        return;
    }
    NSTextFieldCell *textCell = (NSTextFieldCell *)cell;
    id identifier = [tableColumn identifier];
    if (tableView == self.chatTableView && [identifier isEqual:@"chat"] && [cell isKindOfClass:[TGChatListCell class]]) {
        TGChatItem *chatItem = nil;
        if (row >= 0 && (NSUInteger)row < [self.chatItems count]) {
            id item = [self.chatItems objectAtIndex:(NSUInteger)row];
            if ([item isKindOfClass:[TGChatItem class]]) {
                chatItem = (TGChatItem *)item;
            }
        }
        [(TGChatListCell *)cell setHighlighted:[tableView isRowSelected:row]];
        [(TGChatListCell *)cell setChatItem:chatItem];
        return;
    }
    if (tableView == self.messageTableView && [identifier isEqual:@"bubble"] && [cell isKindOfClass:[TGMessageBubbleCell class]]) {
        TGMessageItem *messageItem = nil;
        if (row >= 0 && (NSUInteger)row < [self.messageItems count]) {
            id item = [self.messageItems objectAtIndex:(NSUInteger)row];
            if ([item isKindOfClass:[TGMessageItem class]]) {
                messageItem = (TGMessageItem *)item;
            }
        }
        [(TGMessageBubbleCell *)cell setMessageItem:messageItem];
        [(TGMessageBubbleCell *)cell setShowSenderDetails:[self shouldShowGroupSenderDetailsForMessageItem:messageItem]];
        [self scheduleInlineMediaPlaybackRefresh];
        return;
    }
    [textCell setAlignment:NSLeftTextAlignment];
    [textCell setFont:[NSFont systemFontOfSize:12.0]];
    [textCell setTextColor:TGClassicInkColor()];
    [textCell setDrawsBackground:NO];
    [textCell setLineBreakMode:NSLineBreakByTruncatingTail];

    if (tableView == self.chatTableView) {
        BOOL selected = [tableView isRowSelected:row];
        if (selected) {
            [textCell setDrawsBackground:YES];
            [textCell setBackgroundColor:TGClassicSelectedRowColor()];
            [textCell setTextColor:TGClassicSelectedRowTextColor()];
        }
        if ([identifier isEqual:@"title"]) {
            [textCell setFont:[NSFont boldSystemFontOfSize:12.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicInkColor()];
            }
        } else if ([identifier isEqual:@"unread_count"]) {
            [textCell setFont:[NSFont boldSystemFontOfSize:11.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicUnreadTextColor()];
            }
            [textCell setAlignment:NSCenterTextAlignment];
        } else {
            [textCell setFont:[NSFont systemFontOfSize:11.0]];
            if (!selected) {
                [textCell setTextColor:TGClassicMutedInkColor()];
            }
        }
    } else if (tableView == self.messageTableView) {
        if ([identifier isEqual:@"date"] || [identifier isEqual:@"direction"]) {
            [textCell setFont:[NSFont systemFontOfSize:11.0]];
            [textCell setTextColor:TGClassicMutedInkColor()];
        } else {
            [textCell setFont:[NSFont systemFontOfSize:12.0]];
            [textCell setTextColor:TGClassicInkColor()];
        }
    }
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *items = (tableView == self.messageTableView) ? self.messageItems : self.chatItems;
    if (row < 0 || (NSUInteger)row >= [items count]) {
        return @"";
    }

    id item = [items objectAtIndex:(NSUInteger)row];
    id identifier = [tableColumn identifier];
    id value = nil;
    if (tableView == self.messageTableView && [item isKindOfClass:[TGMessageItem class]]) {
        if ([identifier isEqual:@"bubble"]) {
            value = @"";
        } else {
            value = [(TGMessageItem *)item valueForTableColumnIdentifier:identifier];
        }
    } else if (tableView == self.chatTableView && [item isKindOfClass:[TGChatItem class]]) {
        if ([identifier isEqual:@"chat"]) {
            value = @"";
        } else {
            value = [(TGChatItem *)item valueForTableColumnIdentifier:identifier];
        }
    }
    if (tableView == self.messageTableView && [identifier isEqual:@"date"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger timestamp = [value integerValue];
        if (timestamp <= 0) {
            return @"";
        }
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)timestamp];
        return [NSDateFormatter localizedStringFromDate:date
                                              dateStyle:NSDateFormatterNoStyle
                                              timeStyle:NSDateFormatterShortStyle];
    }
    if ([identifier isEqual:@"unread_count"] && [value respondsToSelector:@selector(integerValue)]) {
        NSInteger unreadCount = [value integerValue];
        if (unreadCount <= 0) {
            return @"";
        }
        if (unreadCount > 999) {
            return @"999+";
        }
        return [NSString stringWithFormat:@"%ld", (long)unreadCount];
    }
    return value ? value : @"";
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([notification object] != self.chatTableView) {
        return;
    }
    if (self.suppressChatSelectionHandling) {
        return;
    }

    NSNumber *previousChatID = [self.selectedChatID retain];
    NSNumber *previousThreadID = [self.selectedMessageThreadID retain];
    NSString *previousTopicKind = [self.selectedMessageTopicKind copy];
    [self saveComposerDraftForChatID:previousChatID
                     messageThreadID:previousThreadID
                      messageTopicKind:previousTopicKind];
    NSInteger clickedRow = [self.chatTableView clickedRow];
    NSInteger row = (clickedRow >= 0) ? clickedRow : [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        self.selectedChatID = nil;
        self.selectedChatTitle = nil;
        self.selectedChatTypeSummary = nil;
        self.selectedChatAvatarLocalPath = nil;
        self.selectedChatLastReadOutboxMessageID = nil;
        self.selectedMessageThreadID = nil;
        self.selectedMessageTopicKind = nil;
        [self refreshSelectedChatHeaderDisplay];
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        [self setComposerTextWithoutSavingDraft:nil];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self updateAuthControlsForState:self.currentAuthState];
        [previousChatID release];
        [previousThreadID release];
        [previousTopicKind release];
        return;
    }

    TGChatItem *item = [[self.chatItems objectAtIndex:(NSUInteger)row] retain];
    BOOL selectedForumTopic = [item isForumTopic];
    id chatID = selectedForumTopic ? [item parentChatID] : [item chatID];
    id title = [item title];
    NSNumber *newChatID = nil;
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        newChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
        self.selectedChatID = newChatID;
    } else {
        self.selectedChatID = nil;
    }
    NSNumber *newThreadID = nil;
    NSString *newTopicKind = nil;
    if (selectedForumTopic && [[item messageThreadID] respondsToSelector:@selector(longLongValue)]) {
        newThreadID = [NSNumber numberWithLongLong:[[item messageThreadID] longLongValue]];
        newTopicKind = [[item messageTopicKind] length] > 0 ? [item messageTopicKind] : @"forum";
    }
    self.selectedMessageThreadID = newThreadID;
    self.selectedMessageTopicKind = newTopicKind;

    BOOL sameChat = ((previousChatID && newChatID) && ([previousChatID longLongValue] == [newChatID longLongValue]));
    BOOL sameThread = ((!previousThreadID && !newThreadID) ||
                       (previousThreadID && newThreadID && [previousThreadID longLongValue] == [newThreadID longLongValue]));
    BOOL sameTopicKind = ((!previousTopicKind && !newTopicKind) ||
                          (previousTopicKind && newTopicKind && [previousTopicKind isEqualToString:newTopicKind]));
    BOOL selectionChanged = !(sameChat && sameThread && sameTopicKind);
    self.selectedChatTitle = [title isKindOfClass:[NSString class]] ? (NSString *)title : @"Selected chat";
    self.selectedChatTypeSummary = [item typeSummary];
    self.selectedChatAvatarLocalPath = [item avatarLocalPath];
    self.selectedChatLastReadOutboxMessageID = [item lastReadOutboxMessageID];
    [self updateOutgoingReadStateForVisibleMessages];
    [self refreshSelectedChatHeaderDisplay];
    BOOL shouldOpenTopicList = (!selectedForumTopic && !self.showingForumTopicList && [[item typeSummary] isEqualToString:@"Supergroup"]);
    if (selectionChanged) {
        [self clearTypingIndicator];
        [self.messageItems removeAllObjects];
        [self.messageTableView reloadData];
        if (shouldOpenTopicList) {
            [self setComposerTextWithoutSavingDraft:nil];
        } else {
            [self restoreComposerDraftForChatID:newChatID
                                messageThreadID:newThreadID
                                 messageTopicKind:newTopicKind];
        }
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
    }
    [self updateAuthControlsForState:self.currentAuthState];
    if (selectedForumTopic) {
        if (newThreadID) {
            [self appendDetail:[NSString stringWithFormat:@"Forum topic selected: %@ (%lld).", self.selectedChatTitle ? self.selectedChatTitle : @"Topic", [newThreadID longLongValue]]];
        }
    } else if (shouldOpenTopicList) {
        [self removeForumTopicRowsPreservingChatID:newChatID];
        [self loadForumTopicsForChatItem:item];
    }
    if (newChatID && (selectionChanged || [self.messageItems count] == 0)) {
        if (selectedForumTopic) {
            [self reloadMessagesForChatID:newChatID interactive:NO];
        } else if (!shouldOpenTopicList) {
            [self reloadMessagesForChatID:newChatID interactive:NO];
        }
    }
    [previousChatID release];
    [previousThreadID release];
    [previousTopicKind release];
    [item release];
}

- (void)activateSelectedChatRow:(id)sender {
    (void)sender;
    if (self.suppressChatSelectionHandling || self.showingForumTopicList || self.forumTopicRefreshInFlight) {
        return;
    }

    NSInteger row = [self.chatTableView selectedRow];
    if (row < 0 || (NSUInteger)row >= [self.chatItems count]) {
        return;
    }

    id candidate = [self.chatItems objectAtIndex:(NSUInteger)row];
    if (![candidate isKindOfClass:[TGChatItem class]]) {
        return;
    }

    TGChatItem *item = [(TGChatItem *)candidate retain];
    if ([item isForumTopic] || ![[item typeSummary] isEqualToString:@"Supergroup"]) {
        [item release];
        return;
    }

    id chatID = [item chatID];
    NSNumber *selectedChatID = nil;
    if ([chatID respondsToSelector:@selector(longLongValue)]) {
        selectedChatID = [NSNumber numberWithLongLong:[chatID longLongValue]];
    }
    [self removeForumTopicRowsPreservingChatID:selectedChatID];
    [self loadForumTopicsForChatItem:item];
    [item release];
}

- (void)applyChatItems:(NSArray *)items preserveSelection:(BOOL)preserveSelection preferredChatID:(NSNumber *)preferredChatID {
    [self clearForumTopicListState];
    NSUInteger selectedIndex = NSNotFound;

    if (preserveSelection && preferredChatID) {
        NSUInteger index = 0;
        for (index = 0; index < [items count]; index++) {
            TGChatItem *item = [items objectAtIndex:index];
            id chatID = [item chatID];
            if ([chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [preferredChatID longLongValue]) {
                selectedIndex = index;
                break;
            }
        }
    }

    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:items];
    [self applyLocalNotificationMuteStateToItems:self.chatItems];
    [self.chatTableView reloadData];
    [self updateApplicationBadge];
    self.autoChatListLoadArmed = YES;
    self.autoChatListRefreshArmed = NO;

    if (self.pendingNotificationChatID) {
        NSNumber *pendingChatID = [self.pendingNotificationChatID retain];
        NSNumber *pendingThreadID = [self.pendingNotificationThreadID retain];
        if ([self selectChatFromNotificationWithChatID:pendingChatID messageThreadID:pendingThreadID]) {
            self.pendingNotificationChatID = nil;
            self.pendingNotificationThreadID = nil;
            [pendingChatID release];
            [pendingThreadID release];
            return;
        }
        [pendingChatID release];
        [pendingThreadID release];
    }

    if (selectedIndex != NSNotFound) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:selectedIndex];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
        id selectedItem = [items objectAtIndex:selectedIndex];
        if ([selectedItem isKindOfClass:[TGChatItem class]]) {
            self.selectedChatLastReadOutboxMessageID = [(TGChatItem *)selectedItem lastReadOutboxMessageID];
            [self updateOutgoingReadStateForVisibleMessages];
        }
        return;
    }

    if ([items count] > 0 && [self.currentAuthState isEqualToString:@"ready"]) {
        NSIndexSet *selection = [NSIndexSet indexSetWithIndex:0];
        [self.chatTableView selectRowIndexes:selection byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:0];
        return;
    }

    [self.chatTableView deselectAll:nil];
    self.selectedChatID = nil;
    self.selectedChatTitle = nil;
    self.selectedChatTypeSummary = nil;
    self.selectedChatAvatarLocalPath = nil;
    self.selectedChatLastReadOutboxMessageID = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    [self refreshSelectedChatHeaderDisplay];
    [self.messageItems removeAllObjects];
    [self.messageTableView reloadData];
    [self setComposerTextWithoutSavingDraft:nil];
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self updateAuthControlsForState:self.currentAuthState];
}

- (BOOL)chatItemsContainForumTopicRows {
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id item = [self.chatItems objectAtIndex:index];
        if ([item isKindOfClass:[TGChatItem class]] && [(TGChatItem *)item isForumTopic]) {
            return YES;
        }
    }
    return NO;
}

- (NSArray *)chatItemsByRemovingForumTopicRowsFromItems:(NSArray *)items {
    NSMutableArray *baseItems = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id item = [items objectAtIndex:index];
        if ([item isKindOfClass:[TGChatItem class]] && [(TGChatItem *)item isForumTopic]) {
            continue;
        }
        [baseItems addObject:item];
    }
    return baseItems;
}

- (NSUInteger)indexOfChatID:(NSNumber *)chatID inChatItems:(NSArray *)items {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return NSNotFound;
    }
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id item = [items objectAtIndex:index];
        if (![item isKindOfClass:[TGChatItem class]] || [(TGChatItem *)item isForumTopic]) {
            continue;
        }
        id itemChatID = [(TGChatItem *)item chatID];
        if ([itemChatID respondsToSelector:@selector(longLongValue)] && [itemChatID longLongValue] == [chatID longLongValue]) {
            return index;
        }
    }
    return NSNotFound;
}

- (void)removeForumTopicRowsPreservingChatID:(NSNumber *)chatID {
    if (![self chatItemsContainForumTopicRows]) {
        return;
    }
    NSArray *baseItems = [self chatItemsByRemovingForumTopicRowsFromItems:self.chatItems];
    NSUInteger selectedIndex = [self indexOfChatID:chatID inChatItems:baseItems];
    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:baseItems];
    [self.chatTableView reloadData];
    if (selectedIndex != NSNotFound) {
        [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
    }
    self.suppressChatSelectionHandling = NO;
}

- (NSString *)displayTitleForTopicItem:(TGChatItem *)item {
    NSString *title = [item title];
    if (![title isKindOfClass:[NSString class]]) {
        return @"Topic";
    }
    return [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)showForumTopicListForChatItem:(TGChatItem *)chatItem topics:(NSArray *)topics {
    if (!chatItem || [topics count] == 0) {
        return;
    }

    self.chatItemsBeforeTopicList = [NSArray arrayWithArray:[self chatItemsByRemovingForumTopicRowsFromItems:self.chatItems]];
    self.topicParentChatID = [chatItem chatID];
    self.topicParentTitle = [chatItem title];
    self.topicParentAvatarLocalPath = [chatItem avatarLocalPath];
    self.showingForumTopicList = YES;
    [self.loadChatsButton setToolTip:@"Refresh topics"];
    self.chatsExhausted = YES;
    self.autoChatListLoadArmed = NO;
    self.autoChatListRefreshArmed = NO;

    NSMutableArray *topicItems = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [topics count]; index++) {
        id candidate = [topics objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *topicItem = (TGChatItem *)candidate;
        [topicItem setAvatarLocalPath:self.topicParentAvatarLocalPath];
        [topicItems addObject:topicItem];
    }
    [self applyLocalNotificationMuteStateToItems:topicItems];

    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:topicItems];
    [self.chatTableView reloadData];
    [self.chatTableView deselectAll:nil];
    self.suppressChatSelectionHandling = NO;

    self.selectedChatID = self.topicParentChatID;
    self.selectedChatTitle = self.topicParentTitle;
    self.selectedChatTypeSummary = @"Forum";
    self.selectedChatAvatarLocalPath = self.topicParentAvatarLocalPath;
    self.selectedChatLastReadOutboxMessageID = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    [self refreshSelectedChatHeaderDisplay];
    [self.messageItems removeAllObjects];
    [self.messageTableView reloadData];
    [self setComposerTextWithoutSavingDraft:nil];
    NSString *topicListTitle = ([self.topicParentTitle length] > 0 ? self.topicParentTitle : @"Topics");
    [self.chatsLabel setStringValue:[NSString stringWithFormat:@"%@ (%lu)", topicListTitle, (unsigned long)[topicItems count]]];
    [self updateAuthControlsForState:self.currentAuthState];
    [self layoutContentView];
    [self updateVisibleSection];
}

- (void)closeForumTopicList:(id)sender {
    (void)sender;
    if (!self.showingForumTopicList) {
        return;
    }

    NSNumber *parentChatID = [self.topicParentChatID retain];
    self.showingForumTopicList = NO;
    self.topicParentChatID = nil;
    self.topicParentTitle = nil;
    self.topicParentAvatarLocalPath = nil;
    self.selectedMessageThreadID = nil;
    self.selectedMessageTopicKind = nil;
    self.chatsExhausted = NO;
    self.autoChatListRefreshArmed = YES;

    NSArray *restoreItems = self.chatItemsBeforeTopicList ? self.chatItemsBeforeTopicList : [NSArray array];
    NSUInteger selectedIndex = [self indexOfChatID:parentChatID inChatItems:restoreItems];
    self.suppressChatSelectionHandling = YES;
    [self.chatItems removeAllObjects];
    [self.chatItems addObjectsFromArray:restoreItems];
    [self.chatTableView reloadData];
    if (selectedIndex != NSNotFound) {
        [self.chatTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedIndex] byExtendingSelection:NO];
        [self.chatTableView scrollRowToVisible:selectedIndex];
    } else {
        [self.chatTableView deselectAll:nil];
    }
    self.suppressChatSelectionHandling = NO;
    self.chatItemsBeforeTopicList = nil;
    [self.chatsLabel setStringValue:@"Chats"];
    [self updateAuthControlsForState:self.currentAuthState];
    [self layoutContentView];
    [self updateVisibleSection];
    [parentChatID release];
}

- (void)reloadCurrentForumTopicListInteractive:(BOOL)interactive {
    if (!self.showingForumTopicList || ![self.topicParentChatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    NSNumber *parentChatID = [self.topicParentChatID retain];
    NSString *parentTitle = [self.topicParentTitle copy];
    NSString *parentAvatarPath = [self.topicParentAvatarLocalPath copy];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading topics..."];
        [self appendDetail:@"Reloading forum topics from TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *topicError = nil;
        NSArray *topics = [[client threadPreviewItemsForChatID:parentChatID limit:24 timeout:6.0 error:&topicError] retain];
        NSString *topicErrorMessage = [[topicError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL stillCurrent = (self.showingForumTopicList && self.topicParentChatID && [self.topicParentChatID longLongValue] == [parentChatID longLongValue]);
            if (stillCurrent && [topics count] > 0) {
                NSMutableArray *topicItems = [NSMutableArray array];
                NSUInteger index = 0;
                for (index = 0; index < [topics count]; index++) {
                    id candidate = [topics objectAtIndex:index];
                    if (![candidate isKindOfClass:[TGChatItem class]]) {
                        continue;
                    }
                    TGChatItem *topicItem = (TGChatItem *)candidate;
                    [topicItem setAvatarLocalPath:parentAvatarPath];
                    [topicItems addObject:topicItem];
                }
                self.suppressChatSelectionHandling = YES;
                [self.chatItems removeAllObjects];
                [self.chatItems addObjectsFromArray:topicItems];
                [self.chatTableView reloadData];
                [self.chatTableView deselectAll:nil];
                self.suppressChatSelectionHandling = NO;
                self.selectedChatID = parentChatID;
                self.selectedChatTitle = parentTitle;
                self.selectedChatTypeSummary = @"Forum";
                self.selectedChatAvatarLocalPath = parentAvatarPath;
                self.selectedChatLastReadOutboxMessageID = nil;
                self.selectedMessageThreadID = nil;
                self.selectedMessageTopicKind = nil;
                [self refreshSelectedChatHeaderDisplay];
                [self.messageItems removeAllObjects];
                [self.messageTableView reloadData];
                NSString *topicListTitle = ([parentTitle length] > 0 ? parentTitle : @"Topics");
                [self.chatsLabel setStringValue:[NSString stringWithFormat:@"%@ (%lu)", topicListTitle, (unsigned long)[topicItems count]]];
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: loaded %lu topics.", (unsigned long)[topicItems count]]];
            } else if (stillCurrent && [topicErrorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: %@", topicErrorMessage]];
            }
            if (interactive) {
                [self setControlsBusy:NO];
            }
            [topics release];
            [topicErrorMessage release];
            [parentChatID release];
            [parentTitle release];
            [parentAvatarPath release];
            [client release];
        });

        [pool drain];
    });
}

- (void)loadForumTopicsForChatItem:(TGChatItem *)chatItem {
    if (!chatItem || [chatItem isForumTopic] || self.forumTopicRefreshInFlight) {
        return;
    }
    id chatID = [chatItem chatID];
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }
    if (![[chatItem typeSummary] isEqualToString:@"Supergroup"]) {
        return;
    }

    self.forumTopicRefreshInFlight = YES;
    NSNumber *chatIDCopy = [[NSNumber numberWithLongLong:[chatID longLongValue]] retain];
    TGChatItem *chatItemCopy = [chatItem retain];
    NSString *parentTitle = [[chatItem title] copy];
    NSString *parentAvatarPath = [[chatItem avatarLocalPath] copy];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *topicError = nil;
        NSArray *topics = [[client threadPreviewItemsForChatID:chatIDCopy limit:24 timeout:6.0 error:&topicError] retain];
        NSString *topicErrorMessage = [[topicError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.forumTopicRefreshInFlight = NO;
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && self.selectedMessageThreadID == nil);
            if (selectionStillCurrent && [topics count] > 0) {
                [self showForumTopicListForChatItem:chatItemCopy topics:topics];
                [self appendDetail:[NSString stringWithFormat:@"Forum topics: found %lu topics in %@", (unsigned long)[topics count], parentTitle ? parentTitle : @"selected chat"]];
            } else if (selectionStillCurrent) {
                if ([topicErrorMessage length] > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"Forum topics: %@", topicErrorMessage]];
                }
                [self reloadMessagesForChatID:chatIDCopy interactive:NO];
            }
            [topics release];
            [topicErrorMessage release];
            [chatIDCopy release];
            [chatItemCopy release];
            [parentTitle release];
            [parentAvatarPath release];
            [client release];
        });

        [pool drain];
    });
}

- (NSNumber *)oldestLoadedMessageID {
    long long minimumMessageID = 0;
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:(NSUInteger)index];
        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            long long value = [messageID longLongValue];
            if (minimumMessageID == 0 || value < minimumMessageID) {
                minimumMessageID = value;
            }
        }
    }
    if (minimumMessageID > 0) {
        return [NSNumber numberWithLongLong:minimumMessageID];
    }
    return nil;
}

- (NSArray *)messageItemsInDisplayOrderFromItems:(NSArray *)items {
    return [items sortedArrayUsingFunction:TGCompareMessageItemsAscending context:NULL];
}

- (NSString *)deduplicationKeyForMessageItem:(TGMessageItem *)item {
    if (![item isKindOfClass:[TGMessageItem class]]) {
        return nil;
    }

    id chatID = [item chatID];
    id date = [item date];
    NSString *preview = [item preview] ? [item preview] : @"";
    long long chatValue = [chatID respondsToSelector:@selector(longLongValue)] ? [chatID longLongValue] : 0;
    long long dateValue = [date respondsToSelector:@selector(longLongValue)] ? [date longLongValue] : 0;

    return [NSString stringWithFormat:@"%lld|%lld|%d|%@", chatValue, dateValue, [item outgoing] ? 1 : 0, preview];
}

- (BOOL)messageItem:(TGMessageItem *)left isLikelyLocalDuplicateOfMessageItem:(TGMessageItem *)right {
    if (![left isKindOfClass:[TGMessageItem class]] || ![right isKindOfClass:[TGMessageItem class]]) {
        return NO;
    }
    if (![left outgoing] || ![right outgoing]) {
        return NO;
    }
    id leftChatID = [left chatID];
    id rightChatID = [right chatID];
    if (![leftChatID respondsToSelector:@selector(longLongValue)] ||
        ![rightChatID respondsToSelector:@selector(longLongValue)] ||
        [leftChatID longLongValue] != [rightChatID longLongValue]) {
        return NO;
    }
    NSString *leftPreview = [left preview] ? [left preview] : @"";
    NSString *rightPreview = [right preview] ? [right preview] : @"";
    NSString *leftContentType = [left contentType] ? [left contentType] : @"";
    NSString *rightContentType = [right contentType] ? [right contentType] : @"";
    if (![leftContentType isEqualToString:rightContentType]) {
        return NO;
    }
    BOOL leftHasID = ([[left messageID] respondsToSelector:@selector(longLongValue)] && [[left messageID] longLongValue] > 0);
    BOOL rightHasID = ([[right messageID] respondsToSelector:@selector(longLongValue)] && [[right messageID] longLongValue] > 0);
    long long leftDate = [[left date] respondsToSelector:@selector(longLongValue)] ? [[left date] longLongValue] : 0;
    long long rightDate = [[right date] respondsToSelector:@selector(longLongValue)] ? [[right date] longLongValue] : 0;
    long long delta = leftDate - rightDate;
    if (delta < 0) {
        delta = -delta;
    }
    if ([left isVisualMediaMessage] || [right isVisualMediaMessage]) {
        BOOL stickerLike = [leftContentType isEqualToString:@"messageSticker"];
        NSString *leftMediaPath = [left mediaLocalPath] ? [left mediaLocalPath] : @"";
        NSString *rightMediaPath = [right mediaLocalPath] ? [right mediaLocalPath] : @"";
        if ([leftMediaPath length] == 0) {
            NSArray *leftMediaItems = [left visualMediaItems];
            if ([leftMediaItems count] > 0 && [[leftMediaItems objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
                id candidatePath = [(NSDictionary *)[leftMediaItems objectAtIndex:0] objectForKey:@"local_path"];
                if ([candidatePath isKindOfClass:[NSString class]]) {
                    leftMediaPath = (NSString *)candidatePath;
                }
            }
        }
        if ([rightMediaPath length] == 0) {
            NSArray *rightMediaItems = [right visualMediaItems];
            if ([rightMediaItems count] > 0 && [[rightMediaItems objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
                id candidatePath = [(NSDictionary *)[rightMediaItems objectAtIndex:0] objectForKey:@"local_path"];
                if ([candidatePath isKindOfClass:[NSString class]]) {
                    rightMediaPath = (NSString *)candidatePath;
                }
            }
        }
        if (leftHasID && rightHasID) {
            return ([[left messageID] longLongValue] == [[right messageID] longLongValue]);
        }
        if ([leftMediaPath length] > 0 && [rightMediaPath length] > 0 && ![leftMediaPath isEqualToString:rightMediaPath]) {
            return NO;
        }
        if ([leftMediaPath length] == 0 || [rightMediaPath length] == 0) {
            if (stickerLike && [leftPreview isEqualToString:rightPreview] && ([left sending] || [right sending] || !leftHasID || !rightHasID)) {
                return (delta <= 300);
            }
            return NO;
        }
    }
    if (![leftPreview isEqualToString:rightPreview]) {
        return NO;
    }
    if ([left sending] || [right sending]) {
        return (delta <= 300);
    }
    return (delta <= 30);
}

- (TGMessageItem *)preferredMessageItemForDuplicateLeft:(TGMessageItem *)left right:(TGMessageItem *)right {
    if ([left sending] && ![right sending]) {
        return right;
    }
    if (![left sending] && [right sending]) {
        return left;
    }
    id leftID = [left messageID];
    id rightID = [right messageID];
    BOOL leftHasID = ([leftID respondsToSelector:@selector(longLongValue)] && [leftID longLongValue] > 0);
    BOOL rightHasID = ([rightID respondsToSelector:@selector(longLongValue)] && [rightID longLongValue] > 0);
    if (rightHasID && !leftHasID) {
        return right;
    }
    if (leftHasID && !rightHasID) {
        return left;
    }
    long long leftIDValue = leftHasID ? [leftID longLongValue] : 0;
    long long rightIDValue = rightHasID ? [rightID longLongValue] : 0;
    if (rightIDValue > leftIDValue) {
        return right;
    }
    return left;
}

- (NSArray *)deduplicatedMessageItemsFromItems:(NSArray *)items {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSUInteger index = 0;

    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        if (![item isKindOfClass:[TGMessageItem class]]) {
            continue;
        }

        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            NSString *messageKey = [NSString stringWithFormat:@"id:%lld", [messageID longLongValue]];
            if ([messageIDs containsObject:messageKey]) {
                continue;
            }
            [messageIDs addObject:messageKey];
        }

        TGMessageItem *previousItem = [result lastObject];
        if ([item outgoing] && previousItem && [previousItem isKindOfClass:[TGMessageItem class]] && [previousItem outgoing]) {
            if ([self messageItem:item isLikelyLocalDuplicateOfMessageItem:previousItem]) {
                TGMessageItem *preferredItem = [self preferredMessageItemForDuplicateLeft:previousItem right:item];
                [result replaceObjectAtIndex:([result count] - 1) withObject:preferredItem];
                continue;
            }
            if ([item isVisualMediaMessage] || [previousItem isVisualMediaMessage]) {
                [result addObject:item];
                continue;
            }
            NSString *currentFallbackKey = [self deduplicationKeyForMessageItem:item];
            NSString *previousFallbackKey = [self deduplicationKeyForMessageItem:previousItem];
            if ([currentFallbackKey length] > 0 && [currentFallbackKey isEqualToString:previousFallbackKey]) {
                id currentID = [item messageID];
                id previousID = [previousItem messageID];
                BOOL currentHasID = ([currentID respondsToSelector:@selector(longLongValue)] && [currentID longLongValue] > 0);
                BOOL previousHasID = ([previousID respondsToSelector:@selector(longLongValue)] && [previousID longLongValue] > 0);
                if (currentHasID && previousHasID && [currentID longLongValue] != [previousID longLongValue]) {
                    [result addObject:item];
                    continue;
                }
                if (currentHasID && !previousHasID) {
                    [result replaceObjectAtIndex:([result count] - 1) withObject:item];
                }
                continue;
            }
        }

        [result addObject:item];
    }

    return result;
}

- (BOOL)removeDisplayedMessageWithID:(NSNumber *)messageID chatID:(NSNumber *)chatID {
    if (![messageID respondsToSelector:@selector(longLongValue)] || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return NO;
    }
    long long targetMessageID = [messageID longLongValue];
    long long targetChatID = [chatID longLongValue];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:index];
        if (![item isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        id itemMessageID = [item messageID];
        id itemChatID = [item chatID];
        if ([itemMessageID respondsToSelector:@selector(longLongValue)] &&
            [itemChatID respondsToSelector:@selector(longLongValue)] &&
            [itemMessageID longLongValue] == targetMessageID &&
            [itemChatID longLongValue] == targetChatID) {
            [self.messageItems removeObjectAtIndex:index];
            [self.messageTableView reloadData];
            return YES;
        }
    }
    return NO;
}

- (void)scrollMessagesToNewestIfAvailable {
    NSUInteger count = [self.messageItems count];
    if (count > 0) {
        [self.messageTableView scrollRowToVisible:(count - 1)];
    }
}

- (void)applyRecentMessageItems:(NSArray *)items preservingOlderItems:(BOOL)preserveOlder {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    BOOL forceScrollToNewest = self.forceMessageScrollToNewest;
    self.forceMessageScrollToNewest = NO;
    if (!preserveOlder || [self.messageItems count] == 0) {
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:orderedItems]];
        self.olderMessagesExhausted = NO;
        self.autoOlderMessagesLoadArmed = YES;
        [self updateOutgoingReadStateForVisibleMessages];
        [self.messageTableView reloadData];
        [self scrollMessagesToNewestIfAvailable];
        return;
    }

    BOOL shouldScrollToNewest = forceScrollToNewest || [self isMessageHistoryNearBottom];
    NSMutableDictionary *messageIndexesByID = [NSMutableDictionary dictionary];
    NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:self.messageItems];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *item = [self.messageItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID) {
            [messageIndexesByID setObject:[NSNumber numberWithUnsignedInteger:index] forKey:messageID];
        }
    }

    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        NSNumber *existingIndex = messageID ? [messageIndexesByID objectForKey:messageID] : nil;
        if (existingIndex) {
            [mergedItems replaceObjectAtIndex:[existingIndex unsignedIntegerValue] withObject:item];
            continue;
        }
        if (messageID) {
            [messageIndexesByID setObject:[NSNumber numberWithUnsignedInteger:[mergedItems count]] forKey:messageID];
        }
        [mergedItems addObject:item];
    }

    [self.messageItems removeAllObjects];
    [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:mergedItems]];
    [self updateOutgoingReadStateForVisibleMessages];
    [self.messageTableView reloadData];
    if (shouldScrollToNewest) {
        [self scrollMessagesToNewestIfAvailable];
    }
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items preservingVisiblePosition:(BOOL)preserveVisiblePosition {
    NSArray *orderedItems = [self messageItemsInDisplayOrderFromItems:items];
    NSInteger firstVisibleRow = 0;
    if (preserveVisiblePosition) {
        NSPoint visibleOrigin = [[self.messageScrollView contentView] bounds].origin;
        firstVisibleRow = [self.messageTableView rowAtPoint:visibleOrigin];
        if (firstVisibleRow < 0) {
            firstVisibleRow = 0;
        }
    }
    NSMutableSet *messageIDs = [NSMutableSet set];
    NSUInteger index = 0;
    for (index = 0; index < [self.messageItems count]; index++) {
        TGMessageItem *existingItem = [self.messageItems objectAtIndex:index];
        id messageID = [existingItem messageID];
        if (messageID) {
            [messageIDs addObject:messageID];
        }
    }

    NSMutableArray *itemsToPrepend = [NSMutableArray array];
    NSUInteger added = 0;
    for (index = 0; index < [orderedItems count]; index++) {
        TGMessageItem *item = [orderedItems objectAtIndex:index];
        id messageID = [item messageID];
        if (messageID && [messageIDs containsObject:messageID]) {
            continue;
        }
        if (messageID) {
            [messageIDs addObject:messageID];
        }
        [itemsToPrepend addObject:item];
        added++;
    }

    if (added > 0) {
        NSMutableArray *mergedItems = [NSMutableArray arrayWithArray:itemsToPrepend];
        [mergedItems addObjectsFromArray:self.messageItems];
        [self.messageItems removeAllObjects];
        [self.messageItems addObjectsFromArray:[self deduplicatedMessageItemsFromItems:mergedItems]];
    }

    [self updateOutgoingReadStateForVisibleMessages];
    [self.messageTableView reloadData];
    if (added > 0) {
        if (preserveVisiblePosition) {
            NSUInteger targetRow = (NSUInteger)firstVisibleRow + added;
            if (targetRow >= [self.messageItems count]) {
                targetRow = [self.messageItems count] - 1;
            }
            [self.messageTableView scrollRowToVisible:targetRow];
        } else {
            [self scrollMessagesToNewestIfAvailable];
        }
    }
    return added;
}

- (NSUInteger)appendOlderMessageItems:(NSArray *)items {
    return [self appendOlderMessageItems:items preservingVisiblePosition:YES];
}

- (BOOL)isChatListNearBottom {
    if ([self.chatItems count] == 0 || self.chatsExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (BOOL)isChatListScrollable {
    if ([self.chatItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat estimatedRowsHeight = ([self.chatTableView rowHeight] + [self.chatTableView intercellSpacing].height) * (CGFloat)[self.chatItems count];
    CGFloat documentHeight = NSHeight(documentBounds);
    if (estimatedRowsHeight > documentHeight) {
        documentHeight = estimatedRowsHeight;
    }
    return (documentHeight > (NSHeight(visibleRect) + 16.0));
}

- (BOOL)isChatListNearTop {
    if ([self.chatItems count] == 0 || self.showingForumTopicList || ![self isChatListScrollable]) {
        return NO;
    }

    NSClipView *clipView = [self.chatScrollView contentView];
    NSView *documentView = [self.chatScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat distanceFromTop = NSMinY(visibleRect) - NSMinY(documentBounds);
    return (distanceFromTop <= 18.0);
}

- (void)chatScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.chatScrollView contentView]) {
        return;
    }

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        self.controlsBusy ||
        self.backgroundChatRefreshInFlight ||
        [self.chatItems count] == 0) {
        return;
    }

    if ([self isChatListNearTop]) {
        if (self.autoChatListRefreshArmed) {
            self.autoChatListRefreshArmed = NO;
            [self reloadChatsInteractive:NO preserveSelection:YES];
        }
        return;
    }

    self.autoChatListRefreshArmed = YES;

    if (self.chatsExhausted) {
        return;
    }

    if (![self isChatListNearBottom]) {
        self.autoChatListLoadArmed = YES;
        return;
    }

    if (!self.autoChatListLoadArmed) {
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }

    if (nextLimit <= self.chatPreviewLimit) {
        self.autoChatListLoadArmed = NO;
        return;
    }

    self.autoChatListLoadArmed = NO;
    [self reloadChatsInteractive:NO preserveSelection:YES requestedLimit:nextLimit];
}

- (BOOL)isMessageHistoryNearBottom {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat visibleBottom = NSMaxY(visibleRect);
    CGFloat documentBottom = NSMaxY(documentBounds);
    CGFloat distanceFromBottom = documentBottom - visibleBottom;
    return (distanceFromBottom <= 48.0);
}

- (BOOL)isMessageHistoryScrollable {
    if ([self.messageItems count] == 0) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    NSRect documentBounds = [documentView bounds];
    CGFloat estimatedRowsHeight = ([self.messageTableView rowHeight] + [self.messageTableView intercellSpacing].height) * (CGFloat)[self.messageItems count];
    CGFloat documentHeight = NSHeight(documentBounds);
    if (estimatedRowsHeight > documentHeight) {
        documentHeight = estimatedRowsHeight;
    }
    return (documentHeight > (NSHeight(visibleRect) + 16.0));
}

- (BOOL)messageHistoryNeedsPrefill {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }
    return ([self.messageItems count] < TGMessagePrefillMinimumRows || ![self isMessageHistoryScrollable]);
}

- (BOOL)isMessageHistoryNearTop {
    if ([self.messageItems count] == 0 || self.olderMessagesExhausted) {
        return NO;
    }

    NSClipView *clipView = [self.messageScrollView contentView];
    NSView *documentView = [self.messageScrollView documentView];
    if (!clipView || !documentView) {
        return NO;
    }

    NSRect visibleRect = [clipView bounds];
    if (![self isMessageHistoryScrollable]) {
        return NO;
    }

    NSRect documentBounds = [documentView bounds];
    CGFloat distanceFromTop = NSMinY(visibleRect) - NSMinY(documentBounds);
    return (distanceFromTop <= 48.0);
}

- (void)messageScrollViewDidScroll:(NSNotification *)notification {
    if ([notification object] != [self.messageScrollView contentView]) {
        return;
    }

    [self scheduleInlineMediaPlaybackRefresh];

    if (![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        self.olderMessagesExhausted ||
        [self.messageItems count] == 0) {
        return;
    }

    if (![self isMessageHistoryNearTop]) {
        self.autoOlderMessagesLoadArmed = YES;
        return;
    }

    if (!self.autoOlderMessagesLoadArmed) {
        return;
    }

    self.autoOlderMessagesLoadArmed = NO;
    [self reloadOlderMessagesInteractive];
}

- (void)prefillOlderMessagesIfNeededWithAttemptsRemaining:(NSUInteger)attemptsRemaining {
    if (attemptsRemaining == 0 ||
        self.controlsBusy ||
        self.backgroundMessageRefreshInFlight ||
        ![self.currentAuthState isEqualToString:@"ready"] ||
        !self.selectedChatID ||
        ![self messageHistoryNeedsPrefill]) {
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    self.backgroundMessageRefreshInFlight = YES;

      TGTDLibClient *client = [self.client retain];
      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                              messageThreadID:messageThreadIDCopy
                                             messageTopicKind:messageTopicKindCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        BOOL hadMessageError = (messageError != nil);
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
          NSArray *itemsCopy = [items copy];

          dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            NSUInteger added = 0;
            if (selectionStillCurrent && itemsCopy) {
                added = [self appendOlderMessageItems:itemsCopy preservingVisiblePosition:NO];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added > 0) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: prefilled %lu older previews", (unsigned long)added]];
                }
            } else if (selectionStillCurrent && hadMessageError) {
                self.autoOlderMessagesLoadArmed = YES;
            }

            self.backgroundMessageRefreshInFlight = NO;
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            } else {
                [self updateAuthControlsForState:self.currentAuthState];
            }

            if (selectionStillCurrent &&
                added > 0 &&
                attemptsRemaining > 1 &&
                [self messageHistoryNeedsPrefill]) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:(attemptsRemaining - 1)];
            } else {
                [self handlePendingLiveRefreshesIfPossible];
            }

            [itemsCopy release];
            [authorizationState release];
            [messageTopicKindCopy release];
            [messageThreadIDCopy release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection {
    [self reloadChatsInteractive:interactive preserveSelection:preserveSelection requestedLimit:self.chatPreviewLimit];
}

- (NSArray *)readReceiptMessageIDsFromItems:(NSArray *)items {
    if (![items isKindOfClass:[NSArray class]] || [items count] == 0) {
        return [NSArray array];
    }

    NSMutableArray *messageIDs = [NSMutableArray array];
    NSUInteger index = 0;
    for (index = 0; index < [items count]; index++) {
        id candidate = [items objectAtIndex:index];
        if (![candidate isKindOfClass:[TGMessageItem class]]) {
            continue;
        }
        TGMessageItem *item = (TGMessageItem *)candidate;
        if ([item outgoing]) {
            continue;
        }
        id messageID = [item messageID];
        if ([messageID respondsToSelector:@selector(longLongValue)] && [messageID longLongValue] > 0) {
            [messageIDs addObject:[NSNumber numberWithLongLong:[messageID longLongValue]]];
        }
    }
    return messageIDs;
}

- (void)clearUnreadCountForChatID:(NSNumber *)chatID {
    [self clearUnreadCountForChatID:chatID messageThreadID:nil];
}

- (void)clearUnreadCountForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID {
    if (![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    BOOL wantsTopic = ([messageThreadID respondsToSelector:@selector(longLongValue)] && [messageThreadID longLongValue] > 0);
    long long targetChatID = [chatID longLongValue];
    long long targetThreadID = wantsTopic ? [messageThreadID longLongValue] : 0;
    BOOL didClear = NO;
    NSUInteger clearedUnreadCount = 0;
    NSUInteger index = 0;
    for (index = 0; index < [self.chatItems count]; index++) {
        id candidate = [self.chatItems objectAtIndex:index];
        if (![candidate isKindOfClass:[TGChatItem class]]) {
            continue;
        }
        TGChatItem *item = (TGChatItem *)candidate;

        id itemChatID = [item chatID];
        id parentChatID = [item parentChatID];
        long long itemChatValue = [itemChatID respondsToSelector:@selector(longLongValue)] ? [itemChatID longLongValue] : 0;
        long long parentChatValue = [parentChatID respondsToSelector:@selector(longLongValue)] ? [parentChatID longLongValue] : 0;
        BOOL chatMatches = (itemChatValue == targetChatID || parentChatValue == targetChatID);
        if (!chatMatches) {
            continue;
        }

        if (wantsTopic && ![item isForumTopic]) {
            continue;
        }
        if (wantsTopic && [item isForumTopic]) {
            id itemThreadID = [item messageThreadID];
            if (![itemThreadID respondsToSelector:@selector(longLongValue)] || [itemThreadID longLongValue] != targetThreadID) {
                continue;
            }
        }
        if ([[item unreadCount] respondsToSelector:@selector(integerValue)] && [[item unreadCount] integerValue] > 0) {
            clearedUnreadCount += [[item unreadCount] unsignedIntegerValue];
            [item setUnreadCount:[NSNumber numberWithInteger:0]];
            didClear = YES;
        }
    }

    if (didClear) {
        NSString *chatKey = [self chatMuteDefaultsKeyForChatID:chatID];
        NSNumber *cachedUnreadCount = ([chatKey length] > 0) ? [self.localMuteUnreadCountsByChatID objectForKey:chatKey] : nil;
        if (cachedUnreadCount) {
            NSUInteger cachedValue = [cachedUnreadCount unsignedIntegerValue];
            NSUInteger updatedValue = (clearedUnreadCount >= cachedValue) ? 0 : (cachedValue - clearedUnreadCount);
            [self.localMuteUnreadCountsByChatID setObject:[NSNumber numberWithUnsignedInteger:updatedValue] forKey:chatKey];
        }
        [self.chatTableView reloadData];
        [self updateApplicationBadge];
    }
}

- (void)scheduleMessageItemsReadForChatID:(NSNumber *)chatID items:(NSArray *)items {
    if (![chatID respondsToSelector:@selector(longLongValue)] || ![items isKindOfClass:[NSArray class]] || [items count] == 0) {
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    NSArray *itemsCopy = [items copy];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.85 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                           (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
        BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                              (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
        BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
        BOOL messagePaneVisible = ([self.messageScrollView window] != nil && ![self.messageScrollView isHidden]);
        if (selectionStillCurrent && messagePaneVisible && [self.currentAuthState isEqualToString:@"ready"]) {
            [self clearUnreadCountForChatID:chatIDCopy messageThreadID:messageThreadIDCopy];
            [self markMessageItemsReadForChatID:chatIDCopy messageThreadID:messageThreadIDCopy messageTopicKind:messageTopicKindCopy items:itemsCopy];
        }
        [chatIDCopy release];
        [messageThreadIDCopy release];
        [messageTopicKindCopy release];
        [itemsCopy release];
    });
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID items:(NSArray *)items {
    [self markMessageItemsReadForChatID:chatID messageThreadID:nil items:items];
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID items:(NSArray *)items {
    [self markMessageItemsReadForChatID:chatID messageThreadID:messageThreadID messageTopicKind:nil items:items];
}

- (void)markMessageItemsReadForChatID:(NSNumber *)chatID messageThreadID:(NSNumber *)messageThreadID messageTopicKind:(NSString *)messageTopicKind items:(NSArray *)items {
    if (![self.currentAuthState isEqualToString:@"ready"] || ![chatID respondsToSelector:@selector(longLongValue)]) {
        return;
    }

    NSArray *messageIDs = [self readReceiptMessageIDsFromItems:items];
    if ([messageIDs count] == 0) {
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [messageThreadID retain];
    NSString *messageTopicKindCopy = [messageTopicKind copy];
    NSArray *messageIDsCopy = [messageIDs copy];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *readError = nil;
        BOOL success = [client markMessagesAsReadForChatID:chatIDCopy
                                           messageThreadID:messageThreadIDCopy
                                          messageTopicKind:messageTopicKindCopy
                                                messageIDs:messageIDsCopy
                                                   timeout:4.0
                                                     error:&readError];
        NSString *readErrorMessage = [[readError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                [self clearUnreadCountForChatID:chatIDCopy messageThreadID:messageThreadIDCopy];
                [self appendDetail:@"TDLib read state: selected chat messages marked as read."];
            } else if ([readErrorMessage length] > 0) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib read state: %@", readErrorMessage]];
            }
            [readErrorMessage release];
            [chatIDCopy release];
            [messageThreadIDCopy release];
            [messageTopicKindCopy release];
            [messageIDsCopy release];
            [client release];
        });

        [pool drain];
    });
}

- (void)reloadProfileSummaryIfReady {
    if (![self.currentAuthState isEqualToString:@"ready"] || self.controlsBusy || self.profileSummaryLoading) {
        return;
    }

    self.profileSummaryLoading = YES;
    [self.profileRefreshButton setEnabled:NO];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *profileError = nil;
        NSDictionary *profile = [[client currentUserProfileSummaryWithTimeout:6.0 error:&profileError] retain];
        NSString *profileErrorMessage = [[profileError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client != client || ![self.currentAuthState isEqualToString:@"ready"]) {
                self.profileSummaryLoading = NO;
                [self.profileRefreshButton setEnabled:YES];
                [profile release];
                [profileErrorMessage release];
                return;
            }

            if (profile) {
                NSString *displayName = [profile objectForKey:@"display_name"];
                NSString *firstName = [profile objectForKey:@"first_name"];
                NSString *lastName = [profile objectForKey:@"last_name"];
                NSString *username = [profile objectForKey:@"username"];
                NSString *phoneNumber = [profile objectForKey:@"phone_number"];
                NSString *bio = [profile objectForKey:@"bio"];
                id userID = [profile objectForKey:@"id"];
                if ([userID respondsToSelector:@selector(longLongValue)]) {
                    self.profileUserID = [NSNumber numberWithLongLong:[userID longLongValue]];
                } else {
                    self.profileUserID = nil;
                }
                self.profileDisplayName = ([displayName length] > 0) ? displayName : nil;
                self.profileFirstName = ([firstName length] > 0) ? firstName : nil;
                self.profileLastName = ([lastName length] > 0) ? lastName : nil;
                self.profileUsername = ([username length] > 0) ? username : nil;
                self.profilePhoneNumber = ([phoneNumber length] > 0) ? phoneNumber : nil;
                self.profileAvatarLocalPath = [profile objectForKey:@"avatar_path"];
                self.profileBio = ([bio length] > 0) ? bio : nil;
                [self refreshProfileDisplay];
                [self layoutContentView];
                [self updateVisibleSection];
                self.profileSummaryLoaded = YES;
            } else {
                self.profileFirstName = nil;
                self.profileLastName = nil;
                self.profilePhoneNumber = nil;
                self.profileBio = nil;
                [self.profileStateField setStringValue:@""];
                [self refreshProfileDisplay];
                [self layoutContentView];
                [self updateVisibleSection];
                self.profileSummaryLoaded = NO;
                if (profileErrorMessage) {
                    [self appendDetail:[NSString stringWithFormat:@"Profile: %@", profileErrorMessage]];
                }
            }
            self.profileSummaryLoading = NO;
            [self.profileRefreshButton setEnabled:YES];
            [profile release];
            [profileErrorMessage release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadChatsInteractive:(BOOL)interactive preserveSelection:(BOOL)preserveSelection requestedLimit:(NSUInteger)requestedLimit {
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        if (interactive) {
            [self appendDetail:@"Chats are available only after sign-in is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundChatRefreshInFlight) {
        self.pendingLiveChatRefresh = YES;
        return;
    }

    NSNumber *preferredChatID = preserveSelection ? [self.selectedChatID retain] : nil;
    NSNumber *activeFilterID = [self.selectedChatFilterID retain];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading chats..."];
        [self appendDetail:activeFilterID ? @"Loading folder chat previews from TDLib..." : @"Loading main chat previews from TDLib..."];
    } else {
        self.backgroundChatRefreshInFlight = YES;
    }

    if (requestedLimit == 0) {
        requestedLimit = TGStatusChatPreviewInitialLimit;
    } else if (requestedLimit > TGStatusChatPreviewMaximumLimit) {
        requestedLimit = TGStatusChatPreviewMaximumLimit;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *chatError = nil;
        BOOL chatsExhausted = NO;
        NSArray *items = nil;
        if (activeFilterID) {
            items = [client chatPreviewItemsForChatFilterID:activeFilterID
                                                      limit:requestedLimit
                                                    timeout:10.0
                                                  exhausted:&chatsExhausted
                                                      error:&chatError];
        } else {
            items = [client mainChatPreviewItemsWithLimit:requestedLimit timeout:10.0 error:&chatError];
            chatsExhausted = [client mainChatListExhausted];
        }
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *chatErrorMessage = [[chatError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL filterStillCurrent = NO;
            if (!activeFilterID && !self.selectedChatFilterID) {
                filterStillCurrent = YES;
            } else if (activeFilterID && self.selectedChatFilterID && [activeFilterID integerValue] == [self.selectedChatFilterID integerValue]) {
                filterStillCurrent = YES;
            }

            if (!filterStillCurrent) {
                if (interactive) {
                    [self appendDetail:@"TDLib chats: ignored stale folder result after selection changed."];
                } else {
                    [self appendDetail:@"TDLib live refresh: ignored stale folder result after selection changed."];
                }
            } else if (itemsCopy) {
                self.chatPreviewLimit = [itemsCopy count];
                self.chatsExhausted = chatsExhausted;
                NSNumber *effectivePreferredChatID = preferredChatID;
                if (preserveSelection &&
                    preferredChatID &&
                    self.selectedChatID &&
                    [self.selectedChatID longLongValue] != [preferredChatID longLongValue]) {
                    effectivePreferredChatID = self.selectedChatID;
                }
                [self applyChatItems:itemsCopy preserveSelection:preserveSelection preferredChatID:effectivePreferredChatID];
                [self setOfflineModeActive:NO reason:nil];
                if (interactive) {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib chats: loaded %lu %@chat previews (limit %lu)", (unsigned long)[itemsCopy count], activeFilterID ? @"folder " : @"", (unsigned long)requestedLimit]];
                    if (self.chatsExhausted) {
                        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
                    }
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib chat previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                BOOL looksOffline = TGStatusErrorLooksOffline(chatErrorMessage);
                if (interactive) {
                    if (looksOffline) {
                        [self setOfflineModeActive:YES reason:@"Network appears unavailable. Keeping the current chat list visible; refresh after the connection returns."];
                    } else {
                        NSString *message = chatErrorMessage ? @"Chat preview request failed. Check connection state and try again." : @"Chat list did not return a result.";
                        [self.statusField setStringValue:@"Chats unavailable"];
                        [self appendDetail:[NSString stringWithFormat:@"TDLib chats: %@", message]];
                    }
                } else {
                    if (looksOffline) {
                        [self setOfflineModeActive:YES reason:@"Network appears unavailable during live chat refresh. Keeping cached chats visible."];
                    } else {
                        [self appendDetail:@"TDLib live refresh: chat preview refresh failed."];
                    }
                }
                [[TGLogger sharedLogger] log:@"TDLib chat preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundChatRefreshInFlight = NO;
                [self handlePendingLiveRefreshesIfPossible];
            }
            [itemsCopy release];
            [chatErrorMessage release];
            [authorizationState release];
            [activeFilterID release];
            [preferredChatID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadMessagesForChatID:(NSNumber *)chatID interactive:(BOOL)interactive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !chatID) {
        if (interactive) {
            [self appendDetail:@"Select a chat after sign-in is ready."];
        }
        return;
    }

    if (!interactive && self.backgroundMessageRefreshInFlight) {
        self.pendingLiveMessageRefresh = YES;
        return;
    }

    NSNumber *chatIDCopy = [chatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    if (interactive) {
        [self setControlsBusy:YES];
        [self.statusField setStringValue:@"Loading messages..."];
        [self appendDetail:(messageThreadIDCopy ? @"Loading recent topic message previews from TDLib..." : @"Loading recent message previews from TDLib...")];
    } else {
        self.backgroundMessageRefreshInFlight = YES;
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client recentMessagePreviewItemsForChatID:chatIDCopy
                                                    messageThreadID:messageThreadIDCopy
                                                   messageTopicKind:messageTopicKindCopy
                                                              limit:TGMessagePreviewInitialLimit
                                                            timeout:8.0
                                                              error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            if (!selectionStillCurrent) {
                if (interactive) {
                    [self appendDetail:@"TDLib messages: ignored stale result for previous chat selection."];
                }
            } else if (itemsCopy) {
                BOOL preserveOlder = (!interactive && [self.messageItems count] > 0);
                [self applyRecentMessageItems:itemsCopy preservingOlderItems:preserveOlder];
                [self scheduleMessageItemsReadForChatID:chatIDCopy items:itemsCopy];
                [self setOfflineModeActive:NO reason:nil];
                if (interactive) {
                    [self.statusField setStringValue:@"Connected"];
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: loaded %lu previews for selected chat", (unsigned long)[itemsCopy count]]];
                    [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib message previews loaded: %lu", (unsigned long)[itemsCopy count]]];
                }
            } else {
                BOOL looksOffline = TGStatusErrorLooksOffline(messageErrorMessage);
                if (interactive) {
                    if (looksOffline) {
                        [self setOfflineModeActive:YES reason:@"Network appears unavailable. Keeping the current messages visible; refresh after the connection returns."];
                    } else {
                        NSString *message = messageErrorMessage ? @"Message preview request failed. Check connection state and try again." : @"Message history did not return a result.";
                        [self.statusField setStringValue:@"Messages unavailable"];
                        [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                    }
                } else {
                    if (looksOffline) {
                        [self setOfflineModeActive:YES reason:@"Network appears unavailable during live message refresh. Keeping cached messages visible."];
                    } else {
                        [self appendDetail:@"TDLib live refresh: selected chat refresh failed."];
                    }
                }
                [[TGLogger sharedLogger] log:@"TDLib message preview load failed."];
            }
            BOOL shouldPrefillOlderMessages = (selectionStillCurrent && itemsCopy && [self messageHistoryNeedsPrefill]);
            if (interactive) {
                [self setControlsBusy:NO];
            } else {
                self.backgroundMessageRefreshInFlight = NO;
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            if (shouldPrefillOlderMessages) {
                [self prefillOlderMessagesIfNeededWithAttemptsRemaining:TGMessagePrefillMaxAttempts];
            } else if (!interactive) {
                [self handlePendingLiveRefreshesIfPossible];
            }
            if (self.composerRefocusPending && selectionStillCurrent) {
                [self consumePendingComposerRefocus:nil];
            }
            [itemsCopy release];
              [messageErrorMessage release];
              [authorizationState release];
              [messageTopicKindCopy release];
              [messageThreadIDCopy release];
              [chatIDCopy release];
        });

        [client release];
        [pool drain];
    });
}

- (void)reloadOlderMessagesInteractive {
    if (![self.currentAuthState isEqualToString:@"ready"] || !self.selectedChatID) {
        [self appendDetail:@"Select a chat after sign-in is ready."];
        return;
    }

    if (self.backgroundMessageRefreshInFlight) {
        [self appendDetail:@"TDLib messages: wait for the current message load to finish."];
        return;
    }

    NSNumber *anchorMessageID = [[self oldestLoadedMessageID] retain];
    if (!anchorMessageID) {
        [self appendDetail:@"TDLib messages: load recent messages before requesting older history."];
        [anchorMessageID release];
        return;
    }

    NSNumber *chatIDCopy = [self.selectedChatID retain];
    NSNumber *messageThreadIDCopy = [self.selectedMessageThreadID retain];
    NSString *messageTopicKindCopy = [self.selectedMessageTopicKind copy];
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Loading older messages..."];
    [self appendDetail:(messageThreadIDCopy ? @"Loading older topic message previews from TDLib..." : @"Loading older message previews from TDLib...")];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *messageError = nil;
        NSArray *items = [client messagePreviewItemsForChatID:chatIDCopy
                                              messageThreadID:messageThreadIDCopy
                                             messageTopicKind:messageTopicKindCopy
                                                fromMessageID:anchorMessageID
                                                        limit:TGMessagePreviewInitialLimit
                                                      timeout:8.0
                                                        error:&messageError];
        NSString *authorizationState = [[client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:NULL] copy];
        NSString *messageErrorMessage = [[messageError localizedDescription] copy];
        NSArray *itemsCopy = [items copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL sameThread = ((!self.selectedMessageThreadID && !messageThreadIDCopy) ||
                               (self.selectedMessageThreadID && messageThreadIDCopy && [self.selectedMessageThreadID longLongValue] == [messageThreadIDCopy longLongValue]));
            BOOL sameTopicKind = ((!self.selectedMessageTopicKind && !messageTopicKindCopy) ||
                                  (self.selectedMessageTopicKind && messageTopicKindCopy && [self.selectedMessageTopicKind isEqualToString:messageTopicKindCopy]));
            BOOL selectionStillCurrent = (self.selectedChatID && [self.selectedChatID longLongValue] == [chatIDCopy longLongValue] && sameThread && sameTopicKind);
            if (!selectionStillCurrent) {
                [self appendDetail:@"TDLib messages: ignored stale older-history result for previous chat selection."];
            } else if (itemsCopy) {
                NSUInteger added = [self appendOlderMessageItems:itemsCopy];
                if (added == 0) {
                    self.olderMessagesExhausted = YES;
                }
                if (added == 0) {
                    self.autoOlderMessagesLoadArmed = NO;
                }
                [self.statusField setStringValue:(added > 0) ? @"Connected" : @"No older messages"];
                [self setOfflineModeActive:NO reason:nil];
                [self appendDetail:[NSString stringWithFormat:@"TDLib messages: appended %lu older previews", (unsigned long)added]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib older message previews appended: %lu", (unsigned long)added]];
            } else {
                if (TGStatusErrorLooksOffline(messageErrorMessage)) {
                    [self setOfflineModeActive:YES reason:@"Network appears unavailable. Older history will stay deferred until the connection returns."];
                } else {
                    [self.statusField setStringValue:@"Older messages unavailable"];
                    NSString *message = messageErrorMessage ? messageErrorMessage : @"Older message history did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib messages: %@", message]];
                }
                [[TGLogger sharedLogger] log:@"TDLib older message preview load failed."];
            }
            if ([authorizationState length] > 0) {
                [self updateAuthControlsForState:authorizationState];
            }
            [self setControlsBusy:NO];
            [self handlePendingLiveRefreshesIfPossible];
            [itemsCopy release];
            [messageErrorMessage release];
            [authorizationState release];
            [messageTopicKindCopy release];
            [messageThreadIDCopy release];
            [chatIDCopy release];
            [anchorMessageID release];
        });

        [client release];
        [pool drain];
    });
}

- (void)handlePendingLiveRefreshesIfPossible {
    if (self.controlsBusy || ![self.currentAuthState isEqualToString:@"ready"]) {
        return;
    }

    BOOL hasMessageTarget = (self.selectedChatID != nil && (!self.showingForumTopicList || self.selectedMessageThreadID != nil));
    if (self.pendingLiveMessageRefresh && !self.backgroundChatRefreshInFlight && !self.backgroundMessageRefreshInFlight && hasMessageTarget) {
        NSNumber *chatID = [self.selectedChatID retain];
        self.pendingLiveMessageRefresh = NO;
        [self reloadMessagesForChatID:chatID interactive:NO];
        [chatID release];
        return;
    }

    if (self.pendingLiveChatRefresh && !self.backgroundChatRefreshInFlight && !self.backgroundMessageRefreshInFlight && !self.showingForumTopicList) {
        self.pendingLiveChatRefresh = NO;
        [self reloadChatsInteractive:NO preserveSelection:YES];
    }
}

- (void)pollLiveUpdates:(NSTimer *)timer {
    (void)timer;
    if (!self.client) {
        return;
    }

    NSArray *updates = [self.client drainSafeUpdateSummaries];
    if ([updates count] == 0) {
        return;
    }

    NSNumber *selectedChatID = [self.selectedChatID retain];
    NSString *latestAuthorizationState = nil;
    BOOL needsChatRefresh = NO;
    BOOL needsMessageRefresh = NO;
    BOOL needsChatFilterRefresh = NO;

    NSUInteger index = 0;
    for (index = 0; index < [updates count]; index++) {
        NSDictionary *summary = [updates objectAtIndex:index];
        if (![summary isKindOfClass:[NSDictionary class]]) {
            continue;
        }

        NSString *kind = [summary objectForKey:@"kind"];
        if ([kind isEqualToString:@"authorization"]) {
            NSString *state = [summary objectForKey:@"state"];
            if ([state length] > 0) {
                latestAuthorizationState = state;
            }
            continue;
        }

        if ([kind isEqualToString:@"new_message"] || [kind isEqualToString:@"chat_update"] || [kind isEqualToString:@"message_update"]) {
            needsChatRefresh = YES;
            self.chatsExhausted = NO;
            [self.client invalidateMainChatListExhaustion];
            if ([kind isEqualToString:@"new_message"]) {
                id direction = [summary objectForKey:@"direction"];
                id incomingChatID = [summary objectForKey:@"chat_id"];
                NSString *incomingChatKey = [self chatMuteDefaultsKeyForChatID:incomingChatID];
                NSNumber *knownLocalUnreadCount = ([incomingChatKey length] > 0) ? [self.localMuteUnreadCountsByChatID objectForKey:incomingChatKey] : nil;
                if ([direction isEqualToString:@"Incoming"] && knownLocalUnreadCount) {
                    NSUInteger updatedLocalUnreadCount = [knownLocalUnreadCount unsignedIntegerValue] + 1;
                    [self.localMuteUnreadCountsByChatID setObject:[NSNumber numberWithUnsignedInteger:updatedLocalUnreadCount] forKey:incomingChatKey];
                    [self updateApplicationBadge];
                }
                [self presentNotificationForUpdateSummary:summary];
            }
            id chatID = [summary objectForKey:@"chat_id"];
            id oldMessageID = [summary objectForKey:@"old_message_id"];
            if ([kind isEqualToString:@"message_update"] &&
                [oldMessageID respondsToSelector:@selector(longLongValue)] &&
                [chatID respondsToSelector:@selector(longLongValue)]) {
                [self removeDisplayedMessageWithID:oldMessageID chatID:chatID];
            }
            if (selectedChatID && [chatID respondsToSelector:@selector(longLongValue)] && [chatID longLongValue] == [selectedChatID longLongValue]) {
                needsMessageRefresh = YES;
            }
        } else if ([kind isEqualToString:@"chat_action"]) {
            [self handleTypingUpdateSummary:summary];
        } else if ([kind isEqualToString:@"account_unread"]) {
            id unreadCount = [summary objectForKey:@"count"];
            if ([unreadCount respondsToSelector:@selector(unsignedIntegerValue)]) {
                self.accountUnreadCount = [unreadCount unsignedIntegerValue];
                self.hasAccountUnreadCount = YES;
                [self updateApplicationBadge];
            }
        } else if ([kind isEqualToString:@"chat_filters"]) {
            needsChatFilterRefresh = YES;
        }
    }

    if ([latestAuthorizationState length] > 0 && ![latestAuthorizationState isEqualToString:self.currentAuthState]) {
        [self updateAuthControlsForState:latestAuthorizationState];
        if ([self isTerminalAuthorizationState:latestAuthorizationState]) {
            [self recoverTDLibClientAfterAuthorizationState:latestAuthorizationState expectedClient:self.client];
        } else {
            self.authClientRecoveryAttemptCount = 0;
        }
    }

    if (needsChatRefresh) {
        self.pendingLiveChatRefresh = YES;
    }
    if (needsMessageRefresh) {
        self.pendingLiveMessageRefresh = YES;
    }
    if (needsChatFilterRefresh) {
        [self reloadChatFiltersIfReady];
    }

    [selectedChatID release];
    [self handlePendingLiveRefreshesIfPossible];
}

- (void)connectOnLaunch:(id)sender {
    (void)sender;
    if (self.initialConnectStarted) {
        return;
    }
    self.initialConnectStarted = YES;
    [self checkTDLib:nil];
}

- (void)checkTDLib:(id)sender {
    (void)sender;
    if (self.controlsBusy) {
        return;
    }
    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Connecting..."];
    [self appendDetail:@"Connecting to Telegram core..."];
    TGTDLibClient *client = [self.client retain];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *probeError = nil;
        NSError *authorizationError = nil;
        NSError *parametersError = nil;
        NSError *encryptionKeyError = nil;
        NSError *finalAuthorizationError = nil;
        NSError *postLoginProbeError = nil;
        NSString *probeSummary = [client tdlibProbeSummaryWithError:&probeError];
        NSString *authorizationState = nil;
        NSString *parametersSummary = nil;
        NSString *encryptionKeySummary = nil;
        NSString *finalAuthorizationState = nil;
        NSString *postLoginProbeSummary = nil;
        if (probeSummary) {
            authorizationState = [client authorizationStateSummaryWithTimeout:2.0 error:&authorizationError];
            if ([authorizationState isEqualToString:@"closed"]) {
                authorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&authorizationError];
            }
            if ([authorizationState isEqualToString:@"waitTdlibParameters"]) {
                parametersSummary = [client setLocalTDLibParametersWithTimeout:4.0 error:&parametersError];
            }
            NSInteger parametersErrorCode = [parametersError code];
            BOOL missingInternalConfiguration = parametersError &&
                (parametersErrorCode == 12 || parametersErrorCode == 13 || parametersErrorCode == 14);
            if ([authorizationState isEqualToString:@"waitTdlibParameters"] && missingInternalConfiguration) {
                finalAuthorizationState = @"waitApiCredentials";
            }
            if ([authorizationState isEqualToString:@"waitEncryptionKey"] || [parametersSummary length] > 0) {
                encryptionKeySummary = [client checkDatabaseEncryptionKeyWithTimeout:4.0 error:&encryptionKeyError];
            }
            if (![finalAuthorizationState isEqualToString:@"waitApiCredentials"]) {
                finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&finalAuthorizationError];
            }
            if ([finalAuthorizationState isEqualToString:@"ready"]) {
                postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
                if (!postLoginProbeSummary) {
                    finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&finalAuthorizationError];
                }
            }
            if (![finalAuthorizationState length]) {
                NSError *fallbackAuthorizationError = nil;
                NSString *fallbackAuthorizationState = [client authorizationStateSummaryWithTimeout:4.0 error:&fallbackAuthorizationError];
                if ([fallbackAuthorizationState length] > 0) {
                    finalAuthorizationState = fallbackAuthorizationState;
                } else if (!finalAuthorizationError && fallbackAuthorizationError) {
                    finalAuthorizationError = fallbackAuthorizationError;
                }
            }
            if (![finalAuthorizationState length] && [authorizationState length] > 0) {
                finalAuthorizationState = authorizationState;
            }
        }
        NSString *loadedPath = [client loadedLibraryPath];
        NSString *receiverSummary = [[client receiverStatusSummary] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.client != client) {
                return;
            }
            if (probeSummary) {
                [self.statusField setStringValue:[finalAuthorizationState isEqualToString:@"ready"] ? @"Connected" : @"Login required"];
                [self appendDetail:[NSString stringWithFormat:@"Loaded: %@", loadedPath ? loadedPath : @"unknown path"]];
                [self appendDetail:[NSString stringWithFormat:@"TDLib probe: %@", probeSummary]];
                if (receiverSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib receiver: %@", receiverSummary]];
                }
                if (authorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", authorizationState]];
                } else {
                    NSString *message = [authorizationError localizedDescription] ? [authorizationError localizedDescription] : @"Authorization state probe did not return a result.";
                    [self appendDetail:[NSString stringWithFormat:@"TDLib auth state: %@", message]];
                }
                if (parametersSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", parametersSummary]];
                } else if (parametersError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib parameters: %@", [parametersError localizedDescription]]];
                }
                if (encryptionKeySummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", encryptionKeySummary]];
                } else if (encryptionKeyError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib encryption key: %@", [encryptionKeyError localizedDescription]]];
                }
                if (finalAuthorizationState) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                } else if (finalAuthorizationError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [finalAuthorizationError localizedDescription]]];
                }
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
                if ([finalAuthorizationState isEqualToString:@"waitApiCredentials"]) {
                    [self setLoginErrorWithLocalizationKey:@"login.config.missing"];
                    [self updateVisibleSection];
                }
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe succeeded: %@", probeSummary]];
                [self setControlsBusy:NO];
                if ([self isTerminalAuthorizationState:finalAuthorizationState]) {
                    [self recoverTDLibClientAfterAuthorizationState:finalAuthorizationState expectedClient:client];
                } else {
                    self.authClientRecoveryAttemptCount = 0;
                }
            } else {
                NSString *message = [probeError localizedDescription] ? [probeError localizedDescription] : @"Unknown TDLib error.";
                [self setControlsBusy:NO];
                [self.statusField setStringValue:@"Connection unavailable"];
                [self setLoginErrorWithLocalizationKey:@"login.connection.unavailable"];
                [self updateVisibleSection];
                [self appendDetail:message];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib probe failed: %@", message]];
            }
        });

        [client release];
        [receiverSummary release];
        [pool drain];
    });
}

- (void)submitAuthInput:(id)sender {
    (void)sender;
    if ([self isTerminalAuthorizationState:self.currentAuthState]) {
        if (!self.authClientRecoveryInFlight) {
            self.authClientRecoveryAttemptCount = 0;
            [self recoverTDLibClientAfterAuthorizationState:self.currentAuthState expectedClient:self.client];
        }
        return;
    }
    if (self.controlsBusy || self.authSubmissionInFlight) {
        return;
    }
    NSString *state = [self.currentAuthState copy];
    if (![self isAuthInputState:state]) {
        [state release];
        [self appendDetail:@"Login input is not available for the current connection state."];
        return;
    }

    NSTextField *inputField = [state isEqualToString:@"waitPassword"] ? (NSTextField *)self.authSecureField : self.authTextField;
    NSString *input = [[inputField stringValue] copy];
    if ([input length] == 0) {
        NSString *emptyErrorKey = @"login.empty.password";
        if ([state isEqualToString:@"waitPhoneNumber"]) {
            emptyErrorKey = @"login.empty.phone";
        } else if ([state isEqualToString:@"waitCode"]) {
            emptyErrorKey = @"login.empty.code";
        }
        [self setLoginErrorWithLocalizationKey:emptyErrorKey];
        [self updateVisibleSection];
        [input release];
        [state release];
        [self appendDetail:@"Login input is empty."];
        return;
    }

    [self setLoginErrorMessage:nil];
    [self updateVisibleSection];
    self.authSubmissionInFlight = YES;
    [self setControlsBusy:YES];
    [self.authButton setTitle:TGLoc(@"login.sending")];
    [self.statusField setStringValue:@"Signing in..."];
    if ([state isEqualToString:@"waitPhoneNumber"]) {
        [self appendDetail:@"Submitting phone number to TDLib..."];
    } else if ([state isEqualToString:@"waitCode"]) {
        [self appendDetail:@"Submitting authentication code to TDLib..."];
    } else {
        [self appendDetail:@"Submitting authentication password to TDLib..."];
    }

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *authError = nil;
        NSError *stateError = nil;
        NSError *postLoginProbeError = nil;
        NSString *authSummary = nil;
        NSString *postLoginProbeSummary = nil;
        if ([state isEqualToString:@"waitPhoneNumber"]) {
            authSummary = [client submitAuthenticationPhoneNumber:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitCode"]) {
            authSummary = [client submitAuthenticationCode:input timeout:8.0 error:&authError];
        } else if ([state isEqualToString:@"waitPassword"]) {
            authSummary = [client submitAuthenticationPassword:input timeout:8.0 error:&authError];
        }
        NSString *finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:2.0 error:&stateError];
        if ([finalAuthorizationState isEqualToString:@"ready"]) {
            postLoginProbeSummary = [client postLoginProbeSummaryWithTimeout:6.0 error:&postLoginProbeError];
            if (!postLoginProbeSummary) {
                finalAuthorizationState = [client currentAuthorizationStatePreparingIfNeededWithTimeout:4.0 error:&stateError];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.authSubmissionInFlight = NO;
            if (!authSummary && [state isEqualToString:@"waitCode"]) {
                [self.authTextField setStringValue:@""];
            } else if (!authSummary && [state isEqualToString:@"waitPassword"]) {
                [self.authSecureField setStringValue:@""];
            }
            if (authSummary) {
                [self.statusField setStringValue:@"Sign-in step submitted"];
                [self setLoginErrorMessage:nil];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", authSummary]];
            } else {
                NSString *message = [authError localizedDescription] ? [authError localizedDescription] : @"Authentication submit did not return a result.";
                [self.statusField setStringValue:@"Sign-in needs attention"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib auth submit: %@", message]];
            }
            if (finalAuthorizationState) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", finalAuthorizationState]];
                if (postLoginProbeSummary) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", postLoginProbeSummary]];
                } else if (postLoginProbeError) {
                    [self appendDetail:[NSString stringWithFormat:@"TDLib post-login probe: %@", [postLoginProbeError localizedDescription]]];
                }
                [self updateAuthControlsForState:finalAuthorizationState];
                if (!authSummary) {
                    [self setLoginErrorWithLocalizationKey:[self loginErrorLocalizationKeyForAuthState:finalAuthorizationState]];
                }
            } else if (stateError) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib current auth state: %@", [stateError localizedDescription]]];
                [self updateAuthControlsForState:state];
                if (!authSummary) {
                    [self setLoginErrorWithLocalizationKey:[self loginErrorLocalizationKeyForAuthState:state]];
                }
            } else {
                [self updateAuthControlsForState:state];
                if (!authSummary) {
                    [self setLoginErrorWithLocalizationKey:[self loginErrorLocalizationKeyForAuthState:state]];
                }
            }
            [self updateVisibleSection];
            [self setControlsBusy:NO];
        });

        [client release];
        [input release];
        [state release];
        [pool drain];
    });
}

- (void)loadChats:(id)sender {
    (void)sender;
    if (self.showingForumTopicList) {
        [self reloadCurrentForumTopicListInteractive:YES];
        return;
    }
    self.autoChatListLoadArmed = YES;
    self.autoChatListRefreshArmed = YES;
    [self reloadChatsInteractive:YES preserveSelection:YES];
}

- (void)loadMoreChats:(id)sender {
    (void)sender;
    self.autoChatListLoadArmed = YES;
    if (self.chatsExhausted) {
        [self appendDetail:@"TDLib chats: all currently available chat previews are loaded."];
        return;
    }

    NSUInteger currentCount = [self.chatItems count];
    NSUInteger nextLimit = currentCount + TGStatusChatPreviewStep;
    if (nextLimit > TGStatusChatPreviewMaximumLimit) {
        nextLimit = TGStatusChatPreviewMaximumLimit;
    }
    if (nextLimit == self.chatPreviewLimit) {
        [self appendDetail:@"TDLib chats: maximum preview limit reached for this build."];
        return;
    }
    [self reloadChatsInteractive:YES preserveSelection:YES requestedLimit:nextLimit];
}

- (void)loadMessages:(id)sender {
    (void)sender;
    self.olderMessagesExhausted = NO;
    self.autoOlderMessagesLoadArmed = YES;
    [self reloadMessagesForChatID:self.selectedChatID interactive:YES];
}

- (void)loadOlderMessages:(id)sender {
    (void)sender;
    [self reloadOlderMessagesInteractive];
}

#include "TGStatusWindowController+ComposerMedia.inc"

- (void)logout:(id)sender {
    (void)sender;
    if (![self.currentAuthState isEqualToString:@"ready"]) {
        [self appendDetail:@"Logout is available only after sign-in is ready."];
        return;
    }

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"Log out of Telegram?"];
    [alert setInformativeText:@"Telegraphica will close the current local TDLib session. You will need to sign in again on this Mac."];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Logout"];
    NSInteger result = [alert runModal];
    if (result != NSAlertSecondButtonReturn) {
        return;
    }

    [self setControlsBusy:YES];
    [self.statusField setStringValue:@"Logging out..."];
    [self appendDetail:@"Submitting Telegram logout to TDLib..."];

    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *logoutError = nil;
        NSString *logoutSummary = [[client logOutWithTimeout:8.0 error:&logoutError] copy];
        NSString *logoutErrorMessage = [[logoutError localizedDescription] copy];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (logoutSummary) {
                [self appendDetail:[NSString stringWithFormat:@"TDLib logout: %@", logoutSummary]];
                [[TGLogger sharedLogger] log:@"TDLib logout accepted."];
                self.client = [[[TGTDLibClient alloc] init] autorelease];
                self.initialConnectStarted = NO;
                self.authClientRecoveryInFlight = NO;
                self.authClientRecoveryAttemptCount = 0;
                self.profileSummaryLoaded = NO;
                self.pendingLiveChatRefresh = NO;
                self.pendingLiveMessageRefresh = NO;
                [self.chatItems removeAllObjects];
                [self.messageItems removeAllObjects];
                [self.chatTableView deselectAll:nil];
                [self.chatTableView reloadData];
                [self.messageTableView reloadData];
                self.selectedChatID = nil;
                self.selectedChatTitle = nil;
                self.selectedChatTypeSummary = nil;
                self.selectedChatAvatarLocalPath = nil;
                self.selectedChatLastReadOutboxMessageID = nil;
                self.selectedMessageThreadID = nil;
                self.selectedMessageTopicKind = nil;
                self.chatsExhausted = NO;
                self.olderMessagesExhausted = NO;
                self.autoChatListLoadArmed = YES;
                self.autoChatListRefreshArmed = YES;
                self.autoOlderMessagesLoadArmed = YES;
                [self refreshSelectedChatHeaderDisplay];
                [self.composerDraftsByTargetKey removeAllObjects];
                [self setComposerTextWithoutSavingDraft:nil];
                [self updateApplicationBadge];
                [self updateAuthControlsForState:@"closed"];
                [self setControlsBusy:NO];
                [self checkTDLib:nil];
            } else {
                NSString *message = logoutErrorMessage ? logoutErrorMessage : @"TDLib logout did not return a result.";
                [self.statusField setStringValue:@"Logout failed"];
                [self appendDetail:[NSString stringWithFormat:@"TDLib logout: %@", message]];
                [[TGLogger sharedLogger] log:[NSString stringWithFormat:@"TDLib logout failed: %@", message]];
                [self setControlsBusy:NO];
            }
            [logoutSummary release];
            [logoutErrorMessage release];
        });

        [client release];
        [pool drain];
    });
}

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
    [_loadMessagesButton release];
    [_loadOlderMessagesButton release];
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
    [_loginLogsButton release];
    [_loginLanguageButtons release];
    [_loginErrorLocalizationKey release];
    [_chatsLabel release];
    [_messagesLabel release];
    [_selectedChatField release];
    [_typingIndicatorField release];
    [_selectedChatAvatarView release];
    [_selectedChatProfileButton release];
    [_chatScrollSurfaceView release];
    [_chatScrollView release];
    [_chatTableView release];
    [_chatItems release];
    [_chatItemsBeforeTopicList release];
    [_messageScrollSurfaceView release];
    [_messageScrollView release];
    if ([_messageTableView isKindOfClass:[TGMessageTableView class]]) {
        [(TGMessageTableView *)_messageTableView setDropOverlayTarget:nil];
    }
    [_inlineMediaPlaybackCoordinator release];
    [_messageTableView release];
    [_messageDropOverlayView release];
    [_messageItems release];
    [_composerDraftsByTargetKey release];
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
    [_settingsFilesSectionField release];
    [_settingsHelpSectionField release];
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
    [_settingsActiveSessionsButton release];
    [_settingsActiveSessionsDetailField release];
    [_settingsLanguageLabel release];
    [_settingsLanguagePopUpButton release];
    [_settingsDownloadFolderHelpField release];
    [_settingsDownloadFolderButton release];
    [_settingsCheckUpdatesButton release];
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
    [_logsWindow close];
    [_aboutWindow close];
    [_appearanceWindow close];
    [_activeSessionsWindow close];
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
    [_activeSessionsStatusField release];
    [_activeSessionsRefreshButton release];
    [_activeSessionsCloseButton release];
    [_mediaPreviewWindow release];
    [_mediaPreviewScrollView release];
    [_mediaPreviewImageView release];
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
    [_photoSendPreviewWindow release];
    [_photoSendPreviewImageView release];
    [_photoSendCaptionBackgroundView release];
    [_photoSendCaptionField release];
    [_photoSendTitleField release];
    [_photoSendErrorField release];
    [_photoSendSendButton release];
    [_pendingPhotoSendPath release];
    [_pendingPhotoSendChatID release];
    [_pendingPhotoSendThreadID release];
    [_pendingPhotoSendTopicKind release];
    [_stickerPickerWindow release];
    [_stickerPickerScrollView release];
    [_stickerPickerContentView release];
    [_stickerPickerItems release];
    [_stickerPickerStatusField release];
    [_stickerPickerPlaybackCoordinator release];
    [_voiceRecorder release];
    [_voicePreviewPlayer release];
    [_voiceRecordingPath release];
    [_voiceRecordingStartDate release];
    [_voicePreviewWindow release];
    [_voicePreviewTitleField release];
    [_voicePreviewPlayButton release];
    [_voicePreviewProgressSlider release];
    [_voicePreviewTimeField release];
    [_voicePreviewSendButton release];
    [_voicePreviewErrorField release];
    [_voicePreviewTimer release];
    [_voiceRecordingIndicatorField release];
    [_messageContextMenu release];
    [_chatContextMenu release];
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
    [super dealloc];
}

@end

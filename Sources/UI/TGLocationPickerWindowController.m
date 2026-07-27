#import "TGLocationPickerWindowController.h"

#import <MapKit/MapKit.h>
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGLocationPickerWindowController ()
@property (nonatomic, assign) BOOL venue;
@property (nonatomic, assign) BOOL mapAvailable;
@property (nonatomic, assign) BOOL waitingForUserLocation;
@property (nonatomic, assign) BOOL hasSelection;
@property (nonatomic, assign) CLLocationCoordinate2D selectedCoordinate;
@property (nonatomic, retain) MKMapView *mapView;
@property (nonatomic, retain) MKPointAnnotation *selectionAnnotation;
@property (nonatomic, retain) NSTextField *searchField;
@property (nonatomic, retain) NSTextField *nameField;
@property (nonatomic, retain) NSTextField *addressField;
@property (nonatomic, retain) NSTextField *latitudeField;
@property (nonatomic, retain) NSTextField *longitudeField;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSButton *searchButton;
@property (nonatomic, retain) NSButton *currentLocationButton;
@property (nonatomic, retain) NSButton *sendButton;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, copy) NSDictionary *result;
@end

@implementation TGLocationPickerWindowController

@synthesize venue = _venue;
@synthesize mapAvailable = _mapAvailable;
@synthesize waitingForUserLocation = _waitingForUserLocation;
@synthesize hasSelection = _hasSelection;
@synthesize selectedCoordinate = _selectedCoordinate;
@synthesize mapView = _mapView;
@synthesize selectionAnnotation = _selectionAnnotation;
@synthesize searchField = _searchField;
@synthesize nameField = _nameField;
@synthesize addressField = _addressField;
@synthesize latitudeField = _latitudeField;
@synthesize longitudeField = _longitudeField;
@synthesize statusField = _statusField;
@synthesize searchButton = _searchButton;
@synthesize currentLocationButton = _currentLocationButton;
@synthesize sendButton = _sendButton;
@synthesize spinner = _spinner;
@synthesize result = _result;

- (id)initForVenue:(BOOL)venue {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 640.0, venue ? 610.0 : 548.0)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.venue = venue;
        self.mapAvailable = (NSClassFromString(@"MKMapView") != Nil &&
                             NSClassFromString(@"MKLocalSearch") != Nil);
        [[self window] setTitle:TGLoc(venue ? @"share.venue.title" : @"share.location.title")];
        [[self window] setReleasedWhenClosed:NO];
        [[self window] setDelegate:(id)self];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_mapView setDelegate:nil];
    [_mapView release];
    [_selectionAnnotation release];
    [_searchField release];
    [_nameField release];
    [_addressField release];
    [_latitudeField release];
    [_longitudeField release];
    [_statusField release];
    [_searchButton release];
    [_currentLocationButton release];
    [_sendButton release];
    [_spinner release];
    [_result release];
    [super dealloc];
}

- (NSTextField *)labelWithFrame:(NSRect)frame text:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
    NSTextField *field = [[[NSTextField alloc] initWithFrame:frame] autorelease];
    [field setEditable:NO];
    [field setSelectable:NO];
    [field setBordered:NO];
    [field setDrawsBackground:NO];
    [field setFont:font];
    [field setTextColor:color];
    [field setStringValue:text ? text : @""];
    return field;
}

- (NSButton *)buttonWithFrame:(NSRect)frame title:(NSString *)title action:(SEL)action primary:(BOOL)primary {
    NSButton *button = [[[NSButton alloc] initWithFrame:frame] autorelease];
    NSButtonCell *cell = primary
        ? (NSButtonCell *)[[[TGPrimaryTextButtonCell alloc] initTextCell:title] autorelease]
        : (NSButtonCell *)[[[TGSecondaryTextButtonCell alloc] initTextCell:title] autorelease];
    [button setCell:cell];
    [button setTitle:title];
    [button setTarget:self];
    [button setAction:action];
    return button;
}

- (void)buildViews {
    CGFloat height = NSHeight([[[self window] contentView] bounds]);
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [[self window] setContentView:root];

    [root addSubview:[self labelWithFrame:NSMakeRect(24.0, height - 47.0, 592.0, 24.0)
                                     text:TGLoc(self.venue ? @"share.venue.title" : @"share.location.title")
                                     font:[NSFont boldSystemFontOfSize:20.0]
                                    color:TGClassicHeaderTextColor(1.0)]];
    [root addSubview:[self labelWithFrame:NSMakeRect(24.0, height - 68.0, 592.0, 18.0)
                                     text:TGLoc(@"share.location.pickerHint")
                                     font:[NSFont systemFontOfSize:11.0]
                                    color:TGClassicHeaderDetailTextColor(0.9)]];

    CGFloat fieldTop = height - 108.0;
    if (self.venue) {
        [root addSubview:[self labelWithFrame:NSMakeRect(24.0, fieldTop, 282.0, 17.0)
                                         text:TGLoc(@"share.venue.name")
                                         font:[NSFont boldSystemFontOfSize:11.0]
                                        color:TGClassicHeaderTextColor(0.9)]];
        [root addSubview:[self labelWithFrame:NSMakeRect(330.0, fieldTop, 286.0, 17.0)
                                         text:TGLoc(@"share.venue.address")
                                         font:[NSFont boldSystemFontOfSize:11.0]
                                        color:TGClassicHeaderTextColor(0.9)]];
        self.nameField = [[[NSTextField alloc] initWithFrame:NSMakeRect(24.0, fieldTop - 27.0, 282.0, 23.0)] autorelease];
        self.addressField = [[[NSTextField alloc] initWithFrame:NSMakeRect(330.0, fieldTop - 27.0, 286.0, 23.0)] autorelease];
        [root addSubview:self.nameField];
        [root addSubview:self.addressField];
        fieldTop -= 58.0;
    }

    self.searchField = [[[NSTextField alloc] initWithFrame:NSMakeRect(24.0, fieldTop - 24.0, 420.0, 24.0)] autorelease];
    [[self.searchField cell] setPlaceholderString:TGLoc(@"share.location.searchPlaceholder")];
    [self.searchField setTarget:self];
    [self.searchField setAction:@selector(searchPressed:)];
    [root addSubview:self.searchField];
    self.searchButton = [self buttonWithFrame:NSMakeRect(452.0, fieldTop - 28.0, 76.0, 30.0)
                                        title:TGLoc(@"share.location.search")
                                       action:@selector(searchPressed:)
                                      primary:NO];
    [root addSubview:self.searchButton];
    self.currentLocationButton = [self buttonWithFrame:NSMakeRect(536.0, fieldTop - 28.0, 80.0, 30.0)
                                                 title:TGLoc(@"share.location.mine")
                                                action:@selector(currentLocationPressed:)
                                               primary:NO];
    [root addSubview:self.currentLocationButton];

    CGFloat mapY = 86.0;
    CGFloat mapTop = fieldTop - 38.0;
    if (self.mapAvailable) {
        self.mapView = [[[NSClassFromString(@"MKMapView") alloc] initWithFrame:NSMakeRect(24.0, mapY + 30.0, 592.0, mapTop - mapY - 30.0)] autorelease];
        [self.mapView setDelegate:(id)self];
        if ([self.mapView respondsToSelector:@selector(setShowsZoomControls:)]) {
            [self.mapView setShowsZoomControls:YES];
        }
        [root addSubview:self.mapView];
        self.selectionAnnotation = [[[MKPointAnnotation alloc] init] autorelease];
        [self.selectionAnnotation setTitle:TGLoc(@"share.location.selected")];
        [self.mapView addAnnotation:self.selectionAnnotation];
        [self setSelectedCoordinate:CLLocationCoordinate2DMake(53.9006, 27.5590) centerMap:YES];
    } else {
        TGGroupedCardView *fallback = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(24.0, mapY + 30.0, 592.0, mapTop - mapY - 30.0)] autorelease];
        [root addSubview:fallback];
        NSTextField *unavailable = [self labelWithFrame:NSMakeRect(44.0, mapTop - 76.0, 552.0, 40.0)
                                                  text:TGLoc(@"share.location.mapUnavailable")
                                                  font:[NSFont systemFontOfSize:12.0]
                                                 color:TGClassicCardInkColor()];
        [[unavailable cell] setUsesSingleLineMode:NO];
        [[unavailable cell] setLineBreakMode:NSLineBreakByWordWrapping];
        [root addSubview:unavailable];
        [root addSubview:[self labelWithFrame:NSMakeRect(44.0, mapTop - 132.0, 250.0, 17.0)
                                         text:TGLoc(@"share.location.latitude")
                                         font:[NSFont boldSystemFontOfSize:11.0]
                                        color:TGClassicCardInkColor()]];
        [root addSubview:[self labelWithFrame:NSMakeRect(322.0, mapTop - 132.0, 250.0, 17.0)
                                         text:TGLoc(@"share.location.longitude")
                                         font:[NSFont boldSystemFontOfSize:11.0]
                                        color:TGClassicCardInkColor()]];
        self.latitudeField = [[[NSTextField alloc] initWithFrame:NSMakeRect(44.0, mapTop - 160.0, 250.0, 23.0)] autorelease];
        self.longitudeField = [[[NSTextField alloc] initWithFrame:NSMakeRect(322.0, mapTop - 160.0, 250.0, 23.0)] autorelease];
        [root addSubview:self.latitudeField];
        [root addSubview:self.longitudeField];
        [self.searchField setEnabled:NO];
        [self.searchButton setEnabled:NO];
        [self.currentLocationButton setEnabled:NO];
    }

    self.statusField = [self labelWithFrame:NSMakeRect(24.0, 91.0, 390.0, 18.0)
                                       text:TGLoc(@"share.location.ready")
                                       font:[NSFont systemFontOfSize:10.0]
                                      color:TGClassicHeaderDetailTextColor(0.92)];
    [root addSubview:self.statusField];
    self.spinner = [[[NSProgressIndicator alloc] initWithFrame:NSMakeRect(420.0, 91.0, 16.0, 16.0)] autorelease];
    [self.spinner setStyle:NSProgressIndicatorSpinningStyle];
    [self.spinner setDisplayedWhenStopped:NO];
    [root addSubview:self.spinner];
    [root addSubview:[self buttonWithFrame:NSMakeRect(428.0, 38.0, 88.0, 32.0)
                                      title:TGLoc(@"cancel")
                                     action:@selector(cancelPressed:)
                                    primary:NO]];
    self.sendButton = [self buttonWithFrame:NSMakeRect(526.0, 38.0, 90.0, 32.0)
                                      title:TGLoc(@"send")
                                     action:@selector(sendPressed:)
                                    primary:YES];
    [root addSubview:self.sendButton];
}

- (BOOL)scanField:(NSTextField *)field value:(double *)value {
    NSString *text = [[[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
                      stringByReplacingOccurrencesOfString:@"," withString:@"."];
    NSScanner *scanner = [NSScanner scannerWithString:text];
    double result = 0.0;
    if ([text length] == 0 || ![scanner scanDouble:&result] || ![scanner isAtEnd]) {
        return NO;
    }
    if (value) {
        *value = result;
    }
    return YES;
}

- (void)setSelectedCoordinate:(CLLocationCoordinate2D)coordinate centerMap:(BOOL)centerMap {
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }
    self.selectedCoordinate = coordinate;
    self.hasSelection = YES;
    [self.selectionAnnotation setCoordinate:coordinate];
    if (centerMap && self.mapView) {
        [self.mapView setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 4500.0, 4500.0) animated:YES];
    }
    [self.statusField setStringValue:[NSString stringWithFormat:TGLoc(@"share.location.coordinates"),
                                      coordinate.latitude, coordinate.longitude]];
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    (void)animated;
    if (mapView == self.mapView && !self.waitingForUserLocation) {
        [self setSelectedCoordinate:[mapView centerCoordinate] centerMap:NO];
    }
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if (mapView != self.mapView || !self.waitingForUserLocation || ![userLocation location]) {
        return;
    }
    self.waitingForUserLocation = NO;
    [self.spinner stopAnimation:nil];
    [self setSelectedCoordinate:[[userLocation location] coordinate] centerMap:YES];
}

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    (void)mapView;
    self.waitingForUserLocation = NO;
    [self.spinner stopAnimation:nil];
    [self.statusField setStringValue:[error localizedDescription] ?: TGLoc(@"share.location.locationFailed")];
}

- (void)currentLocationPressed:(id)sender {
    (void)sender;
    self.waitingForUserLocation = YES;
    [self.statusField setStringValue:TGLoc(@"share.location.locating")];
    [self.spinner startAnimation:nil];
    [self.mapView setShowsUserLocation:NO];
    [self.mapView setShowsUserLocation:YES];
}

- (void)searchPressed:(id)sender {
    (void)sender;
    NSString *query = [[self.searchField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([query length] == 0 || !self.mapAvailable) {
        NSBeep();
        return;
    }
    MKLocalSearchRequest *request = [[[MKLocalSearchRequest alloc] init] autorelease];
    [request setNaturalLanguageQuery:query];
    MKLocalSearch *search = [[[MKLocalSearch alloc] initWithRequest:request] autorelease];
    [self.spinner startAnimation:nil];
    [self.searchButton setEnabled:NO];
    [self.statusField setStringValue:TGLoc(@"share.location.searching")];
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        [self.spinner stopAnimation:nil];
        [self.searchButton setEnabled:YES];
        MKMapItem *item = [[response mapItems] count] > 0 ? [[response mapItems] objectAtIndex:0] : nil;
        if (!item) {
            [self.statusField setStringValue:[error localizedDescription] ?: TGLoc(@"share.location.notFound")];
            return;
        }
        [self setSelectedCoordinate:[[[item placemark] location] coordinate] centerMap:YES];
        NSString *name = [item name];
        NSString *address = [[item placemark] title];
        if (self.venue && [[self.nameField stringValue] length] == 0 && [name length] > 0) {
            [self.nameField setStringValue:name];
        }
        if (self.venue && [[self.addressField stringValue] length] == 0 && [address length] > 0) {
            [self.addressField setStringValue:address];
        }
    }];
}

- (void)sendPressed:(id)sender {
    (void)sender;
    CLLocationCoordinate2D coordinate = self.selectedCoordinate;
    if (!self.mapAvailable) {
        double latitude = 0.0;
        double longitude = 0.0;
        if (![self scanField:self.latitudeField value:&latitude] ||
            ![self scanField:self.longitudeField value:&longitude]) {
            [self.statusField setStringValue:TGLoc(@"share.location.error.invalid")];
            NSBeep();
            return;
        }
        coordinate = CLLocationCoordinate2DMake(latitude, longitude);
    }
    if (!CLLocationCoordinate2DIsValid(coordinate) ||
        coordinate.latitude < -90.0 || coordinate.latitude > 90.0 ||
        coordinate.longitude < -180.0 || coordinate.longitude > 180.0) {
        [self.statusField setStringValue:TGLoc(@"share.location.error.invalid")];
        NSBeep();
        return;
    }
    NSMutableDictionary *values = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithDouble:coordinate.latitude], @"latitude",
                                   [NSNumber numberWithDouble:coordinate.longitude], @"longitude",
                                   nil];
    if (self.venue) {
        NSString *name = [[self.nameField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *address = [[self.addressField stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([name length] == 0) {
            [self.statusField setStringValue:TGLoc(@"share.venue.error")];
            NSBeep();
            return;
        }
        [values setObject:name forKey:@"title"];
        [values setObject:address ? address : @"" forKey:@"address"];
    }
    self.result = values;
    [NSApp stopModalWithCode:NSOKButton];
    [[self window] orderOut:self];
}

- (void)cancelPressed:(id)sender {
    (void)sender;
    [NSApp abortModal];
    [[self window] orderOut:self];
}

- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    [NSApp abortModal];
    return YES;
}

- (NSDictionary *)runModal {
    [[self window] center];
    [[self window] makeKeyAndOrderFront:self];
    NSInteger result = [NSApp runModalForWindow:[self window]];
    return (result == NSOKButton) ? self.result : nil;
}

@end

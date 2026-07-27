#import "TGLocationPickerWindowController.h"

#import <MapKit/MapKit.h>
#import "../Core/TGTDLibClient+MapThumbnail.h"
#import "TGLocationStaticMapView.h"
#import "TGLocalization.h"
#import "TGStatusButtonCells.h"
#import "TGStatusViewComponents.h"
#import "TGStatusViewCells.h"
#import "TGTheme.h"

@interface TGLocationPickerWindowController ()
@property (nonatomic, retain) TGTDLibClient *client;
@property (nonatomic, assign) BOOL mapServicesAvailable;
@property (nonatomic, assign) BOOL waitingForUserLocation;
@property (nonatomic, assign) BOOL hasSelection;
@property (nonatomic, assign) NSUInteger mapGeneration;
@property (nonatomic, assign) NSInteger mapZoom;
@property (nonatomic, assign) CLLocationCoordinate2D selectedCoordinate;
@property (nonatomic, retain) MKMapView *locationServiceMapView;
@property (nonatomic, retain) TGLocationStaticMapView *mapImageView;
@property (nonatomic, retain) NSTextField *statusField;
@property (nonatomic, retain) NSButton *currentLocationButton;
@property (nonatomic, retain) NSButton *sendButton;
@property (nonatomic, retain) NSProgressIndicator *spinner;
@property (nonatomic, copy) NSDictionary *result;
@end

@implementation TGLocationPickerWindowController

@synthesize client = _client;
@synthesize mapServicesAvailable = _mapServicesAvailable;
@synthesize waitingForUserLocation = _waitingForUserLocation;
@synthesize hasSelection = _hasSelection;
@synthesize mapGeneration = _mapGeneration;
@synthesize mapZoom = _mapZoom;
@synthesize selectedCoordinate = _selectedCoordinate;
@synthesize locationServiceMapView = _locationServiceMapView;
@synthesize mapImageView = _mapImageView;
@synthesize statusField = _statusField;
@synthesize currentLocationButton = _currentLocationButton;
@synthesize sendButton = _sendButton;
@synthesize spinner = _spinner;
@synthesize result = _result;

- (id)initWithClient:(TGTDLibClient *)client {
    NSWindow *window = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0.0, 0.0, 640.0, 548.0)
                                                    styleMask:(NSTitledWindowMask | NSClosableWindowMask)
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO] autorelease];
    self = [super initWithWindow:window];
    if (self) {
        self.client = client;
        self.mapZoom = 15;
        self.mapServicesAvailable = (NSClassFromString(@"MKMapView") != Nil &&
                                     NSClassFromString(@"MKPinAnnotationView") != Nil);
        [[self window] setTitle:TGLoc(@"share.location.title")];
        [[self window] setReleasedWhenClosed:NO];
        [[self window] setDelegate:(id)self];
        [self buildViews];
    }
    return self;
}

- (void)dealloc {
    [_locationServiceMapView setDelegate:nil];
    [_client release];
    [_locationServiceMapView release];
    [_mapImageView release];
    [_statusField release];
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

- (NSImage *)systemSelectionPinImage {
    MKPointAnnotation *annotation = [[[NSClassFromString(@"MKPointAnnotation") alloc] init] autorelease];
    MKPinAnnotationView *pinView = [[[NSClassFromString(@"MKPinAnnotationView") alloc]
        initWithAnnotation:annotation reuseIdentifier:@"telegraphica-location-pin-image"] autorelease];
    [pinView setAnimatesDrop:NO];
    [pinView setCanShowCallout:NO];
    NSRect pinFrame = [pinView frame];
    if (NSWidth(pinFrame) < 8.0 || NSHeight(pinFrame) < 8.0) {
        pinFrame = NSMakeRect(0.0, 0.0, 32.0, 39.0);
        [pinView setFrame:pinFrame];
    }
    NSImage *builtInImage = [pinView image];
    if (builtInImage && [builtInImage size].width >= 8.0) {
        return builtInImage;
    }
    NSRect bounds = [pinView bounds];
    NSBitmapImageRep *representation = [pinView bitmapImageRepForCachingDisplayInRect:bounds];
    if (!representation) {
        return nil;
    }
    [pinView cacheDisplayInRect:bounds toBitmapImageRep:representation];
    NSImage *image = [[[NSImage alloc] initWithSize:bounds.size] autorelease];
    [image addRepresentation:representation];
    return image;
}

- (void)buildViews {
    CGFloat height = NSHeight([[[self window] contentView] bounds]);
    TGUtilityWindowView *root = [[[TGUtilityWindowView alloc] initWithFrame:[[[self window] contentView] bounds]] autorelease];
    [[self window] setContentView:root];
    [root addSubview:[self labelWithFrame:NSMakeRect(24.0, height - 47.0, 592.0, 24.0)
                                     text:TGLoc(@"share.location.title")
                                     font:[NSFont boldSystemFontOfSize:20.0]
                                    color:TGClassicHeaderTextColor(1.0)]];
    [root addSubview:[self labelWithFrame:NSMakeRect(24.0, height - 68.0, 592.0, 18.0)
                                     text:TGLoc(@"share.location.pickerHint")
                                     font:[NSFont systemFontOfSize:11.0]
                                    color:TGClassicHeaderDetailTextColor(0.9)]];

    self.currentLocationButton = [self buttonWithFrame:NSMakeRect(500.0, height - 116.0, 116.0, 30.0)
                                                 title:TGLoc(@"share.location.mine")
                                                action:@selector(currentLocationPressed:)
                                               primary:NO];
    [root addSubview:self.currentLocationButton];

    TGGroupedCardView *mapCard = [[[TGGroupedCardView alloc] initWithFrame:NSMakeRect(24.0, 116.0, 592.0, 306.0)] autorelease];
    [root addSubview:mapCard];
    self.mapImageView = [[[TGLocationStaticMapView alloc] initWithFrame:NSMakeRect(30.0, 122.0, 580.0, 294.0)] autorelease];
    [self.mapImageView setCoordinateTarget:self];
    [self.mapImageView setCoordinateAction:@selector(mapCoordinateChosen:)];
    [self.mapImageView setZoom:self.mapZoom];
    [root addSubview:self.mapImageView];

    if (self.mapServicesAvailable) {
        self.locationServiceMapView = [[[NSClassFromString(@"MKMapView") alloc]
            initWithFrame:NSMakeRect(-4.0, -4.0, 1.0, 1.0)] autorelease];
        [self.locationServiceMapView setDelegate:(id)self];
        [self.locationServiceMapView setHidden:YES];
        [root addSubview:self.locationServiceMapView];

        [self.mapImageView setSelectionPinImage:[self systemSelectionPinImage]];
    } else {
        [self.currentLocationButton setEnabled:NO];
    }

    [root addSubview:[self buttonWithFrame:NSMakeRect(548.0, 382.0, 28.0, 28.0)
                                      title:@"−"
                                     action:@selector(zoomOutPressed:)
                                    primary:NO]];
    [root addSubview:[self buttonWithFrame:NSMakeRect(578.0, 382.0, 28.0, 28.0)
                                      title:@"+"
                                     action:@selector(zoomInPressed:)
                                    primary:NO]];

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
    [self setSelectedCoordinate:CLLocationCoordinate2DMake(53.9006, 27.5590) reloadMap:YES];
}

- (void)setSelectedCoordinate:(CLLocationCoordinate2D)coordinate reloadMap:(BOOL)reloadMap {
    if (!CLLocationCoordinate2DIsValid(coordinate)) {
        return;
    }
    self.selectedCoordinate = coordinate;
    self.hasSelection = YES;
    if (![self.mapImageView image]) {
        [self.mapImageView setCenterLatitude:coordinate.latitude];
        [self.mapImageView setCenterLongitude:coordinate.longitude];
    }
    [self.statusField setStringValue:[NSString stringWithFormat:TGLoc(@"share.location.coordinates"),
                                      coordinate.latitude, coordinate.longitude]];
    if (reloadMap) {
        [self reloadMapThumbnail];
    }
}

- (void)reloadMapThumbnail {
    self.mapGeneration++;
    NSUInteger generation = self.mapGeneration;
    CLLocationCoordinate2D coordinate = self.selectedCoordinate;
    NSInteger zoom = self.mapZoom;
    [self.spinner startAnimation:nil];
    [self.statusField setStringValue:TGLoc(@"share.location.mapLoading")];
    TGTDLibClient *client = [self.client retain];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = nil;
        NSString *path = [[client mapThumbnailPathForLatitude:coordinate.latitude
                                                   longitude:coordinate.longitude
                                                        zoom:zoom width:580 height:294
                                                     timeout:12.0 error:&error] copy];
        NSImage *image = [path length] > 0 ? [[NSImage alloc] initWithContentsOfFile:path] : nil;
        NSString *failure = [[error localizedDescription] copy];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation == self.mapGeneration) {
                [self.spinner stopAnimation:nil];
                if (image) {
                    [self.mapImageView setMapImage:image
                                    centerLatitude:coordinate.latitude
                                         longitude:coordinate.longitude
                                              zoom:zoom];
                    [self.statusField setStringValue:[NSString stringWithFormat:TGLoc(@"share.location.coordinates"),
                                                      coordinate.latitude, coordinate.longitude]];
                } else {
                    [self.statusField setStringValue:[failure length] > 0
                        ? failure : TGLoc(@"share.location.mapUnavailable")];
                }
            }
            [failure release];
            [image release];
            [path release];
            [client release];
        });
        [pool drain];
    });
}

- (void)mapCoordinateChosen:(NSDictionary *)coordinate {
    CLLocationCoordinate2D selected = CLLocationCoordinate2DMake([[coordinate objectForKey:@"latitude"] doubleValue],
                                                                 [[coordinate objectForKey:@"longitude"] doubleValue]);
    id zoom = [coordinate objectForKey:@"zoom"];
    if ([zoom respondsToSelector:@selector(integerValue)]) {
        self.mapZoom = MAX(13, MIN(18, [zoom integerValue]));
    }
    [self setSelectedCoordinate:selected reloadMap:YES];
}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if (mapView != self.locationServiceMapView || !self.waitingForUserLocation || ![userLocation location]) {
        return;
    }
    self.waitingForUserLocation = NO;
    [self.spinner stopAnimation:nil];
    [self setSelectedCoordinate:[[userLocation location] coordinate] reloadMap:YES];
}

- (void)mapView:(MKMapView *)mapView didFailToLocateUserWithError:(NSError *)error {
    (void)mapView;
    self.waitingForUserLocation = NO;
    [self.spinner stopAnimation:nil];
    [self.statusField setStringValue:[error localizedDescription] ?: TGLoc(@"share.location.locationFailed")];
}

- (void)zoomOutPressed:(id)sender {
    (void)sender;
    [self.mapImageView requestZoomDelta:-1];
}

- (void)zoomInPressed:(id)sender {
    (void)sender;
    [self.mapImageView requestZoomDelta:1];
}

- (void)currentLocationPressed:(id)sender {
    (void)sender;
    self.waitingForUserLocation = YES;
    [self.statusField setStringValue:TGLoc(@"share.location.locating")];
    [self.spinner startAnimation:nil];
    [self.locationServiceMapView setShowsUserLocation:NO];
    [self.locationServiceMapView setShowsUserLocation:YES];
}

- (void)prepareForClosing {
    self.mapGeneration++;
    self.waitingForUserLocation = NO;
    [self.spinner stopAnimation:nil];
    [self.locationServiceMapView setShowsUserLocation:NO];
    [self.locationServiceMapView setDelegate:nil];
    [self.mapImageView setCoordinateTarget:nil];
    [self.mapImageView setCoordinateAction:NULL];
}

- (void)sendPressed:(id)sender {
    (void)sender;
    CLLocationCoordinate2D coordinate = self.selectedCoordinate;
    if (!self.hasSelection || !CLLocationCoordinate2DIsValid(coordinate) ||
        coordinate.latitude < -90.0 || coordinate.latitude > 90.0 ||
        coordinate.longitude < -180.0 || coordinate.longitude > 180.0) {
        [self.statusField setStringValue:TGLoc(@"share.location.error.invalid")];
        NSBeep();
        return;
    }
    self.result = [NSDictionary dictionaryWithObjectsAndKeys:
                   [NSNumber numberWithDouble:coordinate.latitude], @"latitude",
                   [NSNumber numberWithDouble:coordinate.longitude], @"longitude", nil];
    [self prepareForClosing];
    [NSApp stopModalWithCode:NSOKButton];
    [[self window] orderOut:self];
}

- (void)cancelPressed:(id)sender {
    (void)sender;
    [self prepareForClosing];
    [NSApp abortModal];
    [[self window] orderOut:self];
}

- (BOOL)windowShouldClose:(id)sender {
    (void)sender;
    [self prepareForClosing];
    [NSApp abortModal];
    return YES;
}

- (NSDictionary *)runModal {
    self.result = nil;
    [[self window] center];
    [NSApp runModalForWindow:[self window]];
    return self.result;
}

@end

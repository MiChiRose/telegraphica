#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

@interface TGLocationStaticMapView : NSImageView

@property (nonatomic, assign) id coordinateTarget;
@property (nonatomic, assign) SEL coordinateAction;
@property (nonatomic, assign) double centerLatitude;
@property (nonatomic, assign) double centerLongitude;
@property (nonatomic, assign) NSInteger zoom;

- (void)setMapImage:(NSImage *)image
     centerLatitude:(double)latitude
          longitude:(double)longitude
               zoom:(NSInteger)zoom;
- (void)requestZoomDelta:(NSInteger)delta;

@end

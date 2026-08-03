#import <Foundation/Foundation.h>

/*
 * Main-thread lifecycle token for retained utility windows. Each presentation
 * and operation advances the generation so late callbacks can be rejected.
 */
@interface TGUtilityWindowLifetime : NSObject {
@private
    NSUInteger _generation;
    BOOL _active;
}

@property (nonatomic, readonly, assign) NSUInteger generation;
@property (nonatomic, readonly, assign, getter=isActive) BOOL active;

- (NSUInteger)beginPresentation;
- (NSUInteger)beginOperation;
- (void)invalidate;
- (BOOL)isCurrentGeneration:(NSUInteger)generation;

@end

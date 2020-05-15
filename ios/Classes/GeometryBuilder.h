@import SceneKit;
@import ARKit;
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN
typedef void (^OnReachToEnd)(void);

@interface GeometryBuilder : NSObject

+ (SCNGeometry *) createGeometry:(NSDictionary *) geometryArguments withDevice: (NSObject*) device;

@end

@interface VideoView: MTKView

- (void) play;
- (void) pause;
- (BOOL) isPlaying;
- (instancetype)initWithProperties:(NSDictionary*)videoProperties;
@property CGFloat width;
@property CGFloat height;
@property BOOL isLoop;
@property (copy) OnReachToEnd doOnReachToEnd;

@end


NS_ASSUME_NONNULL_END

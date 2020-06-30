@import SceneKit;
@import ARKit;
@import MetalKit;

NS_ASSUME_NONNULL_BEGIN
typedef void (^OnReachToEnd)(void);

@interface GeometryBuilder : NSObject
+ (SCNGeometry *) createGeometry:(NSDictionary *) geometryArguments call:(NSDictionary *) call controller: (NSObject*)controller withDevice: (NSObject*) device;

@end

@interface VideoView: MTKView<MTKViewDelegate>
- (void) play;
- (void) pause;
- (BOOL) isPlaying;
- (instancetype)initWithProperties:(SCNMaterialProperty*)property dict: (NSDictionary *)videoProperties;
- (void) dispose;
@property CGFloat width;
@property CGFloat height;
@property BOOL isLoop;
@property (copy) OnReachToEnd doOnReachToEnd;

@end

NS_ASSUME_NONNULL_END

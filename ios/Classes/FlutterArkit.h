@import Flutter;
@import ARKit;
@import SceneKit;

API_AVAILABLE(ios(11.3))
@interface FlutterArkitController : NSObject <FlutterPlatformView>

- (nonnull instancetype)initWithWithFrame:(CGRect)frame
                           viewIdentifier:(int64_t)viewId
                                arguments:(id _Nullable)args
                          binaryMessenger:(nonnull NSObject<FlutterBinaryMessenger>*)messenger;

- (nonnull UIView*)view;
- (BOOL)addNurieObject:(nonnull ARAnchor*) anchor node: (nonnull SCNNode*) node;
- (BOOL)checkMarkerNurie:(nonnull ARAnchor*) anchor node: (nonnull SCNNode*) node;

@property (readonly, nonatomic, strong, nonnull) ARSCNView *sceneView;
@property (readonly, nonatomic, strong, nonnull) ARConfiguration *configuration;

@end

@interface FlutterArkitFactory : NSObject <FlutterPlatformViewFactory>
- (nonnull instancetype)initWithMessenger:(nonnull NSObject<FlutterBinaryMessenger>*)messenger;
@end

@interface NurieParams: NSObject

- (nonnull id) initWithName:(nonnull NSString*)name;

@property (readonly) NSString* _Nonnull name;
@property UIImage* _Nullable image;

@end

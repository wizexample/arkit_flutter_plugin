#import "FlutterArkit.h"
#import "Color.h"
#import "GeometryBuilder.h"
#import "SceneViewDelegate.h"
#import "CodableUtils.h"
#import "DecodableUtils.h"
#import <SceneKit/ModelIO.h>
#import "ArkitPlugin.h"
#import <ReplayKit/ReplayKit.h>

@interface FlutterArkitFactory()
@property NSObject<FlutterBinaryMessenger>* messenger;
@end

@implementation FlutterArkitFactory

- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
  self = [super init];
  if (self) {
    self.messenger = messenger;
  }
  return self;
}

- (NSObject<FlutterMessageCodec>*)createArgsCodec {
  return [FlutterStandardMessageCodec sharedInstance];
}

- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
  FlutterArkitController* arkitController =
      [[FlutterArkitController alloc] initWithWithFrame:frame
                                         viewIdentifier:viewId
                                              arguments:args
                                        binaryMessenger:self.messenger];
  return arkitController;
}

@end

@interface FlutterArkitController()
@property ARPlaneDetection planeDetection;
@property int64_t viewId;
@property FlutterMethodChannel* channel;
@property (strong) SceneViewDelegate* delegate;
@property (readwrite) ARConfiguration *configuration;
@property BOOL forceUserTapOnCenter;
@end

@implementation FlutterArkitController

static const NSString* REFERENCE_CHILD_NODE = @"REFERENCE_CHILD_NODE";

static NSMutableSet *g_mSet = NULL;
SCNNode* objectsParent;

NSMutableDictionary *nurieParams = nil;
BOOL nurieFindingMode = false;
float prevMarkerCorners[] = {0,0,0,0,0,0,0,0};
int counterMarkerCorners = 0;
const int checkMarkerCorners = 8;
const int thresholdMarkerCorners = 5;
int viewWidth;
int viewHeight;


- (instancetype)initWithWithFrame:(CGRect)frame
                   viewIdentifier:(int64_t)viewId
                        arguments:(id _Nullable)args
                  binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    if ([super init]) {
        _viewId = viewId;
        _sceneView = [[ARSCNView alloc] initWithFrame:frame];

        NSString* channelName = [NSString stringWithFormat:@"arkit", viewId];
        NSLog(@"####### channelName=%@", channelName);
        _channel = [FlutterMethodChannel methodChannelWithName:channelName binaryMessenger:messenger];
        __weak __typeof__(self) weakSelf = self;
        [_channel setMethodCallHandler:^(FlutterMethodCall* call, FlutterResult result) {
            [weakSelf onMethodCall:call result:result];
        }];
        self.delegate = [[SceneViewDelegate alloc] initWithChannel: _channel controller:self];
        _sceneView.delegate = self.delegate;

        objectsParent = [[SCNNode alloc] init];
        [_sceneView.scene.rootNode addChildNode:objectsParent];
    }
    return self;
}

- (UIView*)view {
  return _sceneView;
}

- (void)onMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
//   if ([[call method] isEqualToString:@"init"]) {
//     [self init:call result:result];
  if ([[call method] isEqualToString:@"addARKitNode"]) {
    [self onAddNode:call result:result];
  } else if ([[call method] isEqualToString:@"removeARKitNode"]) {
    [self onRemoveNode:call result:result];
  } else if ([[call method] isEqualToString:@"getNodeBoundingBox"]) {
    [self onGetNodeBoundingBox:call result:result];
  } else if ([[call method] isEqualToString:@"positionChanged"]) {
    [self updatePosition:call andResult:result];
  } else if ([[call method] isEqualToString:@"rotationChanged"]) {
    [self updateRotation:call andResult:result];
  } else if ([[call method] isEqualToString:@"eulerAnglesChanged"]) {
    [self updateEulerAngles:call andResult:result];
  } else if ([[call method] isEqualToString:@"scaleChanged"]) {
    [self updateScale:call andResult:result];
  } else if ([[call method] isEqualToString:@"isHiddenChanged"]) {
    [self updateIsHidden:call andResult:result];
  } else if ([[call method] isEqualToString:@"isPlayChanged"]) {
    [self updateIsPlay:call andResult:result];
  } else if ([[call method] isEqualToString:@"updateSingleProperty"]) {
    [self updateSingleProperty:call andResult:result];
  } else if ([[call method] isEqualToString:@"updateMaterials"]) {
    [self updateMaterials:call andResult:result];
//   } else if ([[call method] isEqualToString:@"updateFaceGeometry"]) {
//     [self updateFaceGeometry:call andResult:result];
  } else if ([[call method] isEqualToString:@"getLightEstimate"]) {
    [self onGetLightEstimate:call andResult:result];
  } else if ([[call method] isEqualToString:@"projectPoint"]) {
    [self onProjectPoint:call andResult:result];
  } else if ([[call method] isEqualToString:@"cameraProjectionMatrix"]) {
    [self onCameraProjectionMatrix:call andResult:result];
  } else if ([[call method] isEqualToString:@"startAnimation"]) {
    [self onStartAnimation:call andResult:result];
  } else if ([[call method] isEqualToString:@"stopAnimation"]) {
    [self onStopAnimation:call andResult:result];
  } else if ([[call method] isEqualToString:@"dispose"]) {
    [self.sceneView.session pause];
    NSLog(@"ARKit is dispose");
  } else if ([[call method] isEqualToString:@"initStartWorldTrackingSessionWithImage"]) {
    [self initStartWorldTrackingSessionWithImage:call result:result];
  } else if ([[call method] isEqualToString:@"addImageRunWithConfigAndImage"]) {
    [self addImageRunWithConfigAndImage:call result:result];
  } else if ([[call method] isEqualToString:@"startWorldTrackingSessionWithImage"]) {
    [self startWorldTrackingSessionWithImage:call result:result];
  } else if ([call.method isEqualToString:@"screenCapture"]) {
      [self screenCapture: call andResult: result];
  } else if ([call.method isEqualToString:@"toggleScreenRecord"]) {
      [self toggleScreenRecord: call andResult: result];
  } else if ([call.method isEqualToString:@"startScreenRecord"]) {
      [self startScreenRecord: call andResult: result];
  } else if ([call.method isEqualToString:@"stopScreenRecord"]) {
      [self stopScreenRecord: call andResult: result];
  } else if ([call.method isEqualToString:@"addNurie"]) {
      [self addNurie: call result: result];
  } else if ([call.method isEqualToString:@"findNurieMarker"]) {
      [self findNurieMarker: call result: result];
  } else if ([call.method isEqualToString:@"applyNurieTexture"]) {
      [self applyNurieTexture: call result: result];
  } else if ([call.method isEqualToString:@"addTransformableNode"]) {
//      [self addTransformableNode: call result: result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}


// - (void)init:(FlutterMethodCall*)call result:(FlutterResult)result {
//     NSNumber* showStatistics = call.arguments[@"showStatistics"];
//     self.sceneView.showsStatistics = [showStatistics boolValue];
  
//     NSNumber* autoenablesDefaultLighting = call.arguments[@"autoenablesDefaultLighting"];
//     self.sceneView.autoenablesDefaultLighting = [autoenablesDefaultLighting boolValue];
    
//     NSNumber* forceUserTapOnCenter = call.arguments[@"forceUserTapOnCenter"];
//     self.forceUserTapOnCenter = [forceUserTapOnCenter boolValue];
  
//     NSNumber* requestedPlaneDetection = call.arguments[@"planeDetection"];
//     self.planeDetection = [self getPlaneFromNumber:[requestedPlaneDetection intValue]];
    
//     if ([call.arguments[@"enableTapRecognizer"] boolValue]) {
//         UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
//         [self.sceneView addGestureRecognizer:tapGestureRecognizer];
//     }
    
//     if ([call.arguments[@"enablePinchRecognizer"] boolValue]) {
//         UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchFrom:)];
//         [self.sceneView addGestureRecognizer:pinchGestureRecognizer];
//     }
    
//     if ([call.arguments[@"enablePanRecognizer"] boolValue]) {
//         UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)];
//         [self.sceneView addGestureRecognizer:panGestureRecognizer];
//     }
    
//     self.sceneView.debugOptions = [self getDebugOptions:call.arguments];
    
//     _configuration = [self buildConfiguration: call.arguments];

//     [self.sceneView.session runWithConfiguration:[self configuration]];
//     result(nil);
// }

- (void)initStartWorldTrackingSessionWithImage:(FlutterMethodCall*)call result:(FlutterResult)result {
    viewWidth = _sceneView.bounds.size.width;
    viewHeight = _sceneView.bounds.size.height;
    NSNumber* showStatistics = call.arguments[@"showStatistics"];
    self.sceneView.showsStatistics = [showStatistics boolValue];
  
    NSNumber* autoenablesDefaultLighting = call.arguments[@"autoenablesDefaultLighting"];
    self.sceneView.autoenablesDefaultLighting = [autoenablesDefaultLighting boolValue];
    
    NSNumber* forceUserTapOnCenter = call.arguments[@"forceUserTapOnCenter"];
    self.forceUserTapOnCenter = [forceUserTapOnCenter boolValue];
  
    NSNumber* requestedPlaneDetection = call.arguments[@"planeDetection"];
    self.planeDetection = [self getPlaneFromNumber:[requestedPlaneDetection intValue]];
    
    if ([call.arguments[@"enableTapRecognizer"] boolValue]) {
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapFrom:)];
        [self.sceneView addGestureRecognizer:tapGestureRecognizer];
    }
    
    if ([call.arguments[@"enablePinchRecognizer"] boolValue]) {
        UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchFrom:)];
        [self.sceneView addGestureRecognizer:pinchGestureRecognizer];
    }
    
    if ([call.arguments[@"enablePanRecognizer"] boolValue]) {
        UIPanGestureRecognizer *panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanFrom:)];
        [self.sceneView addGestureRecognizer:panGestureRecognizer];
    }
    
    self.sceneView.debugOptions = [self getDebugOptions:call.arguments];
    
    _configuration = [self buildConfiguration: call.arguments];

    // [self.sceneView.session runWithConfiguration:[self configuration]];
    g_mSet = [[NSMutableSet alloc ]init];
    nurieParams =  [NSMutableDictionary dictionary];

    result(nil);
}

- (void)addImageRunWithConfigAndImage:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSNumber* imageLengthNSNumber = call.arguments[@"imageLength"];
    double imageLength = [imageLengthNSNumber doubleValue];
    NSData* imageData = [((FlutterStandardTypedData*) call.arguments[@"imageBytes"]) data];
    NSString* imageNameNSString = call.arguments[@"imageName"];
    NSNumber* markerSizeMeterNSNumber = call.arguments[@"markerSizeMeter"];
    double markerSizeMeter = [markerSizeMeterNSNumber doubleValue];
    // NSLog(@"####### addImageRunWithConfigAndImage: imageLength=%@ imageName=%@ markerSizeMeter=%@", imageLength, imageNameNSString, markerSizeMeter);

    //   'imageBytes': bytes,
    //   'imageLength': lengthInBytes,
    //   'imageName': imageName,
    //   'markerSizeMeter': markerSizeMeter,

    UIImage* uiimage = [[UIImage alloc] initWithData:imageData];
    CGImageRef cgImage = [uiimage CGImage];
    
    ARReferenceImage *image = [[ARReferenceImage alloc] initWithCGImage:cgImage orientation:kCGImagePropertyOrientationUp physicalWidth:markerSizeMeter];
    
    image.name = imageNameNSString;
    [g_mSet addObject:image];

    result(nil);
}

- (void)addNurie:(FlutterMethodCall*)call result:(FlutterResult)result {
    UIImage* uiimage;
    if (call.arguments[@"filePath"] != nil) {
        uiimage = [[UIImage alloc] initWithContentsOfFile:call.arguments[@"filePath"]];
    } else {
        NSData* imageData = [((FlutterStandardTypedData*) call.arguments[@"imageBytes"]) data];
        uiimage = [[UIImage alloc] initWithData:imageData];
    }
    NSString* imageName = call.arguments[@"imageName"];
    NSNumber* markerSizeMeterNSNumber = call.arguments[@"markerSizeMeter"];
    double markerSizeMeter = [markerSizeMeterNSNumber doubleValue];
    
    nurieParams[imageName] = [[NurieParams alloc] initWithName:imageName];

    CGImageRef cgImage = [uiimage CGImage];
    
    ARReferenceImage *image = [[ARReferenceImage alloc] initWithCGImage:cgImage orientation:kCGImagePropertyOrientationUp physicalWidth:markerSizeMeter];
    
    image.name = imageName;
    [g_mSet addObject:image];

    result(nil);
}

- (SCNVector3) getScreenPoint:(SCNNode*) camera pose:(SCNNode*)pose x:(float)x z:(float)z {
    SCNVector3 t = SCNVector3Make(x, 0, z);
    return [_sceneView projectPoint: [pose convertPosition:t toNode:nil]];
}

- (UIImage*) affine:(UIImage*)input ul:(SCNVector3)ul ur:(SCNVector3)ur bl:(SCNVector3)bl br:(SCNVector3)br {
    CIImage *ciImage = [CIImage imageWithCGImage:input.CGImage];
    CIFilter *perspective = [CIFilter filterWithName:@"CIPerspectiveCorrection"];
    CGFloat scale = UIScreen.mainScreen.scale;
    CGFloat height = input.size.height;
    [perspective setValue:[CIVector vectorWithX:ul.x * scale Y:height - ul.y * scale] forKey:@"inputTopLeft"];
    [perspective setValue:[CIVector vectorWithX:ur.x * scale Y:height - ur.y * scale] forKey:@"inputTopRight"];
    [perspective setValue:[CIVector vectorWithX:bl.x * scale Y:height - bl.y * scale] forKey:@"inputBottomLeft"];
    [perspective setValue:[CIVector vectorWithX:br.x * scale Y:height - br.y * scale] forKey:@"inputBottomRight"];
    [perspective setValue:ciImage forKey:kCIInputImageKey];
    ciImage = perspective.outputImage;
    return [UIImage imageWithCGImage:[[CIContext contextWithOptions:nil] createCGImage:ciImage fromRect:ciImage.extent]];
}

- (void)startWorldTrackingSessionWithImage:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSNumber* runOpts = call.arguments[@"runOpts"];
    NSLog(@"####### startWorldTrackingSessionWithImage: runOpts=%@", runOpts);

    // ARWorldTrackingConfigurationのみ
    ((ARWorldTrackingConfiguration*)_configuration).detectionImages = g_mSet;
    
    [self.sceneView.session runWithConfiguration:[self configuration] options:runOpts];
}

- (ARConfiguration*) buildConfiguration: (NSDictionary*)params {
    int configurationType = [params[@"configuration"] intValue];
    ARConfiguration* _configuration;
    
    if (configurationType == 0) {
        if (ARWorldTrackingConfiguration.isSupported) {
            ARWorldTrackingConfiguration* worldTrackingConfiguration = [ARWorldTrackingConfiguration new];
            worldTrackingConfiguration.planeDetection = self.planeDetection;
            // NSString* detectionImages = params[@"detectionImagesGroupName"];
            // if ([detectionImages isKindOfClass:[NSString class]]) {
            //     worldTrackingConfiguration.detectionImages = [ARReferenceImage referenceImagesInGroupNamed:detectionImages bundle:nil];
            // }
            NSNumber* autoFocusEnabled = params[@"autoFocusEnabled"];
            worldTrackingConfiguration.autoFocusEnabled = [autoFocusEnabled boolValue];

            NSNumber* maximumNumberOfTrackedImages = params[@"maximumNumberOfTrackedImages"];
            worldTrackingConfiguration.maximumNumberOfTrackedImages = [maximumNumberOfTrackedImages intValue];

            _configuration = worldTrackingConfiguration;
        }
    // } else if (configurationType == 1) {
    //     if (ARFaceTrackingConfiguration.isSupported) {
    //         ARFaceTrackingConfiguration* faceTrackingConfiguration = [ARFaceTrackingConfiguration new];
    //         _configuration = faceTrackingConfiguration;
    //     }
    // } else if (configurationType == 2) {
    //     if (ARImageTrackingConfiguration.isSupported) {
    //         ARImageTrackingConfiguration* imageTrackingConfiguration = [ARImageTrackingConfiguration new];
    //         NSString* trackingImages = params[@"trackingImagesGroupName"];
    //         if ([trackingImages isKindOfClass:[NSString class]]) {
    //             imageTrackingConfiguration.trackingImages = [ARReferenceImage referenceImagesInGroupNamed:trackingImages bundle:nil];
    //         }
    //         _configuration = imageTrackingConfiguration;
    //     }
    }
    NSNumber* worldAlignment = params[@"worldAlignment"];
    _configuration.worldAlignment = [self getWorldAlignmentFromNumber:[worldAlignment intValue]];

    NSNumber* lightEstimationEnabled = params[@"lightEstimationEnabled"];
    _configuration.lightEstimationEnabled = [lightEstimationEnabled boolValue];

    return _configuration;
}

- (void)onAddNode:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary* geometryArguments = call.arguments[@"geometry"];
    SCNGeometry* geometry = [GeometryBuilder createGeometry:geometryArguments withDevice: _sceneView.device];
    [self addNodeToSceneWithGeometry:geometry andCall:call andResult:result];
}

- (void)onRemoveNode:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString* nodeName = call.arguments[@"nodeName"];
    SCNNode* node = [objectsParent childNodeWithName:nodeName recursively:YES];
    [node removeFromParentNode];
    result(nil);
}

- (void)onGetNodeBoundingBox:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSDictionary* geometryArguments = call.arguments[@"geometry"];
    SCNGeometry* geometry = [GeometryBuilder createGeometry:geometryArguments withDevice: _sceneView.device];
    SCNNode* node = [self getNodeWithGeometry:geometry fromDict:call.arguments];
    SCNVector3 minVector, maxVector;
    [node getBoundingBoxMin:&minVector max:&maxVector];
    
    result(@[[CodableUtils convertSimdFloat3ToString:SCNVector3ToFloat3(minVector)],
             [CodableUtils convertSimdFloat3ToString:SCNVector3ToFloat3(maxVector)]]
           );
}

#pragma mark - Lazy loads

-(ARConfiguration *)configuration {
    return _configuration;
}

#pragma mark - Scene tap event
- (void) handleTapFrom: (UITapGestureRecognizer *)recognizer
{
    [self debugNodeTree:nil level:0];
    
    if (![recognizer.view isKindOfClass:[ARSCNView class]])
        return;
    
    ARSCNView* sceneView = (ARSCNView *)recognizer.view;
    CGPoint touchLocation = self.forceUserTapOnCenter
        ? self.sceneView.center
        : [recognizer locationInView:sceneView];
    NSArray<SCNHitTestResult *> * hitResults = [sceneView hitTest:touchLocation options:@{}];
    if ([hitResults count] != 0) {
        for(SCNHitTestResult *n in hitResults) {
            SCNNode *node = [self getParentIfReferenceChild: n.node];
            if (node.name != nil) {
                [_channel invokeMethod: @"onNodeTap" arguments: node.name];
                return; // consume event here
            }
        }
    }

    NSArray<ARHitTestResult *> *arHitResults = [sceneView hitTest:touchLocation types: 0
//                                                + ARHitTestResultTypeFeaturePoint
//                                                + ARHitTestResultTypeEstimatedHorizontalPlane
//                                                + ARHitTestResultTypeEstimatedVerticalPlane
                                                + ARHitTestResultTypeExistingPlane
                                                + ARHitTestResultTypeExistingPlaneUsingExtent
                                                + ARHitTestResultTypeExistingPlaneUsingGeometry
                                                ];
    if ([arHitResults count] != 0) {
        NSMutableArray<NSDictionary*>* results = [NSMutableArray arrayWithCapacity:[arHitResults count]];
        for (ARHitTestResult* r in arHitResults) {
            [results addObject:[self getDictFromHitResult:r]];
        }
        [_channel invokeMethod: @"onPlaneTap" arguments: results];
    }
}

- (void) handlePinchFrom: (UIPinchGestureRecognizer *) recognizer
{
    if (![recognizer.view isKindOfClass:[ARSCNView class]])
        return;
    
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        ARSCNView* sceneView = (ARSCNView *)recognizer.view;
        CGPoint touchLocation = [recognizer locationInView:sceneView];
        NSArray<SCNHitTestResult *> * hitResults = [sceneView hitTest:touchLocation options:@{}];
        
        NSMutableArray<NSDictionary*>* results = [NSMutableArray arrayWithCapacity:[hitResults count]];
        for (SCNHitTestResult* r in hitResults) {
            if (r.node.name != nil) {
                [results addObject:@{@"name" : r.node.name, @"scale" : @(recognizer.scale)}];
            }
        }
        if ([results count] != 0) {
            [_channel invokeMethod: @"onNodePinch" arguments: results];
        }
        recognizer.scale = 1;
    }
}

- (void) handlePanFrom: (UIPanGestureRecognizer *) recognizer
{
    if (![recognizer.view isKindOfClass:[ARSCNView class]])
        return;
    
    if (recognizer.state == UIGestureRecognizerStateChanged) {
        ARSCNView* sceneView = (ARSCNView *)recognizer.view;
        CGPoint touchLocation = [recognizer locationInView:sceneView];
        CGPoint translation = [recognizer translationInView:sceneView];
        NSArray<SCNHitTestResult *> * hitResults = [sceneView hitTest:touchLocation options:@{}];
        
        NSMutableArray<NSDictionary*>* results = [NSMutableArray arrayWithCapacity:[hitResults count]];
        for (SCNHitTestResult* r in hitResults) {
            if (r.node.name != nil) {
                [results addObject:@{@"name" : r.node.name, @"x" : @(translation.x), @"y":@(translation.y)}];
            }
        }
        if ([results count] != 0) {
            [_channel invokeMethod: @"onNodePan" arguments: results];
        }
    }
}

#pragma mark - Parameters
- (void) updatePosition:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [objectsParent childNodeWithName:name recursively:YES];
    node.position = [DecodableUtils parseVector3:call.arguments];
    result(nil);
}

- (void) updateRotation:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [objectsParent childNodeWithName:name recursively:YES];
    node.rotation = [DecodableUtils parseVector4:call.arguments];
    result(nil);
}

- (void) updateEulerAngles:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [objectsParent childNodeWithName:name recursively:YES];
    node.eulerAngles = [DecodableUtils parseVector3:call.arguments];
    result(nil);
}

- (void) updateScale:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [objectsParent childNodeWithName:name recursively:YES];
    node.scale = [DecodableUtils parseVector3:call.arguments];
    result(nil);
}

- (void) updateIsHidden:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [objectsParent childNodeWithName:name recursively:YES];

    if ([call.arguments[@"isHidden"] boolValue]) {
        node.hidden = YES;
    } else {
        node.hidden = NO;
    }

    NSLog(@"node.isHidden:%d",node.isHidden);
    
    result(nil);
}

- (void) updateIsPlay:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [objectsParent childNodeWithName:name recursively:YES];

    NSLog(@"###### node.geometry.contents=%@", node.geometry.firstMaterial.diffuse.contents );
    if([node.geometry.firstMaterial.diffuse.contents isMemberOfClass:[SKScene class]]){
        SKScene *scene = node.geometry.firstMaterial.diffuse.contents;
        for (SKVideoNode *videoNode in scene.children){
            if ([call.arguments[@"isPlay"] boolValue]){
                videoNode.play;
            }else{
                videoNode.pause;
            }
        }
    }
    if([node.geometry.firstMaterial.diffuse.contents isMemberOfClass:[VideoView class]]){
        VideoView *videoView = node.geometry.firstMaterial.diffuse.contents;
        if ([call.arguments[@"isPlay"] boolValue]) {
            [videoView play];
        } else {
            [videoView pause];
        }
    }
    
    result(nil);
}

- (void) updateSingleProperty:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [objectsParent childNodeWithName:name recursively:YES];
    
    NSString* keyProperty = call.arguments[@"keyProperty"];
    id object = [node valueForKey:keyProperty];
    
    [object setValue:call.arguments[@"propertyValue"] forKey:call.arguments[@"propertyName"]];
    result(nil);
}

- (void) updateMaterials:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* name = call.arguments[@"name"];
    SCNNode* node = [objectsParent childNodeWithName:name recursively:YES];
    SCNGeometry* geometry = [GeometryBuilder createGeometry:call.arguments withDevice: _sceneView.device];
    node.geometry = geometry;
    result(nil);
}

// - (void) updateFaceGeometry:(FlutterMethodCall*)call andResult:(FlutterResult)result{
//     NSString* name = call.arguments[@"name"];
//     SCNNode* node = [self.sceneView.scene.rootNode childNodeWithName:name recursively:YES];
//     ARSCNFaceGeometry* geometry = (ARSCNFaceGeometry*)node.geometry;
//     ARFaceAnchor* faceAnchor = [self findAnchor:call.arguments[@"fromAnchorId"] inArray:self.sceneView.session.currentFrame.anchors];
    
//     [geometry updateFromFaceGeometry:faceAnchor.geometry];
    
//     result(nil);
// }

// -(ARFaceAnchor*)findAnchor:(NSString*)searchUUID inArray:(NSArray<ARAnchor *>*)array{
//     for (ARAnchor* obj in array){
//         if([[obj.identifier UUIDString] isEqualToString:searchUUID])
//             return (ARFaceAnchor*)obj;
//     }
//     return NULL;
// }

- (void) onGetLightEstimate:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    ARFrame* frame = self.sceneView.session.currentFrame;
    if (frame != nil && frame.lightEstimate != nil) {
        NSDictionary* res = @{
                              @"ambientIntensity": @(frame.lightEstimate.ambientIntensity),
                              @"ambientColorTemperature": @(frame.lightEstimate.ambientColorTemperature)
                              };
        result(res);
    }
    result(nil);
}

- (void) onProjectPoint:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    SCNVector3 point =  [DecodableUtils parseVector3:call.arguments[@"point"]];
    SCNVector3 projectedPoint = [_sceneView projectPoint:point];
    NSString* coded = [CodableUtils convertSimdFloat3ToString:SCNVector3ToFloat3(projectedPoint)];
    result(coded);
}

- (void) onCameraProjectionMatrix:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* coded = [CodableUtils convertSimdFloat4x4ToString:_sceneView.session.currentFrame.camera.projectionMatrix];
    result(coded);
}

- (void) onStartAnimation:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* key = call.arguments[@"key"];
    NSString* sceneName = call.arguments[@"sceneName"];
    NSString* animationIdentifier = call.arguments[@"animationIdentifier"];
    NSString* nodeName = call.arguments[@"nodeName"];
    SCNNode* node = [objectsParent childNodeWithName:nodeName recursively:YES];
    float repeatCount = [call.arguments[@"repeatCount"] floatValue];
    if (repeatCount < 0) {
        repeatCount = HUGE_VALF;
    } else {
        repeatCount ++;
    }

    NSURL* sceneURL = [[NSURL alloc] initFileURLWithPath: sceneName];
    SCNSceneSource* sceneSource = [SCNSceneSource sceneSourceWithURL:sceneURL options:nil];

    CAAnimation* animationObject = [sceneSource entryWithIdentifier:animationIdentifier withClass:[CAAnimation self]];
    animationObject.repeatCount = repeatCount;
    animationObject.fadeInDuration = 1;
    animationObject.fadeOutDuration = 0.5;
    [node addAnimation:animationObject forKey:key];
    
    result(nil);
}

- (void) onStopAnimation:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    NSString* key = call.arguments[@"key"];
    NSString* nodeName = call.arguments[@"nodeName"];
    SCNNode* node = [objectsParent childNodeWithName:nodeName recursively:YES];
    [node removeAnimationForKey:key blendOutDuration:0.5];
    result(nil);
}


- (void) screenCapture:(FlutterMethodCall*)call andResult:(FlutterResult)result{
    UIImage *image = [_sceneView snapshot];
    UIImageWriteToSavedPhotosAlbum(image, self, @selector(onCaptureImageSaved:didFinishSavingWithError:contextInfo:), nil);
}

- (void) toggleScreenRecord:(FlutterMethodCall*)call andResult:(FlutterResult)result {
    if (![[RPScreenRecorder sharedRecorder] isRecording]) {
        NSLog(@"toggleScreenRecord start");
        [[RPScreenRecorder sharedRecorder] startRecordingWithMicrophoneEnabled:NO handler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"failed to start recording, %@", [error localizedDescription]);
            }
        }];
    } else {
        NSLog(@"toggleScreenRecord stop");
        [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController * _Nullable previewViewController, NSError * _Nullable error) {
            if (error) {
                NSLog(@"failed to stop recording, %@", [error localizedDescription]);
            }
        }];
    }
}

- (void)startScreenRecord:(FlutterMethodCall*)call andResult:(FlutterResult)result {
    if (![[RPScreenRecorder sharedRecorder] isRecording]) {
        NSLog(@"startScreenRecord");
        [[RPScreenRecorder sharedRecorder] startRecordingWithMicrophoneEnabled:NO handler:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"failed to start recording, %@", [error localizedDescription]);
            }
        }];
    }
}

- (void)stopScreenRecord:(FlutterMethodCall*)call andResult:(FlutterResult)result {
    if ([[RPScreenRecorder sharedRecorder] isRecording]) {
        NSLog(@"stopScreenRecord");
        [[RPScreenRecorder sharedRecorder] stopRecordingWithHandler:^(RPPreviewViewController * _Nullable previewViewController, NSError * _Nullable error) {
            if (error) {
                NSLog(@"failed to stop recording, %@", [error localizedDescription]);
            }
        }];
    }
}

- (void) onCaptureImageSaved: (UIImage*)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    if (error) {
        NSLog(@"capture image save failure %@", error);
    } else {
        NSLog(@"capture image saved");
    }
}


- (BOOL)addNurieObject:(ARAnchor *)anchor node:(SCNNode *)node {
    if ([anchor isMemberOfClass:[ARImageAnchor class]]) {
        ARImageAnchor *image = (ARImageAnchor*)anchor;
        NSString* imageName = image.referenceImage.name;
        if ([nurieParams.allKeys containsObject:imageName]) {
            return true;
        }
    }
    return false;
}

- (BOOL)checkMarkerNurie:(ARAnchor*) anchor node:(SCNNode *)node {
    if (nurieFindingMode && [anchor isMemberOfClass:[ARImageAnchor class]]) {
        ARImageAnchor *image = (ARImageAnchor*)anchor;
        NSString* imageName = image.referenceImage.name;
        if ([nurieParams.allKeys containsObject:imageName]) {
            NurieParams* nurie = nurieParams[imageName];
            SCNNode* cameraNode = _sceneView.pointOfView;
            float hw = image.referenceImage.physicalSize.width / 2;
            float hh = image.referenceImage.physicalSize.height / 2;
            SCNVector3 ul = [self getScreenPoint:cameraNode pose:node x:-hw z:-hh];
            SCNVector3 ur = [self getScreenPoint:cameraNode pose:node x:hw z:-hh];
            SCNVector3 bl = [self getScreenPoint:cameraNode pose:node x:-hw z:hh];
            SCNVector3 br = [self getScreenPoint:cameraNode pose:node x:hw z:hh];
            SCNVector3 arr[] = {ul, ur, bl, br};

            if ([self validMarkerCorners:viewWidth height:viewHeight corners:arr]) {
                UIImage *uiImage = [self affine:[_sceneView snapshot] ul:ul ur:ur bl:bl br:br];
                nurie.image = uiImage;
                [self startFindingNurieMarker:false];
                NSLog(@"**** captured");
            }
            return true;
        }
    }
    return false;
}

- (BOOL) validMarkerCorners:(int)width height:(int)height corners:(SCNVector3[])corners {
    BOOL succeed = true;
    for(int i = 0; i < 4; i++) {
        SCNVector3 corner = corners[i];
        float prevX = prevMarkerCorners[i * 2];
        float prevY = prevMarkerCorners[i * 2 + 1];
        if (succeed && corner.x < 0 || corner.x > width || corner.y < 0 || corner.y > height ||
            abs(corner.x - prevX) > thresholdMarkerCorners || abs(corner.y - prevY) > thresholdMarkerCorners) {
            succeed = false;
            counterMarkerCorners = -1;
        }
    
        prevMarkerCorners[i * 2] = corner.x;
        prevMarkerCorners[i * 2 + 1] = corner.y;
    }
    if (++ counterMarkerCorners >= checkMarkerCorners) {
        counterMarkerCorners = 0;
        return true;
    }
    return false;
}

- (void) applyNurieTexture:(FlutterMethodCall*)call result:(FlutterResult)result {
    NSString* nurieStr = call.arguments[@"nurie"];
    NSString* nodeName = call.arguments[@"nodeName"];
    if (nurieStr != nil) {
        NurieParams* nurieParam = nurieParams[nurieStr];
        SCNNode* node = [objectsParent childNodeWithName:nodeName recursively:YES];
        if (nurieParam != nil && nurieParam.image != nil && node != nil) {
            UIImage* texture = nurieParam.image;
            [self setTexture:node texture:texture];
        }
    }
    result(nil);
}

- (void) setTexture:(SCNNode*)node texture:(UIImage*)texture {
    for (SCNMaterial* mat in node.geometry.materials) {
        [mat.diffuse setContents: texture];
    }
    for (SCNNode* childNode in node.childNodes){
        [self setTexture:childNode texture:texture];
    }
}

- (void) findNurieMarker:(FlutterMethodCall*)call result:(FlutterResult)result {
    BOOL isStart = call.arguments[@"isStart"];
    [self startFindingNurieMarker:isStart];
    result(nil);
}

- (void) startFindingNurieMarker:(BOOL)isStart {
    if (nurieFindingMode != isStart) {
        nurieFindingMode = isStart;
        NSDictionary* results = @{@"isStart" : @(isStart)};
        [_channel invokeMethod: @"nurieMarkerModeChanged" arguments: results];
        [objectsParent setHidden:isStart];
    }
}

- (void) addTransformableNode:(FlutterMethodCall*)call result:(FlutterResult)result {
    // need plane detection
    
}

#pragma mark - Utils
-(ARPlaneDetection) getPlaneFromNumber: (int) number {
  if (number == 0) {
    return ARPlaneDetectionNone;
  } else if (number == 1) {
    return ARPlaneDetectionHorizontal;
  }
  return ARPlaneDetectionVertical;
}

-(ARWorldAlignment) getWorldAlignmentFromNumber: (int) number {
    if (number == 0) {
        return ARWorldAlignmentGravity;
    } else if (number == 1) {
        return ARWorldAlignmentGravityAndHeading;
    }
    return ARWorldAlignmentCamera;
}

- (SCNNode *) getNodeWithGeometry:(SCNGeometry *)geometry fromDict:(NSDictionary *)dict {
    SCNNode* node;
    NSLog(@"**** getNodeWithGeometry");
    if ([dict[@"dartType"] isEqualToString:@"ARKitNode"]) {
        node = [SCNNode nodeWithGeometry:geometry];
    } else if ([dict[@"dartType"] isEqualToString:@"ARKitReferenceNode"]) {
        NSString* localPath = dict[@"object3DFileName"];
        NSURL* referenceURL = [[NSURL alloc] initFileURLWithPath: localPath];
        node = [SCNNode node];
        SCNScene *scene = [SCNScene sceneWithURL: referenceURL options: nil error: nil];
        for (SCNNode* childNode in scene.rootNode.childNodes){
            childNode.name = REFERENCE_CHILD_NODE;
            [node addChildNode:childNode];
        }
    } else if([dict[@"dartType"] isEqualToString:@"ARKitObjectNode"]){
        node = [SCNNode nodeWithGeometry:geometry];
        NSURL *localPath = [[NSURL alloc] initFileURLWithPath: dict[@"localPath"]];
        SCNScene *scene = [SCNScene sceneWithURL: localPath options: nil error: nil];
        for (id childNode in scene.rootNode.childNodes){
            [node addChildNode:childNode];
        }
    } else if([dict[@"dartType"] isEqualToString:@"ARKitVideoNode"]){
        //TODO VideoNode作成
        node = [SCNNode nodeWithGeometry:geometry];
    } else {
        return nil;
    }
    node.position = [DecodableUtils parseVector3:dict[@"position"]];
    
    if (dict[@"scale"] != nil) {
        node.scale = [DecodableUtils parseVector3:dict[@"scale"]];
    }
    if (dict[@"rotation"] != nil) {
        node.rotation = [DecodableUtils parseVector4:dict[@"rotation"]];
    }
    if (dict[@"eulerAngles"] != nil) {
        node.eulerAngles = [DecodableUtils parseVector3:dict[@"eulerAngles"]];
    }
    if (dict[@"name"] != nil) {
        node.name = dict[@"name"];
    }
    if (dict[@"physicsBody"] != nil) {
        NSDictionary *physics = dict[@"physicsBody"];
        node.physicsBody = [self getPhysicsBodyFromDict:physics];
    }
    if (dict[@"light"] != nil) {
        NSDictionary *light = dict[@"light"];
        node.light = [self getLightFromDict: light];
    }
    if (dict[@"isHidden"] != nil) {
        if ([dict[@"isHidden"] boolValue]) {
            node.hidden = YES;
        } else {
            node.hidden = NO;
        }
    }
    if (dict[@"isPlay"] != nil){
        //TODO
        // SKScene *scene = node.geometry.firstMaterial.diffuse.contents;
        // for (SKVideoNode *videoNode in scene.children){
        //     if ([dict[@"isPlay"] boolValue]){
        //         NSLog(@"###### videoPlay=%@", videoNode );
        //         videoNode.play;
        //     }else{
        //         videoNode.pause;
        //     }
        // }
        if([node.geometry.firstMaterial.diffuse.contents isMemberOfClass:[SKScene class]]){
            SKScene *scene = node.geometry.firstMaterial.diffuse.contents;
            for (SKVideoNode *videoNode in scene.children){
                if ([dict[@"isPlay"] boolValue]){
                    videoNode.play;
                }else{
                    videoNode.pause;
                }
            }
        }
        if([node.geometry.firstMaterial.diffuse.contents isMemberOfClass:[VideoView class]]){
            VideoView *videoView = node.geometry.firstMaterial.diffuse.contents;
            if ([dict[@"isPlay"] boolValue]) {
                [videoView play];
            } else {
                [videoView pause];
            }
        }
    }
    
    NSNumber* renderingOrder = dict[@"renderingOrder"];
    node.renderingOrder = [renderingOrder integerValue];
    
    return node;
}

- (SCNPhysicsBody *) getPhysicsBodyFromDict:(NSDictionary *)dict {
    NSNumber* type = dict[@"type"];
    
    SCNPhysicsShape* shape;
    if (dict[@"shape"] != nil) {
        NSDictionary* shapeDict = dict[@"shape"];
        if (shapeDict[@"geometry"] != nil) {
            shape = [SCNPhysicsShape shapeWithGeometry:[GeometryBuilder createGeometry:shapeDict[@"geometry"] withDevice:_sceneView.device] options:nil];
        }
    }
    
    SCNPhysicsBody* physicsBody = [SCNPhysicsBody bodyWithType:[type intValue] shape:shape];
    if (dict[@"categoryBitMask"] != nil) {
        NSNumber* mask = dict[@"categoryBitMask"];
        physicsBody.categoryBitMask = [mask unsignedIntegerValue];
    }
    
    return physicsBody;
}

- (SCNLight *) getLightFromDict:(NSDictionary *)dict {
    SCNLight* light = [SCNLight light];
    if (dict[@"type"] != nil) {
        SCNLightType lightType;
        int type = [dict[@"type"] intValue];
        switch (type) {
            case 0:
                lightType = SCNLightTypeAmbient;
                break;
            case 1:
                lightType = SCNLightTypeOmni;
                break;
            case 2:
                lightType =SCNLightTypeDirectional;
                break;
            case 3:
                lightType =SCNLightTypeSpot;
                break;
            case 4:
                lightType =SCNLightTypeIES;
                break;
            case 5:
                lightType =SCNLightTypeProbe;
                break;
            default:
                break;
        }
        light.type = lightType;
    }
    if (dict[@"temperature"] != nil) {
        NSNumber* temperature = dict[@"temperature"];
        light.temperature = [temperature floatValue];
    }
    if (dict[@"intensity"] != nil) {
        NSNumber* intensity = dict[@"intensity"];
        light.intensity = [intensity floatValue];
    }
    if (dict[@"spotInnerAngle"] != nil) {
        NSNumber* spotInnerAngle = dict[@"spotInnerAngle"];
        light.spotInnerAngle = [spotInnerAngle floatValue];
    }
    if (dict[@"spotOuterAngle"] != nil) {
        NSNumber* spotOuterAngle = dict[@"spotOuterAngle"];
        light.spotOuterAngle = [spotOuterAngle floatValue];
    }
    if (dict[@"color"] != nil) {
        NSNumber* color = dict[@"color"];
        light.color = [UIColor fromRGB: [color integerValue]];
    }
    return light;
}

- (void) addNodeToSceneWithGeometry:(SCNGeometry*)geometry andCall: (FlutterMethodCall*)call andResult:(FlutterResult)result{
    SCNNode* node = [self getNodeWithGeometry:geometry fromDict:call.arguments];
    if (call.arguments[@"parentNodeName"] != nil) {
        SCNNode *parentNode = [objectsParent childNodeWithName:call.arguments[@"parentNodeName"] recursively:YES];
        [parentNode addChildNode:node];
    } else {
        [objectsParent addChildNode:node];
    }
    result(nil);
}

- (SCNDebugOptions) getDebugOptions:(NSDictionary*)arguments{
    SCNDebugOptions debugOptions = SCNDebugOptionNone;
    if ([arguments[@"showFeaturePoints"] boolValue]) {
        debugOptions += ARSCNDebugOptionShowFeaturePoints;
    }
    if ([arguments[@"showWorldOrigin"] boolValue]) {
        debugOptions += ARSCNDebugOptionShowWorldOrigin;
    }
    return debugOptions;
}

- (NSDictionary*) getDictFromHitResult: (ARHitTestResult*) result {
    NSMutableDictionary* dict = [@{
             @"type": @(result.type),
             @"distance": @(result.distance),
             @"localTransform": [CodableUtils convertSimdFloat4x4ToString:result.localTransform],
             @"worldTransform": [CodableUtils convertSimdFloat4x4ToString:result.worldTransform]
             } mutableCopy];
    if (result.anchor != nil) {
        [dict setValue:[CodableUtils convertARAnchorToDictionary:result.anchor] forKey:@"anchor"];
    }
    return dict;
}

- (nullable SCNNode*) getParentIfReferenceChild:(SCNNode*) node {
    SCNNode* ret = node;
    if (ret.name == REFERENCE_CHILD_NODE) {
        ret = [self getParentIfReferenceChild:ret.parentNode];
    }
    return ret;
}

- (void) debugNodeTree:(nullable SCNNode*)node level:(int)level{
    if (node == nil) node = _sceneView.scene.rootNode;
    for(SCNNode* child in node.childNodes) {
        NSString* name = node.name;
        if (name == nil) name = @"null";
        NSLog(@"**** [%d] %@ - %@ ", level, name, node.class);
        [self debugNodeTree:child level:level + 1];
    }
}

@end

@implementation NurieParams

- (id) initWithName:(NSString *)name {
    if (self = [super init]) {
        _name = name;
    }
    return self;
}

@end

#import <Foundation/Foundation.h>
@import Scenekit;
@import ARKit;

@interface VideoNode : SCNNode

@property (retain, nonatomic) AVPlayer *player;

- (AVPlayer *)getPlayer;
+ (VideoNode *)videoNodeWithGeometry:(SCNGeometry *) geometry;
@end
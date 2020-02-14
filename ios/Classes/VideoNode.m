#import "VideoNode.h"
#import "FlutterArkit.h"
#import "GeometryBuilder.h"
#import "SceneViewDelegate.h"


@implementation VideoNode

@synthesize player;

- (AVPlayer *)getPlayer {
    return self.player;
}

+ (VideoNode *)videoNodeWithGeometry:(SCNGeometry *) geometry{
    node = [self nodeWithGeometry:geometry];
    return (VideoNode*)node;
}
@end
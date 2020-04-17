//
//  VideoRecorder.h
//  arkit_plugin
//
//  Created by 上江洲　智久 on 2020/04/13.
//

@import ARKit;
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoRecorder : NSObject

@property SCNView* _Nonnull view;

- (nonnull instancetype)initWithView:(nonnull SCNView*)view;

- (void) startRecord:(NSString*) path useAudio:(int)useAudio;
- (void) stopRecord;
- (void) toggleRecord:(NSString*) path useAudio:(int)useAudio;

@end

@interface UIView (Capture)

- (UIImage*) getCaptureImageFromView;

@end

@interface UIImage (Crop)

- (UIImage*)cropImage:(CGSize) croppedSize;

@end

NS_ASSUME_NONNULL_END

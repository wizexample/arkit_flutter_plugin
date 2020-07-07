//
//  VideoRecorder.h
//  arkit_plugin
//
//  Created by 上江洲　智久 on 2020/04/13.
//

@import ARKit;
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol VideoRecorderDelegate <NSObject>

- (void)recStateChanged:(int)recStatus;

@end


@interface VideoRecorder : NSObject<AVCaptureAudioDataOutputSampleBufferDelegate>

@property SCNView* _Nonnull view;
@property NSObject<VideoRecorderDelegate>* delegate;
@property bool micPermissionGranted;
@property BOOL isRecording;

- (nonnull instancetype)initWithView:(nonnull SCNView*)view;
- (void) startRecord:(NSString*) path useAudio:(int)useAudio resize:(BOOL) resize fps:(int) fps;
- (void) stopRecord;
- (void) toggleRecord:(NSString*) path useAudio:(int)useAudio resize:(BOOL) resize fps:(int) fps;
- (void) dispose;

@end

@interface UIView (Capture)

- (UIImage*) getCaptureImageFromView;

@end

@interface UIImage (Crop)

- (UIImage*)cropImage:(CGSize) croppedSize;

@end


NS_ASSUME_NONNULL_END

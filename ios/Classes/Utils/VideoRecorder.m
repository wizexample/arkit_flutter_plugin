//
//  VideoRecorder.m
//  arkit_plugin
//
//  Created by 上江洲　智久 on 2020/04/13.
//

#import "VideoRecorder.h"

CGFloat scale;
BOOL isRecording = false;
CADisplayLink* displayLink = nil;

int frameCount = 0;
int frameRate = 30;
NSString* movName;
NSURL* outputURL;
AVAssetWriter* videoWriter;
AVAssetWriterInput* writerInput;
int movPixelWidth;
int movPixelHeight;
CGSize movieSize;
AVAssetWriterInputPixelBufferAdaptor* adaptor;
dispatch_queue_t queue;

@implementation VideoRecorder

- (nonnull instancetype)initWithView:(nonnull SCNView*)view {
    if (self = [super init]) {
        _view = view;
        scale = UIScreen.mainScreen.scale;
    }
    return self;
}


- (void) startRecord:(NSString*) path {
    if (isRecording) return;
    NSLog(@"startScreenRecord");
    isRecording = true;
    [self initRecorderWithPath: path];

    displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(saveFrameImage)];
    displayLink.preferredFramesPerSecond = frameRate;
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void) stopRecord {
    if (!isRecording) return;
    NSLog(@"stopScreenRecord");
    isRecording = false;
    [displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self finishVideoWriting];
}

- (void) toggleRecord:(NSString*) path {
    NSLog(@"toggleScreenRecord");

}

- (void) initRecorderWithPath: (NSString*) path {
    frameCount = 0;
    movName = path;
    queue = dispatch_queue_create("makingMovie", DISPATCH_QUEUE_SERIAL);
    outputURL = [NSURL fileURLWithPath:movName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
//    videoWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeQuickTimeMovie error:nil];
    videoWriter = [AVAssetWriter assetWriterWithURL:outputURL fileType:AVFileTypeQuickTimeMovie error:nil];
    [self calcPixelSizeForMovie:_view.frame.size scale:scale];
    NSDictionary* outputSetting = @{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @(movPixelWidth), AVVideoHeightKey: @(movPixelHeight)};
    writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSetting];
    writerInput.expectsMediaDataInRealTime = true;
    [videoWriter addInput:writerInput];
    adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:@{
        (__bridge_transfer NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
        (__bridge_transfer NSString *)kCVPixelBufferWidthKey: @(movPixelWidth),
        (__bridge_transfer NSString *)kCVPixelBufferHeightKey: @(movPixelHeight)
    }];
}

- (void) saveFrameImage {
    @autoreleasepool {
        if (frameCount == 0) {
            if (videoWriter != nil) {
                if (!videoWriter.startWriting) {
                    NSLog(@"videoWriter startWriting is false");
                }
                [videoWriter startSessionAtSourceTime:kCMTimeZero];
                NSLog(@"making movie is started");
            } else {
                NSLog(@"videoWriter is nil");
            }
        }
        UIImage* img = _view.snapshot;
        dispatch_async(queue, ^{
            @autoreleasepool {
                [self appendImageToBuffer:img];
            }
        });
    }
}

- (void) calcPixelSizeForMovie: (CGSize) size scale:(CGFloat) scale {
    const int num = 16;
    int pixelWidth = (int)(size.width * scale);
    movPixelWidth = (pixelWidth / num) * num;
    int pixelHeight = (int)(size.height * scale);
    movPixelHeight = (pixelHeight / num) * num;
    movieSize = CGSizeMake(((CGFloat)movPixelWidth), ((CGFloat)movPixelHeight));
}

- (void) appendImageToBuffer:(UIImage*) image {
    if (adaptor == nil) return;
    frameCount ++;
    if (!adaptor.assetWriterInput.isReadyForMoreMediaData) return;
    CMTime frameTime = CMTimeMake((int64_t)(frameCount - 1), frameRate);
    UIImage* cropped = [image cropImage:movieSize];
    CVPixelBufferRef buffer = [self pixelBufferFromCGImage:cropped.CGImage];
    [adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
    CFRelease(buffer);
}

- (CVPixelBufferRef) pixelBufferFromCGImage:(CGImageRef) image {
    NSDictionary *options = @{
        (__bridge_transfer NSString *)kCVPixelBufferCGImageCompatibilityKey: @(true),
        (__bridge_transfer NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(true)
    };
    CVPixelBufferRef pxBuffer = nil;

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CVPixelBufferCreate(kCFAllocatorDefault,
                        width,
                        height,
                        kCVPixelFormatType_32ARGB,
                        (__bridge CFDictionaryRef)options,
                        &pxBuffer);

    CVPixelBufferLockBaseAddress(pxBuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxBuffer);

    size_t bitsPerComponent = 8;
    size_t bytesPerRow = 4 * width;
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 width,
                                                 height,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat) width, (CGFloat) height), image);
    CGContextRelease(context);
    CGColorSpaceRelease(rgbColorSpace);

    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);
    return pxBuffer;
}

- (void) finishVideoWriting {
    dispatch_async(queue, ^{
        [writerInput markAsFinished];
        [videoWriter endSessionAtSourceTime:CMTimeMake((int64_t)(frameCount - 1), frameRate)];
        [videoWriter finishWritingWithCompletionHandler:^{
            NSLog(@"movie created");
        }];
        CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(outputURL.path)) {
            UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path, self, nil, nil);
            NSLog(@"save to album");
        } else {
            NSLog(@"failure saving to album");
        }
    });
}

@end

@implementation UIView (Capture)

- (UIImage*) getCaptureImageFromView {
    CGSize contextSize = self.frame.size;
    UIGraphicsBeginImageContextWithOptions(contextSize, false, 0.0);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:false];
    UIImage* captureImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return captureImage;
}

@end


@implementation UIImage (Crop)

- (UIImage*)cropImage:(CGSize) croppedSize {
    CGFloat orgWidth = self.size.width;
    CGFloat orgHeight = self.size.height;
    
    CGFloat cropWidth = croppedSize.width;
    CGFloat cropHeight = croppedSize.height;
    
    CGRect cropRect = CGRectMake((orgWidth - cropWidth) / 2, (orgHeight - cropHeight) / 2, cropWidth, cropHeight);
    UIGraphicsBeginImageContextWithOptions(croppedSize, false, 0.0);
    [self drawInRect:cropRect];
    UIImage* croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return croppedImage;
}

@end

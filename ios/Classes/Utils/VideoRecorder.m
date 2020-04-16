//
//  VideoRecorder.m
//  arkit_plugin
//
//  Created by 上江洲　智久 on 2020/04/13.
//

#import "VideoRecorder.h"

const int frameRate = 30;

@interface VideoRecorder()

@property CGFloat scale;
@property BOOL isRecording;
@property CADisplayLink* displayLink;

@property int frameCount;
@property NSString* movName;
@property NSURL* outputURL;
@property AVAssetWriter* videoWriter;
@property AVAssetWriterInput* writerInput;
@property int movPixelWidth;
@property int movPixelHeight;
@property CGSize movieSize;
@property AVAssetWriterInputPixelBufferAdaptor* adaptor;
@property dispatch_queue_t queue;


@property AVAudioSession *session;

@end

@implementation VideoRecorder

- (nonnull instancetype)initWithView:(nonnull SCNView*)view {
    if (self = [super init]) {
        _view = view;
        _scale = UIScreen.mainScreen.scale;
    }
    return self;
}


- (void) startRecord:(NSString*) path {
    if (_isRecording) return;
    NSLog(@"startScreenRecord");
    _isRecording = true;
    [self initRecorderWithPath: path];

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(saveFrameImage)];
    _displayLink.preferredFramesPerSecond = frameRate;
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    // todo start record mic | output
}

- (void) stopRecord {
    if (!_isRecording) return;
    NSLog(@"stopScreenRecord");
    _isRecording = false;
    [_displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    // todo stop record audio

    [self finishVideoWriting];
}

- (void) toggleRecord:(NSString*) path {
    NSLog(@"toggleScreenRecord");

}

- (void) initRecorderWithPath: (NSString*) path {
    _frameCount = 0;
    _movName = path;
    _queue = dispatch_queue_create("makingMovie", DISPATCH_QUEUE_SERIAL);
    _outputURL = [NSURL fileURLWithPath:_movName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    _videoWriter = [AVAssetWriter assetWriterWithURL:_outputURL fileType:AVFileTypeQuickTimeMovie error:nil];
    [self calcPixelSizeForMovie:_view.frame.size scale:_scale];
    NSDictionary* outputSetting = @{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @(_movPixelWidth), AVVideoHeightKey: @(_movPixelHeight)};
    _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSetting];
    _writerInput.expectsMediaDataInRealTime = true;
    [_videoWriter addInput:_writerInput];
    _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_writerInput sourcePixelBufferAttributes:@{
        (__bridge_transfer NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
        (__bridge_transfer NSString *)kCVPixelBufferWidthKey: @(_movPixelWidth),
        (__bridge_transfer NSString *)kCVPixelBufferHeightKey: @(_movPixelHeight)
    }];
}

- (void) saveFrameImage {
    @autoreleasepool {
        if (_frameCount == 0) {
            if (_videoWriter != nil) {
                if (!_videoWriter.startWriting) {
                    NSLog(@"videoWriter startWriting is false");
                }
                [_videoWriter startSessionAtSourceTime:kCMTimeZero];
                NSLog(@"making movie is started");
            } else {
                NSLog(@"videoWriter is nil");
            }
        }
        UIImage* img = _view.snapshot;
        UIImage* cropped = [img cropImage:_movieSize];
        dispatch_async(_queue, ^{
            @autoreleasepool {
                [self appendImageToBuffer:cropped];
            }
        });
    }
}

- (void) calcPixelSizeForMovie: (CGSize) size scale:(CGFloat) scale {
    const int num = 16;
    int pixelWidth = (int)(size.width * scale);
    _movPixelWidth = (pixelWidth / num) * num;
    int pixelHeight = (int)(size.height * scale);
    _movPixelHeight = (pixelHeight / num) * num;
    _movieSize = CGSizeMake(((CGFloat)_movPixelWidth), ((CGFloat)_movPixelHeight));
}

- (void) appendImageToBuffer:(UIImage*) image {
    if (_adaptor == nil) return;
    _frameCount ++;
    if (!_adaptor.assetWriterInput.isReadyForMoreMediaData) return;
    CMTime frameTime = CMTimeMake((int64_t)(_frameCount - 1), frameRate);
    CVPixelBufferRef buffer = [self pixelBufferFromCGImage:image.CGImage];
    [_adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
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
    CFRelease(context);
    CFRelease(rgbColorSpace);
    
    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);
    return pxBuffer;
}

- (void) finishVideoWriting {
    dispatch_async(_queue, ^{
        [self->_writerInput markAsFinished];
        [self->_videoWriter endSessionAtSourceTime:CMTimeMake((int64_t)(self->_frameCount - 1), frameRate)];
        [self->_videoWriter finishWritingWithCompletionHandler:^{
            NSLog(@"movie created");
        }];
        CVPixelBufferPoolRelease(self->_adaptor.pixelBufferPool);
        
        // todo combine movie and auido
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self->_outputURL.path)) {
            UISaveVideoAtPathToSavedPhotosAlbum(self->_outputURL.path, self, nil, nil);
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

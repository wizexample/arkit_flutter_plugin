//
//  VideoRecorder.m
//  arkit_plugin
//
//  Created by 上江洲　智久 on 2020/04/13.
//

#import "VideoRecorder.h"

static const int frameRate = 30;
static NSURL* tempVideoURL;
static NSURL* tempAudioURL;
static const int USE_MIC = 1;

@interface VideoRecorder()

@property CGFloat scale;
@property BOOL isRecording;
@property CADisplayLink* displayLink;

@property int frameCount;
@property NSURL* outputURL;
@property AVAssetWriter* videoWriter;
@property AVAssetWriterInput* writerInput;
@property int movPixelWidth;
@property int movPixelHeight;
@property CGSize movieSize;
@property AVAssetWriterInputPixelBufferAdaptor* adaptor;
@property dispatch_queue_t queue;

@property AVAudioRecorder* audioRecorder;

@end

@implementation VideoRecorder

- (nonnull instancetype)initWithView:(nonnull SCNView*)view {
    if (self = [super init]) {
        _view = view;
        _scale = UIScreen.mainScreen.scale;
        tempVideoURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:@"/tempVideo.mp4"]];
        tempAudioURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingString:@"/tempAudio.caf"]];
    }
    return self;
}


- (void) startRecord:(NSString*) path useAudio:(int)useAudio {
    if (_isRecording) return;
    NSLog(@"startScreenRecord");
    _isRecording = true;
    [self clearFiles:path];
    [self initVideoRecorderWithPath: path];

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(saveFrameImage)];
    _displayLink.preferredFramesPerSecond = frameRate;
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    NSError *error = nil;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error != nil) {
        NSLog(@"Error when preparing audio session : %@", [error localizedDescription]);
        return;
    }
    [session setActive:YES error:&error];
    if (error != nil) {
        NSLog(@"Error when enabling audio session : %@", [error localizedDescription]);
        return;
    }
    if (useAudio == USE_MIC) {
        [self startRecordMic];
    }
}

- (void) startRecordMic {
    NSDictionary* audioSettings = @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @(44100.0),
        AVNumberOfChannelsKey: @(2),
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh),
        AVLinearPCMIsBigEndianKey: @(NO),
        AVLinearPCMIsFloatKey: @(NO),
    };
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:tempAudioURL settings:audioSettings error:nil];
    [_audioRecorder prepareToRecord];
    _audioRecorder.meteringEnabled = YES;
    [_audioRecorder record];
}

- (void) stopRecord {
    if (!_isRecording) return;
    NSLog(@"stopScreenRecord");
    _isRecording = false;
    [_displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    [self stopRecordMic];

    [self finishVideoWriting];
}

- (void) stopRecordMic {
    if ([_audioRecorder isRecording]) {
        [_audioRecorder stop];
    }
}

- (void) toggleRecord:(NSString*) path useAudio:(int)useAudio {
    if (!_isRecording) {
        [self startRecord:path useAudio:useAudio];
    } else {
        [self stopRecord];
    }
}

- (void) clearFiles: (NSString*) path {
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        [fm removeItemAtPath:path error:nil];
    }
    if ([fm fileExistsAtPath:path]) {
        [fm removeItemAtURL:tempAudioURL error:nil];
    }
    if ([fm fileExistsAtPath:path]) {
        [fm removeItemAtURL:tempVideoURL error:nil];
    }
}

- (void) initVideoRecorderWithPath: (NSString*) path {
    _frameCount = 0;
    _queue = dispatch_queue_create("makingMovie", DISPATCH_QUEUE_SERIAL);
    _outputURL = [NSURL fileURLWithPath:path];

    _videoWriter = [AVAssetWriter assetWriterWithURL:tempVideoURL fileType:AVFileTypeQuickTimeMovie error:nil];
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
            NSLog(@"movie created count:%d", self->_frameCount);
        }];
        CVPixelBufferPoolRelease(self->_adaptor.pixelBufferPool);

        [self combineMovieAndAudio];
    });
}

- (void) combineMovieAndAudio {
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:tempAudioURL.path]) {
        // combine
        AVMutableComposition* composition = [AVMutableComposition composition];
        AVMutableCompositionTrack* compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        NSError* error;
        
        AVURLAsset* vAsset = [[AVURLAsset alloc] initWithURL:tempVideoURL options:nil];
        CMTimeRange range = CMTimeRangeMake(kCMTimeZero, vAsset.duration);
        AVAssetTrack* videoTrack = [vAsset tracksWithMediaType:AVMediaTypeVideo][0];
        
        [compositionVideoTrack insertTimeRange:range ofTrack:videoTrack atTime:kCMTimeZero error:&error];
        AVMutableVideoCompositionInstruction* instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        instruction.timeRange = range;
        AVMutableVideoCompositionLayerInstruction* layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:compositionVideoTrack];
        
        AVURLAsset* sAsset = [[AVURLAsset alloc] initWithURL:tempAudioURL options:nil];
        AVAssetTrack* soundTrack = [sAsset tracksWithMediaType:AVMediaTypeAudio][0];
        AVMutableCompositionTrack* compositionSoundTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionSoundTrack insertTimeRange:range ofTrack:soundTrack atTime:kCMTimeZero error:&error];
        
        CGSize videoSize = videoTrack.naturalSize;
        CGAffineTransform transform = videoTrack.preferredTransform;
        if (transform.a == 0 && transform.d == 0 && (transform.b == -1.0 || transform.b == 1.0) && (transform.c == -1.0 || transform.c == 1.0)) {
            videoSize = CGSizeMake(videoSize.height, videoSize.width);
        }
        
        [layerInstruction setTransform:transform atTime:kCMTimeZero];
        instruction.layerInstructions = @[layerInstruction];
        
        AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
        videoComposition.renderSize = videoSize;
        videoComposition.instructions = @[instruction];
        videoComposition.frameDuration = CMTimeMake(1, frameRate);
        
        AVAssetExportSession* session = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
        session.outputURL = _outputURL;
        session.outputFileType = AVFileTypeQuickTimeMovie;
        session.videoComposition = videoComposition;
        [session exportAsynchronouslyWithCompletionHandler:^{
            if (session.status == AVAssetExportSessionStatusCompleted) {
                NSLog(@"combine complete");
            } else {
                NSLog(@"combine error %@", session.error);
            }
            // delete temporary files
            [fm removeItemAtURL:tempAudioURL error:nil];
            [fm removeItemAtURL:tempVideoURL error:nil];
            
            [self registerVideoToGallery];
        }];
    } else {
        // lacked audio file, move movie
        [fm moveItemAtURL:tempVideoURL toURL:_outputURL error:nil];
        NSLog(@"move complete");
        [self registerVideoToGallery];
    }
}

- (void) registerVideoToGallery {
    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self->_outputURL.path)) {
        UISaveVideoAtPathToSavedPhotosAlbum(self->_outputURL.path, self, nil, nil);
        NSLog(@"save to album");
    } else {
        NSLog(@"failure saving to album");
    }
    // todo notify method channel
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

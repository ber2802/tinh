#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>

static NSString *const FVSelectedVideoPath = @"/var/mobile/Media/VCam/video.mp4";
static NSString *const FVStorageDirectory = @"/var/mobile/Media/VCam";
static NSString *const FVCameraRollDirectory = @"/var/mobile/Media/DCIM/100APPLE";

static BOOL gCameraActive = NO;
static BOOL gReloadVideo = YES;
static NSTimeInterval gVolumeUpTime = 0;
static NSTimeInterval gVolumeDownTime = 0;
static AVPlayer *gPreviewPlayer = nil;
static AVPlayerLayer *gPreviewPlayerLayer = nil;
static NSString *gPreviewVideoPath = nil;

static UIViewController *FVTopViewController(void) {
    UIWindow *keyWindow = nil;

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) {
            continue;
        }

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }

        if (keyWindow != nil) {
            break;
        }
    }

    UIViewController *controller = keyWindow.rootViewController;
    while (controller.presentedViewController != nil) {
        controller = controller.presentedViewController;
    }
    return controller;
}

static void FVEnsureStorageDirectory(void) {
    [NSFileManager.defaultManager createDirectoryAtPath:FVStorageDirectory
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
}

static NSArray<NSString *> *FVMp4Files(void) {
    NSArray<NSString *> *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:FVCameraRollDirectory error:nil];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];

    for (NSString *name in names) {
        if ([name.pathExtension.lowercaseString isEqualToString:@"mp4"]) {
            [paths addObject:[FVCameraRollDirectory stringByAppendingPathComponent:name]];
        }
    }

    [paths sortUsingComparator:^NSComparisonResult(NSString *left, NSString *right) {
        NSDictionary *leftAttrs = [NSFileManager.defaultManager attributesOfItemAtPath:left error:nil];
        NSDictionary *rightAttrs = [NSFileManager.defaultManager attributesOfItemAtPath:right error:nil];
        NSDate *leftDate = leftAttrs[NSFileModificationDate] ?: [NSDate distantPast];
        NSDate *rightDate = rightAttrs[NSFileModificationDate] ?: [NSDate distantPast];
        return [rightDate compare:leftDate];
    }];

    return paths;
}

static void FVShowAlert(NSString *title, NSString *message) {
    UIViewController *presenter = FVTopViewController();
    if (presenter == nil || presenter.presentedViewController != nil) {
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static BOOL FVUseVideo(NSString *sourcePath) {
    if (sourcePath.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:sourcePath]) {
        return NO;
    }

    FVEnsureStorageDirectory();
    [NSFileManager.defaultManager removeItemAtPath:FVSelectedVideoPath error:nil];

    BOOL ok = [NSFileManager.defaultManager copyItemAtPath:sourcePath
                                                    toPath:FVSelectedVideoPath
                                                     error:nil];
    gReloadVideo = YES;
    gPreviewVideoPath = nil;
    return ok;
}

static BOOL FVHasSelectedVideo(void) {
    return [NSFileManager.defaultManager fileExistsAtPath:FVSelectedVideoPath];
}

static void FVEnsurePreviewPlayer(void) {
    if (!FVHasSelectedVideo()) {
        [gPreviewPlayer pause];
        [gPreviewPlayerLayer removeFromSuperlayer];
        gPreviewPlayer = nil;
        gPreviewPlayerLayer = nil;
        gPreviewVideoPath = nil;
        return;
    }

    if (gPreviewPlayer != nil && [gPreviewVideoPath isEqualToString:FVSelectedVideoPath]) {
        return;
    }

    gPreviewVideoPath = [FVSelectedVideoPath copy];
    NSURL *url = [NSURL fileURLWithPath:FVSelectedVideoPath];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    gPreviewPlayer = [AVPlayer playerWithPlayerItem:item];
    gPreviewPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    gPreviewPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:gPreviewPlayer];
    gPreviewPlayerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;

    [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:item
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(__unused NSNotification *note) {
                                                      [gPreviewPlayer seekToTime:kCMTimeZero];
                                                      [gPreviewPlayer play];
                                                  }];
    [gPreviewPlayer play];
}

static void FVUpdatePreviewOverlay(CALayer *previewLayer) {
    if (previewLayer == nil) {
        return;
    }

    if (!gCameraActive || !FVHasSelectedVideo()) {
        [gPreviewPlayer pause];
        gPreviewPlayerLayer.hidden = YES;
        return;
    }

    FVEnsurePreviewPlayer();
    if (gPreviewPlayerLayer == nil) {
        return;
    }

    gPreviewPlayerLayer.hidden = NO;
    gPreviewPlayerLayer.frame = previewLayer.bounds;
    if (gPreviewPlayerLayer.superlayer != previewLayer) {
        [gPreviewPlayerLayer removeFromSuperlayer];
        [previewLayer addSublayer:gPreviewPlayerLayer];
    }
    [gPreviewPlayer play];
}

static void FVShowVideoList(void) {
    UIViewController *presenter = FVTopViewController();
    if (presenter == nil || presenter.presentedViewController != nil) {
        return;
    }

    NSArray<NSString *> *videos = FVMp4Files();
    if (videos.count == 0) {
        FVShowAlert(@"FrontVCam", @"Khong thay file .mp4 trong /var/mobile/Media/DCIM/100APPLE");
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chon video"
                                                                   message:@"/var/mobile/Media/DCIM/100APPLE"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSUInteger limit = MIN(videos.count, 30);
    for (NSUInteger i = 0; i < limit; i++) {
        NSString *path = videos[i];
        [alert addAction:[UIAlertAction actionWithTitle:path.lastPathComponent
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
                                                    if (!FVUseVideo(path)) {
                                                        FVShowAlert(@"FrontVCam", @"Khong copy duoc video da chon.");
                                                    }
                                                }]];
    }

    if (videos.count > limit) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Chi hien 30 video moi nhat"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Huy"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];

    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover != nil) {
        popover.sourceView = presenter.view;
        popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
    }

    [presenter presentViewController:alert animated:YES completion:nil];
}

static void FVShowMainMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = FVTopViewController();
        if (presenter == nil || presenter.presentedViewController != nil) {
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"FrontVCam"
                                                                       message:@"Thay camera bang MP4"
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        [alert addAction:[UIAlertAction actionWithTitle:@"Chon video"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
                                                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)),
                                                                   dispatch_get_main_queue(), ^{
                                                                       FVShowVideoList();
                                                                   });
                                                }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Tat thay camera"
                                                  style:UIAlertActionStyleDestructive
                                                handler:^(__unused UIAlertAction *action) {
                                                    [NSFileManager.defaultManager removeItemAtPath:FVSelectedVideoPath error:nil];
                                                    gReloadVideo = YES;
                                                    gPreviewVideoPath = nil;
                                                    [gPreviewPlayer pause];
                                                    gPreviewPlayerLayer.hidden = YES;
                                                }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Huy"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];

        UIPopoverPresentationController *popover = alert.popoverPresentationController;
        if (popover != nil) {
            popover.sourceView = presenter.view;
            popover.sourceRect = CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
        }

        [presenter presentViewController:alert animated:YES completion:nil];
    });
}

@interface FVFrameSource : NSObject
+ (CMSampleBufferRef)newReplacementForSampleBuffer:(CMSampleBufferRef)sampleBuffer;
@end

@implementation FVFrameSource

+ (CMSampleBufferRef)newSampleBufferFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                             timing:(CMSampleTimingInfo)timing {
    if (pixelBuffer == nil) {
        return nil;
    }

    CMVideoFormatDescriptionRef format = nil;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &format);
    if (format == nil) {
        return nil;
    }

    CMSampleBufferRef sampleBuffer = nil;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                       pixelBuffer,
                                       true,
                                       nil,
                                       nil,
                                       format,
                                       &timing,
                                       &sampleBuffer);
    CFRelease(format);
    return sampleBuffer;
}

+ (CMSampleBufferRef)newReplacementForSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    static AVAssetReader *reader = nil;
    static AVAssetReaderTrackOutput *output = nil;

    if (!gCameraActive || sampleBuffer == nil ||
        ![NSFileManager.defaultManager fileExistsAtPath:FVSelectedVideoPath]) {
        return nil;
    }

    if (gReloadVideo || reader == nil || reader.status != AVAssetReaderStatusReading) {
        gReloadVideo = NO;

        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:FVSelectedVideoPath]];
        AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        if (track == nil) {
            return nil;
        }

        reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
        output = [[AVAssetReaderTrackOutput alloc] initWithTrack:track
                                                  outputSettings:@{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)}];
        output.alwaysCopiesSampleData = NO;
        if ([reader canAddOutput:output]) {
            [reader addOutput:output];
        }
        [reader startReading];
    }

    CMSampleBufferRef videoFrame = [output copyNextSampleBuffer];
    if (videoFrame == nil) {
        gReloadVideo = YES;
        return nil;
    }

    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(videoFrame);
    if (pixelBuffer == nil) {
        CFRelease(videoFrame);
        return nil;
    }

    CMSampleTimingInfo timing = {
        .duration = CMSampleBufferGetDuration(sampleBuffer),
        .presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
        .decodeTimeStamp = CMSampleBufferGetDecodeTimeStamp(sampleBuffer)
    };

    CMSampleBufferRef replacement = [self newSampleBufferFromPixelBuffer:pixelBuffer timing:timing];
    CFRelease(videoFrame);
    return replacement;
}

@end

%hook AVCaptureSession

- (void)addInput:(AVCaptureInput *)input {
    if ([input isKindOfClass:%c(AVCaptureDeviceInput)]) {
        AVCaptureDevice *device = [(AVCaptureDeviceInput *)input device];
        if ([device hasMediaType:AVMediaTypeVideo]) {
            gCameraActive = YES;
            gReloadVideo = YES;
        }
    }

    %orig;
}

- (void)startRunning {
    gCameraActive = YES;
    gReloadVideo = YES;
    %orig;
}

%end

%hook AVCaptureVideoPreviewLayer

- (void)layoutSublayers {
    %orig;
    FVUpdatePreviewOverlay((CALayer *)self);
}

- (void)setFrame:(CGRect)frame {
    %orig;
    FVUpdatePreviewOverlay((CALayer *)self);
}

%end

%hook AVCaptureVideoDataOutput

- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate
                          queue:(dispatch_queue_t)queue {
    if (delegate != nil && queue != nil) {
        static NSMutableSet<NSString *> *hookedClasses = nil;
        if (hookedClasses == nil) {
            hookedClasses = [NSMutableSet set];
        }

        Class delegateClass = [delegate class];
        NSString *className = NSStringFromClass(delegateClass);
        if (![hookedClasses containsObject:className]) {
            [hookedClasses addObject:className];

            __block void (*original)(id, SEL, AVCaptureOutput *, CMSampleBufferRef, AVCaptureConnection *) = nil;
            MSHookMessageEx(delegateClass,
                            @selector(captureOutput:didOutputSampleBuffer:fromConnection:),
                            imp_implementationWithBlock(^(id self, AVCaptureOutput *output, CMSampleBufferRef sampleBuffer, AVCaptureConnection *connection) {
                                CMSampleBufferRef replacement = [FVFrameSource newReplacementForSampleBuffer:sampleBuffer];
                                if (original != NULL) {
                                    original(self,
                                             @selector(captureOutput:didOutputSampleBuffer:fromConnection:),
                                             output,
                                             replacement != nil ? replacement : sampleBuffer,
                                             connection);
                                }
                                if (replacement != nil) {
                                    CFRelease(replacement);
                                }
                            }),
                            (IMP *)&original);
        }
    }

    %orig;
}

%end

%group VolumeMenu

%hook VolumeControl

- (void)increaseVolume {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (gVolumeDownTime > 0 && now - gVolumeDownTime < 1.0) {
        FVShowMainMenu();
    }
    gVolumeUpTime = now;
    %orig;
}

- (void)decreaseVolume {
    NSTimeInterval now = NSDate.date.timeIntervalSince1970;
    if (gVolumeUpTime > 0 && now - gVolumeUpTime < 1.0) {
        FVShowMainMenu();
    }
    gVolumeDownTime = now;
    %orig;
}

%end

%end

%ctor {
    %init;

    Class volumeClass = NSClassFromString(@"SBVolumeControl");
    if (volumeClass == Nil) {
        volumeClass = NSClassFromString(@"VolumeControl");
    }
    if (volumeClass != Nil) {
        %init(VolumeMenu, VolumeControl = volumeClass);
    }
}

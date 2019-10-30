//
//  ScreenRecorder.m
//  ScreenRecorder
//
//  Created by JinYoung Lee on 2017. 12. 14..
//  Copyright © 2017년 JinYoung Lee. All rights reserved.
//

#import "ScreenRecorder.h"
#import "ScreenRecorder-Swift.h"

extern void UnitySendMessage(const char *, const char *, const char *);

@interface ScreenRecorder() <TbRecordingObserver>
@end

@implementation ScreenRecorder

+(instancetype)sharedInstance
{
    static dispatch_once_t once;
    static ScreenRecorder *sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc]init];
    });
    
    return sharedInstance;
}

-(void)savePhoto:(NSURL *)path withListener:(void (^)(BOOL success, NSError * error))successListener
{
    [[ScreenRecorderModule sharedInstance] startDownloadVideoWithPath:path completeHandler:successListener];
}

-(void)onStartRecord
{
    _onRecording = YES;
    _m_currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    _lockOrientation = YES;
    UnitySendMessage([_bridgeName UTF8String], "StartRecordingSuccessCallback", "");
}

-(void)onStartRecordWithError:(NSString *)error
{
    _onRecording = NO;
    _lockOrientation = NO;
    UnitySendMessage([_bridgeName UTF8String], "StartRecordingFailCallback", error.UTF8String);
    
}

-(void)onStopRecord
{
    _onRecording = NO;
    _lockOrientation = NO;
    UnitySendMessage([_bridgeName UTF8String], "StopRecordingSuccessCallback", "");
}

-(void)onStopRecordWithError:(NSString *)error
{
    _onRecording = NO;
    _lockOrientation = NO;
    UnitySendMessage([_bridgeName UTF8String], "StopRecordingFailCallback", error.UTF8String);
}

-(void)pauseRecord:(BOOL)pause
{
    if (pause) {
        [[ScreenRecorderModule sharedInstance] pauseRecord];
    } else {
        [[ScreenRecorderModule sharedInstance] resumeRecord];
    }
}

-(NSURL *)getOutputPath
{
    return [[ScreenRecorderModule sharedInstance] getOutputPath];
}

-(void)startRecord
{
    [[ScreenRecorderModule sharedInstance] bindObserverWithObserver:[ScreenRecorder sharedInstance]];
    [[ScreenRecorderModule sharedInstance] startRecording];
}

-(void)stopRecord
{
    [[ScreenRecorderModule sharedInstance] stopRecording];
}

-(void)cancelRecord
{
    [[ScreenRecorderModule sharedInstance] cancelRecord];
}

-(void)saveToStorage:(void (^)(BOOL success, NSError *error, NSString *path))successListener
{
    [[ScreenRecorderModule sharedInstance] moveTempToStorageFileWithCompleteHandler:successListener];
}

-(void)setMicEnabled:(BOOL)enable
{
    [[ScreenRecorderModule sharedInstance] setWillEnableMic:enable];
}

void _startRecording()
{
    [[ScreenRecorder sharedInstance] startRecord];
}

void _stopRecording()
{
    [[ScreenRecorder sharedInstance] stopRecord];
}

void _cancelRecording()
{
    [[ScreenRecorder sharedInstance] cancelRecord];
}

void _setUpRecordingDelegate(const char * bridgeName)
{
    [ScreenRecorder sharedInstance].bridgeName = [NSString stringWithFormat:@"%s", bridgeName];
}

void _setUpScreenSize(const char * screenSize)
{
    [ScreenRecorder sharedInstance].screenSize = [NSString stringWithFormat:@"%s", screenSize];
}

void _setMicEnabled(BOOL enable)
{
    [[ScreenRecorder sharedInstance] setMicEnabled:enable];
}

@end

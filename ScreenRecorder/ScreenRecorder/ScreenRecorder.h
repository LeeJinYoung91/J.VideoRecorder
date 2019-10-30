//
//  ScreenRecorder.h
//  ScreenRecorder
//
//  Created by JinYoung Lee on 2017. 12. 14..
//  Copyright © 2017년 JinYoung Lee. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ScreenRecorder : NSObject
@property (nonatomic) BOOL onRecording;
@property (nonatomic) NSString *bridgeName;
@property (nonatomic) NSURL *localVideoPath;
@property UIInterfaceOrientation m_currentOrientation;
@property (nonatomic) BOOL lockOrientation;
@property (nonatomic) NSString *screenSize;

+(instancetype)sharedInstance;

-(void)savePhoto:(NSURL *)path withListener:(void (^)(BOOL success, NSError * error))successListener;
-(void)startRecord;
-(void)stopRecord;
-(void)cancelRecord;
-(void)pauseRecord:(BOOL)pause;
-(void)setMicEnabled:(BOOL)enable;
-(void)saveToStorage:(void (^)(BOOL success, NSError * error, NSString * path))successListener;
-(NSURL *)getOutputPath;

void _startRecording(void);
void _stopRecording(void);
void _cancelRecording(void);
void _setUpRecordingDelegate(const char * brdigeName);
void _setUpScreenSize(const char * screenSize);
@end


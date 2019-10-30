//
//  TbRecordingObserver.swift
//  ScreenRecorder
//
//  Created by JinYoung Lee on 2018. 1. 29..
//  Copyright © 2018년 JinYoung Lee. All rights reserved.
//

import Foundation

@objc protocol TbRecordingObserver {
    func onStartRecord()
    func onStartRecordWithError(_ error:String)
    func onStopRecord()
    func onStopRecordWithError(_ error:String)
}

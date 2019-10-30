
//  ScreenRecorderModule.swift
//  ScreenRecorder
//
//  Created by JinYoung Lee on 2017. 12. 14..
//  Copyright © 2017년 JinYoung Lee. All rights reserved.
//

import Foundation
import AVFoundation
import ReplayKit
import Photos

@objc(ScreenRecorderModule)
@objcMembers public class ScreenRecorderModule: NSObject, RPScreenRecorderDelegate, AVAudioRecorderDelegate {
    enum CALL_BACK_TYPE: Int {
        case CALLBACK_START = 0
        case CALLBACK_START_FAIL
        case CALLBACK_STOP
        case CALLBACK_STOP_FAIL
        case CALLBACK_CANCEL
        case CALLBACK_CANCEL_FAIL
    }
    
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var avAssetWriter: AVAssetWriter?
    private var moviePath: String?
    private var outputPath: URL?
    private var temporarySavedPath: URL?
    private var fileName: String?
    private var firstCheckPermission: Bool = false
    private var observers: [TbRecordingObserver]? = [TbRecordingObserver]()
    private var pauseRecording: Bool = false
    private var isStopRecording: Bool = false
    private var willRecordWithMic: Bool = true
    static let sharedInstance: ScreenRecorderModule = ScreenRecorderModule()
    private final let albumTitle = "VideoRecorder"
    private var micRecorder: AVAudioRecorder?
    
    func bindObserver(observer:TbRecordingObserver) {
        if observers == nil {
            observers = [TbRecordingObserver]()
        }
        observers?.append(observer)
    }
    
    func removeAllObservers() {
        observers?.removeAll()
    }
    
    func pauseRecord() {
        pauseRecording = true
    }
    
    func resumeRecord() {
        pauseRecording = false
    }
    
    var willEnableMic: Bool {
        set {
            willRecordWithMic = newValue
        } get {
            return willRecordWithMic
        }
    }
    
    func readyToWriterAVAsset(){
        let recordScreenSize:CGSize = UIScreen.main.bounds.size
        let scale:CGFloat = UIScreen.main.scale
        let bitrate = (recordScreenSize.width * scale) * (recordScreenSize.height * scale) * 10
        
        let videoCompress:NSDictionary = [AVVideoAverageBitRateKey: bitrate,
                                          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                          AVVideoH264EntropyModeKey: AVVideoH264EntropyModeKey,
                                          AVVideoMaxKeyFrameIntervalKey: 60,
                                          AVVideoMaxKeyFrameIntervalDurationKey: 0]
        
        let videoSetting:[String:Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                         AVVideoWidthKey: NSNumber(value: ceilf(Float(recordScreenSize.width / 16)) * 16 * Float(scale)),
                                         AVVideoHeightKey: NSNumber(value: ceilf(Float(recordScreenSize.height / 16)) * 16 * Float(scale)),
                                         AVVideoCompressionPropertiesKey: videoCompress];
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSetting)
        
        audioInput = nil
        var channelLayout = AudioChannelLayout()
        if willRecordWithMic {
            let audioSetting:[String:Any] = [AVFormatIDKey: UInt(kAudioFormatMPEG4AAC),
                                             AVSampleRateKey: 12000,
                                             AVNumberOfChannelsKey: 1,
                                             AVEncoderAudioQualityForVBRKey: AVAudioQuality.high.rawValue]
            let audioURL = getMicRecordFileURL()
            if FileManager.default.fileExists(atPath: audioURL.path) {
                try? FileManager.default.removeItem(atPath: audioURL.path)
                
            }
            
            micRecorder = try? AVAudioRecorder(url: audioURL, settings: audioSetting)
            micRecorder?.delegate = self
        } else {
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
            let audioSetting:[String:Any] = [AVFormatIDKey: UInt(kAudioFormatMPEG4AAC),
                                             AVSampleRateKey: 44100,
                                             AVNumberOfChannelsKey: 2,
                                             AVChannelLayoutKey: NSData(bytes:&channelLayout, length:MemoryLayout.size(ofValue: channelLayout))]
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSetting)
            micRecorder = nil
        }
        
        let filePath = getTemporarySavedFilePath()
        if (FileManager.default.fileExists(atPath: filePath)) {
            do {
                try FileManager.default.removeItem(atPath: filePath)
            } catch let error as NSError {
                NSLog("delete error: %@", error.description)
            }
        }
        
        outputPath = URL(fileURLWithPath: filePath)
        
        do{
            try self.avAssetWriter = AVAssetWriter(outputURL: self.outputPath!, fileType: AVFileType.mp4)
        } catch let error as NSError {
            NSLog("AssetWriter Error: %@", error.description)
        }
        videoInput?.expectsMediaDataInRealTime = true
        audioInput?.expectsMediaDataInRealTime = true
        videoInput?.mediaTimeScale = 60
        avAssetWriter?.movieTimeScale = 60
        
        if (avAssetWriter?.canAdd(videoInput!))! {
            avAssetWriter?.add(videoInput!)
        }
        
        if !willRecordWithMic {
            if (avAssetWriter?.canAdd(audioInput!))! {
                avAssetWriter?.add(audioInput!)
            }
        }
    }
    
    private func getTemporarySavedFilePath() -> String {
        let tempFolderPath = NSTemporaryDirectory().appending("/TemporaryMovies")
        if !FileManager.default.fileExists(atPath: tempFolderPath) {
            do {
                try FileManager.default.createDirectory(atPath: tempFolderPath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
                print("Create Temporary Directory Error")
            }
        }
        return tempFolderPath.appending("/temp.mp4")
    }
    
    private func getExportURLPath() -> String {
        let tempFolderPath = NSTemporaryDirectory().appending("/TemporaryMovies")
        if !FileManager.default.fileExists(atPath: tempFolderPath) {
            do {
                try FileManager.default.createDirectory(atPath: tempFolderPath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
                print("Create Temporary Directory Error")
            }
        }
        
        return tempFolderPath.appending("/export_temp.mp4")
    }
    
    private func getSavedFileURL() -> String {
        moviePath = ((NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true) as NSArray).object(at: 0) as! NSString).appendingPathComponent("RecordMovies")
        
        if !(FileManager.default.fileExists(atPath: self.moviePath!)) {
            do {
                try FileManager.default.createDirectory(atPath: self.moviePath!, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                print(String(format: "Create Directory Error: %@", error.description))
            }
        }
        
        let dateFormatter:DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-hh-mm-ss"
        let timeString:String = dateFormatter.string(from: Date())
        let filename = String(format: "video_%@.mp4", timeString)
        fileName = filename
        let documentPath:String = String(format: "%@/%@", self.moviePath!, filename)
        return documentPath
    }
    
    @objc func moveTempToStorageFile(completeHandler:((Bool, Error?, String)->Void)?) {
        do {
            if FileManager.default.fileExists(atPath: getSavedFileURL()) {
                try? FileManager.default.removeItem(atPath: getSavedFileURL())
            }
            try FileManager.default.copyItem(atPath: getTemporarySavedFilePath(), toPath: getSavedFileURL())
            createThumbnail(completeHandler: completeHandler)
        } catch {
            completeHandler?(false, nil, getSavedFileURL())
        }
    }
    
    private func createThumbnail(completeHandler:((Bool, Error?, String)->Void)?) {
        let width = UIScreen.main.bounds.width * UIScreen.main.scale
        let height = UIScreen.main.bounds.height * UIScreen.main.scale
        let asset:AVURLAsset = AVURLAsset(url: URL(fileURLWithPath: getSavedFileURL()))
        let generator:AVAssetImageGenerator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: width, height: height)
        do {
            let imgRef = try generator.copyCGImage(at: CMTime(seconds: 0, preferredTimescale: 1), actualTime: nil)
            let videoName = getSavedFileURL().split(separator: "/").last
            if let imgData = UIImage(cgImage: imgRef).jpegData(compressionQuality: 0.7) {
                if let endIndex = videoName?.lastIndex(of: ".") {
                    if let imageName = videoName?[..<endIndex] {
                        guard let directoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first?.appending("/MovieThumbnail") else {
                            completeHandler?(false, nil, getSavedFileURL())
                            return
                        }
                        
                        do {
                            if !FileManager.default.fileExists(atPath: directoryPath){
                                try FileManager.default.createDirectory(atPath: directoryPath, withIntermediateDirectories: true, attributes: nil)
                            }
                        } catch {
                            completeHandler?(false, nil, getSavedFileURL())
                        }
                        
                        let savedPath = directoryPath.appending(String(format:"/%@.jpeg", imageName.description))
                        if FileManager.default.fileExists(atPath: savedPath) {
                            try? FileManager.default.removeItem(atPath: savedPath)
                        }
                        print(savedPath)
                        do {
                            try imgData.write(to: URL(fileURLWithPath: savedPath))
                            completeHandler?(true, nil, getSavedFileURL())
                        } catch {
                            completeHandler?(false, nil, getSavedFileURL())
                        }
                    }
                }
            }
        } catch {
            completeHandler?(false, nil, getSavedFileURL())
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func getMicRecordFileURL() -> URL {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recording.m4a")
    }
    
    public func startRecording(){
        let screenRecorder:RPScreenRecorder = RPScreenRecorder.shared()
        screenRecorder.delegate = self
        var frameCount = 0;
        readyToWriterAVAsset()
        if #available(iOS 11.0, *) {
            if screenRecorder.isAvailable {
                if self.willRecordWithMic {
                    try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
                    try? AVAudioSession.sharedInstance().setActive(true, options: AVAudioSession.SetActiveOptions())
                    if AVAudioSession.sharedInstance().recordPermission == .granted {
                        self.micRecorder?.record()
                    }
                }
                screenRecorder.startCapture(handler: {(sampleBuffer, bufferType, error) in
                    guard error == nil else {
                        return
                    }
                    
                    guard !(self.pauseRecording) && !(self.isStopRecording) && screenRecorder.isRecording else {
                        return
                    }
                    
                    if (frameCount == 0 && bufferType != .video) {
                        return;
                    }
                    
                    guard CMSampleBufferDataIsReady(sampleBuffer) && CMSampleBufferIsValid(sampleBuffer) else {
                        return
                    }
                    
                    if let sample:CMTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) as CMTime? {
                        if CMTIME_IS_VALID(sample) {
                            if self.avAssetWriter?.status == AVAssetWriter.Status.unknown {
                                if let started = self.avAssetWriter?.startWriting() {
                                    if !started {
                                        return
                                    }
                                    self.avAssetWriter?.startSession(atSourceTime: sample)
                                } else {
                                    return
                                }
                            }
                            
                            if self.avAssetWriter?.status == AVAssetWriter.Status.failed {
                                self.forceStopRecordMic()
                                self.forceStopRecord()
                                let erDescription = "notify_unable_save"
                                self.onStartRecordWithError(erDescription)
                                return
                            }
                            
                            if self.avAssetWriter?.status == AVAssetWriter.Status.writing {
                                var assetInput:AVAssetWriterInput?
                                switch bufferType {
                                case .video:
                                    assetInput = self.videoInput
                                    break
                                case .audioApp:
                                    guard !self.willRecordWithMic else {
                                        break
                                    }
                                    assetInput = self.audioInput
                                    break
                                case .audioMic:
                                    break
                                }
                                
                                if let writer = assetInput {
                                    if writer.isReadyForMoreMediaData {
                                        writer.append(sampleBuffer)
                                    }
                                }
                                frameCount += 1
                            } else {
                                self.forceStopRecordMic()
                                self.forceStopRecord()
                                self.onStartRecordWithError("notify_unable_save")
                            }
                        }
                    }
                }, completionHandler: { [weak self] (error) in
                    (error == nil) ? self?.onStartRecord() : self?.onStartRecordWithError("notify_unable_save")
                    if error != nil {
                        self?.forceStopRecordMic()
                    }
                })
            } else {
                onStartRecordWithError("recording_not_available")
            }
        } else{
            onStartRecordWithError("device_version_not_support")
        }
    }
    
    
    
    public func forceStopRecord() {
        self.isStopRecording = true
        if #available(iOS 11.0, *) {
            let screenRecorder:RPScreenRecorder = RPScreenRecorder.shared()
            screenRecorder.stopCapture(handler: { [weak self](error) in
                self?.avAssetWriter?.cancelWriting()
                self?.onStopRecordWithError("force_stopRecord")
            })
        }
    }
    
    public func cancelRecord() {
        onStopRecordWithError("cancelRecord")
        forceStopRecordMic()
        forceStopRecord()
    }
    
    private func forceStopRecordMic() {
        if willRecordWithMic {
            micRecorder?.stop()
            try? AVAudioSession.sharedInstance().setCategory(.playback)
        }
    }
    
    public func stopRecording(){
        self.isStopRecording = true
        if avAssetWriter?.status == AVAssetWriter.Status.unknown {
            forceStopRecordMic()
            forceStopRecord()
            onStopRecordWithError("notify_unable_save")
            return
        }
        
        let screenRecorder:RPScreenRecorder = RPScreenRecorder.shared()
        guard screenRecorder.isRecording else {
            if avAssetWriter?.status == AVAssetWriter.Status.writing {
                avAssetWriter?.cancelWriting()
            }
            onStopRecordWithError("recording_error")
            return
        }
        
        guard screenRecorder.isAvailable else {
            avAssetWriter?.cancelWriting()
            onStopRecordWithError("recording_not_available")
            return
        }
        
        if #available(iOS 11.0, *) {
            screenRecorder.stopCapture { (error) in
                if error != nil {
                    self.onStopRecordWithError((error?.localizedDescription)!)
                    return
                }
                
                if self.willRecordWithMic {
                    self.micRecorder?.stop()
                }
                if self.avAssetWriter?.status == AVAssetWriter.Status.writing {
                    self.videoInput?.markAsFinished()
                    if !self.willRecordWithMic {
                        self.audioInput?.markAsFinished()
                    }
                    self.avAssetWriter?.finishWriting(completionHandler: {
                        if self.willRecordWithMic && AVAudioSession.sharedInstance().recordPermission == .granted {
                            self.mergeFilesWithUrl()
                        } else {
                            self.onStopRecord()
                        }
                    })
                } else {
                    self.avAssetWriter?.cancelWriting()
                    self.onStopRecordWithError("fail_write_movie")
                }
            }
        }
    }
    
    private func addInstruction() {
        let videoComposition : AVMutableComposition = AVMutableComposition()
        var mutableCompositionVideoTrack : [AVMutableCompositionTrack] = []
        var mutableCompositionAudioTrack : [AVMutableCompositionTrack] = []
        
        let videoAsset : AVAsset = AVAsset(url: getOutputPath())
        
        guard let videoAssetTrack : AVAssetTrack = videoAsset.tracks(withMediaType: .video).first else {
            onStopRecordWithError("notify_unable_save")
            return
        }
        
        guard let audioAssetTrack : AVAssetTrack = videoAsset.tracks(withMediaType: .audio).first else {
            onStopRecord()
            return
        }
        
        mutableCompositionVideoTrack.append(videoComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        mutableCompositionAudioTrack.append(videoComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        
        try? mutableCompositionVideoTrack.first?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAssetTrack.timeRange.duration), of: videoAssetTrack, at: .zero)
        try? mutableCompositionAudioTrack.first?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAssetTrack.timeRange.duration), of: audioAssetTrack, at: .zero)
        
        let mainCompositionInst = AVMutableVideoComposition()
        mainCompositionInst.frameDuration = CMTimeMake(value: 1, timescale: 60)
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: videoAsset.duration)
        
        let transformInstruction:AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction.init(assetTrack: videoAssetTrack)
        
        mainCompositionInst.renderSize = videoAssetTrack.naturalSize
        mainInstruction.layerInstructions = [transformInstruction]
        mainCompositionInst.instructions = [mainInstruction]
        
        let savePathUrl = URL(fileURLWithPath: getExportURLPath())
        if FileManager.default.fileExists(atPath: savePathUrl.path) {
            try? FileManager.default.removeItem(at: savePathUrl)
        }
        
        let assetExport: AVAssetExportSession = AVAssetExportSession(asset: videoComposition, presetName: AVAssetExportPresetHighestQuality)!
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = savePathUrl
        assetExport.shouldOptimizeForNetworkUse = true
        assetExport.videoComposition = mainCompositionInst
        
        if FileManager.default.fileExists(atPath: savePathUrl.path) {
            try? FileManager.default.removeItem(at: savePathUrl)
        }
        
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        assetExport.exportAsynchronously {
            switch assetExport.status {
            case .completed:
                self.outputPath = savePathUrl
                break
            case .failed:
                break
            case .cancelled:
                break
            default:
                break
            }
            self.onStopRecord()
        }
    }
    
    private func mergeFilesWithUrl()
    {
        let mixComposition : AVMutableComposition = AVMutableComposition()
        var mutableCompositionVideoTrack : [AVMutableCompositionTrack] = []
        var mutableCompositionAudioTrack : [AVMutableCompositionTrack] = []
        
        let videoAsset : AVAsset = AVAsset(url: getOutputPath())
        let audioAsset : AVAsset = AVAsset(url: getMicRecordFileURL())
        
        guard let videoAssetTrack : AVAssetTrack = videoAsset.tracks(withMediaType: .video).first else {
            onStopRecordWithError("notify_unable_save")
            return
        }
        
        guard let audioAssetTrack : AVAssetTrack = audioAsset.tracks(withMediaType: .audio).first else {
            onStopRecord()
            return
        }
        
        mutableCompositionVideoTrack.append(mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        mutableCompositionAudioTrack.append(mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!)
        
        try? mutableCompositionVideoTrack.first?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAssetTrack.timeRange.duration), of: videoAssetTrack, at: .zero)
        try? mutableCompositionAudioTrack.first?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAssetTrack.timeRange.duration), of: audioAssetTrack, at: .zero)
        
        let savePathUrl = URL(fileURLWithPath: getExportURLPath())
        if FileManager.default.fileExists(atPath: savePathUrl.path) {
            try? FileManager.default.removeItem(at: savePathUrl)
        }
        
        let assetExport: AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = savePathUrl
        assetExport.shouldOptimizeForNetworkUse = true
        
        if FileManager.default.fileExists(atPath: savePathUrl.path) {
            try? FileManager.default.removeItem(at: savePathUrl)
        }
        
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        assetExport.exportAsynchronously {
            switch assetExport.status {
            case .completed:
                self.outputPath = savePathUrl
                break
            default:
                break
            }
            self.onStopRecord()
        }
    }
    
    func getOutputPath() -> URL {
        return outputPath!
    }
    
    func getFileName() -> String {
        return fileName!
    }
    
    public func startDownloadVideo(path: URL, completeHandler:((Bool, Error?)->Void)?) {
        getAlbum { (assetCollection) in
            PHPhotoLibrary.shared().performChanges({
                let assetChangeRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: path)
                let assetPlaceholder = assetChangeRequest?.placeholderForCreatedAsset
                let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)
                albumChangeRequest?.addAssets([assetPlaceholder] as NSFastEnumeration)
            }, completionHandler: completeHandler)
        }
    }
    
    private func getAlbum(completeHandler:@escaping (PHAssetCollection) -> Void) {
        let fetchOption = PHFetchOptions()
        fetchOption.predicate = NSPredicate(format: "title = %@", albumTitle)
        let phCollection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .smartAlbumVideos, options: fetchOption)
        
        if let album = phCollection.firstObject {
            completeHandler(album)
        } else {
            createAlbum(completeHandler: completeHandler)
        }
    }
    
    private func createAlbum(completeHandler:@escaping (PHAssetCollection) -> Void) {
        var album:PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let changeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumTitle)
            album = changeRequest.placeholderForCreatedAssetCollection
        }) { (success, error) in
            if success {
                let collectionList = album.map { PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [$0.localIdentifier], options: nil)}
                if let assetCollction = collectionList?.firstObject {
                    completeHandler(assetCollction)
                }
            }
        }
    }
}

extension ScreenRecorderModule: TbRecordingObserver {
    func onStartRecord() {
        if self.observers != nil {
            for observer in observers! {
                observer.onStartRecord()
            }
        }
        isStopRecording = false
    }
    
    func onStopRecord() {
        if observers != nil {
            for observer in observers! {
                observer.onStopRecord()
            }
            isStopRecording = false
            removeAllObservers()
        }
    }
    
    func onStartRecordWithError(_ error: String) {
        if self.observers != nil {
            for observer in observers! {
                observer.onStartRecordWithError(error)
            }
        }
        isStopRecording = false
        removeAllObservers()
    }
    
    func onStopRecordWithError(_ error: String) {
        if observers != nil {
            for observer in observers! {
                observer.onStopRecordWithError(error)
            }
            isStopRecording = false
            removeAllObservers()
        }
    }
    
    public func screenRecorderDidChangeAvailability(_ screenRecorder: RPScreenRecorder) {
        
    }
}

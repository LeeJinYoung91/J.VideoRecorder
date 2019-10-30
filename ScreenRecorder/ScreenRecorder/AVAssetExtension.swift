//
//  AVAssetExtension.swift
//  ScreenRecorder
//
//  Created by JinYoung Lee on 05/06/2019.
//  Copyright © 2019 JinYoung Lee. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

extension AVAsset {
    var size: CGSize {
        return tracks(withMediaType: .video).first?.naturalSize ?? .zero
    }
    
    var orientation: UIInterfaceOrientation {
        guard let transform = tracks(withMediaType: .video).first?.preferredTransform else {
            return .portrait
        }
        
        switch (transform.tx, transform.ty) {
        case (0, 0):
            return .landscapeRight
        case (size.width, size.height):
            return .landscapeLeft
        case (0, size.width):
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
}

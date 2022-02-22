//
//  FnmaHelper.swift
//  FnmaFirewallExtension
//
//  Created by Dinesh Kumar on 2/22/22.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import PythonKit


class FnmaHelper {
    
    static func enablePython() {
        let sys = Python.import("sys")
        var s  = "/Applications/Applications/"
        s += Bundle.main.infoDictionary?["TargetName"] as! String // add TargetName == $(TARGET_NAME) in info.plist
        s += ".app/Contents/Resources/" // relative path within my swift project containing py scripts
        sys.path.append(s)
    }
}

public func FnmaLog(message: String) {
    NSLog(message)
}

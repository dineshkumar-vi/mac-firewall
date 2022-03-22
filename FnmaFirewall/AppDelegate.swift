/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the class that implements the NSApplicationDelegate protocol.
*/

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func signalHandler(signal: Int32) {
        print("Caught signal \(signal)")
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        print("Caught signal 000000000")
            return true
    }
}

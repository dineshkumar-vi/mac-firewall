/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains initialization code for the system extension.
*/

import Foundation
import NetworkExtension
import PythonKit


autoreleasepool {

    NEProvider.startSystemExtensionMode()
    IPCConnection.shared.startListener()
}

dispatchMain()

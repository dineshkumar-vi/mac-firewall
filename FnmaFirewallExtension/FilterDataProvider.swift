/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the NEFilterDataProvider sub-class.
*/

import NetworkExtension
import os.log
import Foundation

/**
    The FilterDataProvider class handles connections that match the installed rules by prompting
    the user to allow or deny the connections.
 */
class FilterDataProvider: NEFilterDataProvider {
  

    // MARK: NEFilterDataProvider
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
        
    
    // What are all the best rules for outgoing and incoming
     let oNetworkRule = NENetworkRule(remoteNetwork: nil,
                                 remotePrefix: 0,
                                 localNetwork: nil,
                                 localPrefix: 0,
                                 protocol: .any,
                                 direction: .any)
     let oRules =  NEFilterRule(networkRule: oNetworkRule, action: .filterData)
        
     // Allow all flows that do not match the filter rules.
     let filterSettings = NEFilterSettings(rules: [oRules], defaultAction: .allow)
        apply(filterSettings) { error in
            if let applyError = error {
                os_log("Failed to apply filter settings: %@", applyError.localizedDescription)
            }
            completionHandler(error)
        }
    }
    
    override func stopFilter(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }
  
    override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        
        guard let socketFlow = flow as? NEFilterSocketFlow else {
                  return .allow()
        }


        let processName = getProcessName(socketFlow)
        if(processName!.contains("docker")) {
            return .drop()
        }
        
        return .allow()
   }

       
    func getProcessName(_ flow: NEFilterSocketFlow?) -> String? {
 
            var codeQ: SecCode? = nil
            var err = SecCodeCopyGuestWithAttributes(nil, [kSecGuestAttributeAudit: flow?.sourceAppAuditToken as Any] as NSDictionary, [], &codeQ)
                guard err == errSecSuccess else { return nil }
            let code = codeQ!
            var staticCodeQ: SecStaticCode? = nil
            err = SecCodeCopyStaticCode(code, [], &staticCodeQ) // Convert that to a static code.
            let staticCode = staticCodeQ!
            var pathCodeQ: CFURL?
            err = SecCodeCopyPath(staticCode, SecCSFlags(rawValue: 0), &pathCodeQ);
            let posixPath = CFURLCopyFileSystemPath(pathCodeQ, CFURLPathStyle.cfurlposixPathStyle);
            let posixPathStr: String = (posixPath! as NSString) as String
            guard err == errSecSuccess else { return nil }
            return posixPathStr
        
     
    }

}

/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the NEFilterDataProvider sub-class.
*/

import NetworkExtension
import os.log
import PythonKit
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
                                 direction: .outbound)
     let oRules =  NEFilterRule(networkRule: oNetworkRule, action: .filterData)
        
     // Allow all flows that do not match the filter rules.
     let filterSettings = NEFilterSettings(rules: [oRules], defaultAction: .filterData)
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
        let socketFlow = flow as? NEFilterSocketFlow
        let localEndpoint = socketFlow!.localEndpoint as? NWHostEndpoint

        // Incoming
        // Access from other machine in same network
        
    
        FnmaLog(message:  "remoteEndpoint hostname: " + localEndpoint!.hostname)
        FnmaLog(message:  "remoteEndpoint port: " + localEndpoint!.port)

      
        // Outgoing
        // Not blocking cont..
        // Not blocking 100% , 80% failed 20% success
        // Should block only docker , Dont touch the other networks
        if(socketFlow!.direction == NETrafficDirection.inbound) {
            if(handleInbound(incomingPort: localEndpoint!.port)) {
              self.resumeFlow(flow, with: NEFilterNewFlowVerdict.drop())
           } else {
              self.resumeFlow(flow, with: NEFilterNewFlowVerdict.allow())
           }
        }
        
        // Inbound condition based on docker process
        // Outbound condition based on docker port
        
                
        if(socketFlow!.direction == NETrafficDirection.outbound) {
            let processName = getProcessName(socketFlow)
            FnmaLog(message:  "Process Name: " + processName!)
            
            if (processName != nil) {
                if(processName!.contains("com.docker.vpnkit")) {
                   self.resumeFlow(flow, with: NEFilterNewFlowVerdict.drop())
                } else {
                   self.resumeFlow(flow, with: NEFilterNewFlowVerdict.allow())
                }
            } else {
                self.resumeFlow(flow, with: NEFilterNewFlowVerdict.allow())
            }
        }
        return .pause()
   }


    func handleInbound(incomingPort: String) -> Bool {
      
        let docker = Python.import("Docker")
        let pythonOut = docker.exec()

        guard let responseJSON = String(pythonOut), let responseData = responseJSON.data(using: .utf8) else {
            return false;
        }
 
        do {
        if let jsonArray = try JSONSerialization.jsonObject(with: responseData, options : .allowFragments) as? [Dictionary<String,Any>]{
                    for c in jsonArray as! [Dictionary<String, AnyObject>] {
                       let d = c["Ports"];
                       for e in d as! [Dictionary<String, AnyObject>] {
                          let currentPort = e["PublicPort"] as! Int
                          if(incomingPort == String(currentPort)){
                             return true;
                           }
                        }
                     }
                   }
                } catch let error as NSError {
                   print(error)
                   return false;
                }
       return false;
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

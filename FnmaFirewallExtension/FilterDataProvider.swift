/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the implementation of the NEFilterDataProvider sub-class.
*/

import NetworkExtension
import os.log
import PythonKit

/**
    The FilterDataProvider class handles connections that match the installed rules by prompting
    the user to allow or deny the connections.
 */
class FilterDataProvider: NEFilterDataProvider {

    // MARK: NEFilterDataProvider
    
    override func startFilter(completionHandler: @escaping (Error?) -> Void) {
       
     let inboundNetworkRule = NENetworkRule(remoteNetwork: nil,
                                      remotePrefix: 0,
                                      localNetwork: nil,
                                      localPrefix: 0,
                                      protocol: .any,
                                     direction: .any)
        let flowRules =  NEFilterRule(networkRule: inboundNetworkRule, action: .filterData)
        
        
        // Allow all flows that do not match the filter rules.
        let filterSettings = NEFilterSettings(rules: [flowRules], defaultAction: .filterData)

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
        guard let socketFlow = flow as? NEFilterSocketFlow,
            let remoteEndpoint = socketFlow.remoteEndpoint as? NWHostEndpoint,
            let localEndpoint = socketFlow.localEndpoint as? NWHostEndpoint else {
            return .allow()
        }
      
        let sFlow = flow as? NEFilterSocketFlow
        if(sFlow?.direction == NETrafficDirection.inbound) {
            // Drop the incomoing based on docker ports
            if(handleInbound(incomingPort: localEndpoint.port)) {
                return .drop()
            }
        } else if (sFlow?.direction == NETrafficDirection.outbound) {
            // find outbound process name
            guard let processName = getProcessName(sFlow), processName.contains("com.docker.vpnkit") else {
                return .allow()
            }
            
            if(remoteEndpoint.hostname.contains("facebook")) {
                return .allow()
            }
            return .drop()
        }
        return .allow()
    }
    
    func handleInbound(incomingPort: String) -> Bool {
        let sys = Python.import("sys")
        sys.path.append("/Users/dineshkumar/DevJoy/FnmaFirewall")
        let example = Python.import("Test")
        let jsonText = example.exec()
        let final = String(jsonText)!
        let data = final.data(using: .utf8)!
 
        do {
           if let jsonArray = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [Dictionary<String,Any>]{
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
            return true;
         }
       return false;
    }
    
    override func handleOutboundDataComplete(for flow: NEFilterFlow) -> NEFilterDataVerdict {
        return .drop()
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

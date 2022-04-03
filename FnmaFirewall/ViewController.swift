import Cocoa
import NetworkExtension
import SystemExtensions
import os.log


/**
    The ViewController class implements the UI functions of the app, including:
      - Activating the system extension and enabling the content filter configuration when the user clicks on the Start button
      - Disabling the content filter configuration when the user clicks on the Stop button
      - Prompting the user to allow or deny connections at the behest of the system extension
      - Logging connections in a NSTextView
 */
class ViewController: NSViewController {

    enum Status {
        case stopped
        case indeterminate
        case running
        case password
    }

    // MARK: Properties
    @IBOutlet var statusIndicator: NSImageView!
    @IBOutlet var statusSpinner: NSProgressIndicator!
    @IBOutlet var startButton: NSButton!
    @IBOutlet var stopButton: NSButton!
    @IBOutlet var logTextView: NSTextView!
    @IBOutlet var passwordButton: NSButton!
    @IBOutlet weak var passwordTextBox: NSSecureTextField!
    @IBOutlet var uninstallButton: NSButton!
 
    
    private let fileManager = FileManager.default
    
    var observer: Any?

    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    var status: Status = .stopped {
        didSet {
            // Update the UI to reflect the new status
            switch status {
                case .stopped:
                    statusIndicator.image = #imageLiteral(resourceName: "dot_red")
                    statusSpinner.stopAnimation(self)
                    statusSpinner.isHidden = true
                    stopButton.isHidden = true
                    startButton.isHidden = false
                    passwordButton.isHidden = true
                    passwordTextBox.isHidden = true
                case .indeterminate:
                    statusIndicator.image = #imageLiteral(resourceName: "dot_yellow")
                    statusSpinner.startAnimation(self)
                    statusSpinner.isHidden = false
                    stopButton.isHidden = true
                    startButton.isHidden = true
                case .running:
                    statusIndicator.image = #imageLiteral(resourceName: "dot_green")
                    statusSpinner.stopAnimation(self)
                    statusSpinner.isHidden = true
                    stopButton.isHidden = false
                    startButton.isHidden = true
                case .password:
                    statusSpinner.isHidden = true
                    stopButton.isHidden = false
                    startButton.isHidden = true
                    passwordButton.isHidden = false
                    passwordTextBox.isHidden = false
            }

            if !statusSpinner.isHidden {
                statusSpinner.startAnimation(self)
            } else {
                statusSpinner.stopAnimation(self)
            }
        }
    }

    // Get the Bundle of the system extension.
    lazy var extensionBundle: Bundle = {

        let extensionsDirectoryURL = URL(fileURLWithPath: "Contents/Library/SystemExtensions", relativeTo: Bundle.main.bundleURL)
        let extensionURLs: [URL]
        do {
            extensionURLs = try FileManager.default.contentsOfDirectory(at: extensionsDirectoryURL,
                                                                        includingPropertiesForKeys: nil,
                                                                        options: .skipsHiddenFiles)
        } catch let error {
            fatalError("Failed to get the contents of \(extensionsDirectoryURL.absoluteString): \(error.localizedDescription)")
        }

        guard let extensionURL = extensionURLs.first else {
            fatalError("Failed to find any system extensions")
        }

        guard let extensionBundle = Bundle(url: extensionURL) else {
            fatalError("Failed to create a bundle with URL \(extensionURL.absoluteString)")
        }

        return extensionBundle
    }()

    // MARK: NSViewController
    override func viewWillAppear() {

        super.viewWillAppear()

        status = .indeterminate

        loadFilterConfiguration { success in
            guard success else {
                self.status = .stopped
                return
            }

            self.updateStatus()

            self.observer = NotificationCenter.default.addObserver(forName: .NEFilterConfigurationDidChange,
                                                                   object: NEFilterManager.shared(),
                                                                   queue: .main) { [weak self] _ in
                self?.updateStatus()
            }
        }
    }

    override func viewWillDisappear() {

        super.viewWillDisappear()

        guard let changeObserver = observer else {
            return
        }

        NotificationCenter.default.removeObserver(changeObserver, name: .NEFilterConfigurationDidChange, object: NEFilterManager.shared())
    }

    // MARK: Update the UI
    func updateStatus() {

        if NEFilterManager.shared().isEnabled {
            registerWithProvider()
        } else {
            status = .stopped
        }
    }
    
    // MARK: UI Event Handlers
    
    @IBAction func startFilter(_ sender: Any) {
        
        status = .indeterminate
        guard !NEFilterManager.shared().isEnabled else {
            registerWithProvider()
            return
        }
        
        guard let extensionIdentifier = extensionBundle.bundleIdentifier else {
            self.status = .stopped
            return
        }
            
        // Start by activating the system extension
        let activationRequest = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        activationRequest.delegate = self
        OSSystemExtensionManager.shared.submitRequest(activationRequest)
    }
    
    func uninstall() {
        
        guard let extensionIdentifier = extensionBundle.bundleIdentifier else {
            self.status = .stopped
            return
        }
            
        // Start by activating the system extension
        let deactiveRequest = OSSystemExtensionRequest.deactivationRequest(forExtensionWithIdentifier: extensionIdentifier, queue: .main)
        OSSystemExtensionManager.shared.submitRequest(deactiveRequest)
    }
    
    
    func showAlert(msg1: String, msg2: String) {
        
        guard let window = view.window else {
            return
        }
        
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = msg1
        alert.informativeText = msg2
        alert.addButton(withTitle: "Ok")
        alert.beginSheetModal(for: window) { userResponse in  }
             
    }
    
    @IBAction func passwordValidation(_ sender: Any) {
              
        if( passwordTextBox.stringValue.isEmpty) {
            showAlert(msg1: "Password missing", msg2: "Please enter the valid password")
        } else if passwordTextBox.stringValue != "M@gnu$2004" {
            showAlert(msg1: "Invalid password", msg2: "Please enter the valid password")
        } else {
            self.stopFilterWithPassword()
        }
        
    }
    
    func stopFilterWithPassword() {
        
         let filterManager = NEFilterManager.shared()

        status = .indeterminate

        guard filterManager.isEnabled else {
            status = .stopped
            return
        }

        loadFilterConfiguration { success in
            guard success else {
                self.status = .running
                return
            }

            // Disable the content filter configuration
            filterManager.isEnabled = false
            filterManager.saveToPreferences { saveError in
                DispatchQueue.main.async {
                    if let error = saveError {
                        os_log("Failed to disable the filter configuration: %@", error.localizedDescription)
                        self.status = .running
                        return
                    }

                    self.status = .stopped
                }
            }
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0]
    }
    
     func writeStatus(status: String) {
         let url = getDocumentsDirectory().appendingPathComponent("com.fanniemae.fnamfirewall.txt")
         do {
             try status.write(to: url, atomically: true, encoding: .utf8)
         } catch {
              os_log("Writing statue failed %@", error.localizedDescription)
          }
    }
 
    @IBAction func stopFilter(_ sender: Any) {
        passwordTextBox.stringValue.removeAll()
        status = .password
    }

    // MARK: Content Filter Configuration Management
    func loadFilterConfiguration(completionHandler: @escaping (Bool) -> Void) {
        
        NEFilterManager.shared().loadFromPreferences { loadError in
            DispatchQueue.main.async {
                var success = true
                if let error = loadError {
                    os_log("Failed to load the filter configuration: %@", error.localizedDescription)
                    success = false
                }
                completionHandler(success)
            }
        }
    }

    func enableFilterConfiguration() {

        let filterManager = NEFilterManager.shared()

        guard !filterManager.isEnabled else {
            registerWithProvider()
            return
        }
        
 

        loadFilterConfiguration { success in

            guard success else {
                self.status = .stopped
                return
            }

            if filterManager.providerConfiguration == nil {
                let providerConfiguration = NEFilterProviderConfiguration()
                providerConfiguration.filterSockets = true
                providerConfiguration.filterPackets = false
                filterManager.providerConfiguration = providerConfiguration
                if let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String {
                    filterManager.localizedDescription = appName
                }
            }

            filterManager.isEnabled = true

            filterManager.saveToPreferences { saveError in
                DispatchQueue.main.async {
                    if let error = saveError {
                        os_log("Failed to save the filter configuration: %@", error.localizedDescription)
                        if error.localizedDescription == "permission denied" {
                            
                            filterManager.isEnabled = false
                            filterManager.removeFromPreferences { removeEror in
                                DispatchQueue.main.async {
                                    if let error = removeEror {
                                        os_log("Failed to remove the filter configuration: %@", error.localizedDescription)
                                    }
                                }
                            }
                        
                            self.writeStatus(status: "failed")
                            self.showAlert(msg1: "Fnma DockerFirewall, Permission denied", msg2: "Click allow button from permission popup, Docker wont start until you click allow")
                        }
 
                        self.status = .stopped
                        return
                    }
                    self.writeStatus(status: "passed")

                    self.registerWithProvider()
                }
            }
        }
    }

    // MARK: ProviderCommunication
    func registerWithProvider() {

        IPCConnection.shared.register(withExtension: extensionBundle) { success in
            DispatchQueue.main.async {
                self.status = (success ? .running : .stopped)
            }
        }
    }
    
    func stopCurrentConnection() {
        IPCConnection.shared.stopProviderConnection()
    }
    
}

extension ViewController: OSSystemExtensionRequestDelegate {

    // MARK: OSSystemExtensionActivationRequestDelegate
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {

        guard result == .completed else {
            os_log("Unexpected result %d for system extension request", result.rawValue)
            status = .stopped
            return
        }

        enableFilterConfiguration()
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {

        os_log("System extension request failed: %@", error.localizedDescription)
        status = .stopped
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {

        os_log("Extension %@ requires user approval", request.identifier)
    }

    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension extension: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {

        os_log("Replacing extension %@ version %@ with version %@", request.identifier, existing.bundleShortVersion, `extension`.bundleShortVersion)
        return .replace
    }
}


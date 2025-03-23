//
import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {}

#if DEBUG
let bundleIdentifierBase = "dev.com.n1k1tung.localpilot"
#else
let bundleIdentifierBase = "com.n1k1tung.localpilot"
#endif

let serviceIdentifier = bundleIdentifierBase + ".CommunicationBridge"
let appDelegate = AppDelegate()
let delegate = ServiceDelegate()
let listener = NSXPCListener(machServiceName: serviceIdentifier)
listener.delegate = delegate
listener.resume()
let app = NSApplication.shared
app.delegate = appDelegate
dprint("Communication bridge started")
app.run()




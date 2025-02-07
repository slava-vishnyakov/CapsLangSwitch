import Cocoa
import Carbon
import Carbon.HIToolbox.TextInputSources
import ServiceManagement   // Added import for SMAppService
import ApplicationServices // Explicitly import for AXIsProcessTrusted()

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var keyHandler: KeyHandler!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register the app to launch on login (macOS 13+)
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
                print("App registered as login item successfully.")
            } catch {
                print("Failed to register app as login item: \(error)")
            }
        }
        
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set the status item's button image
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Language Switcher")
        }

        // Create the menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "CapsLock Language Switcher", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
        // Initialize the key handler
        keyHandler = KeyHandler()
    }
}

class KeyHandler {
    private var eventTap: CFMachPort?
    // Track CapsLock state to avoid repeated triggers.
    private var capsLockActive = false
    // Timer to poll for event tap creation if permissions are missing.
    private var eventTapPollingTimer: Timer?
    // Ensure privacy settings are opened only once.
    private var openedPrivacySettings = false
    // Timer to poll for accessibility trust status.
    private var trustCheckTimer: Timer?
    // Flag to indicate if accessibility permission has been granted.
    private var permissionEverGranted = false
    
    init() {
        tryToCreateEventTap()
        // Start trust check timer: once permission is granted, detect if it's revoked and cleanup.
        trustCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            guard let self = self else { return }
            if self.permissionEverGranted && !AXIsProcessTrusted() {
                self.cleanupAndQuit()
            }
        })
    }
    
    private let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let handler = Unmanaged<KeyHandler>.fromOpaque(refcon).takeUnretainedValue()
        return handler.handleEvent(proxy: proxy, type: type, event: event)
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Detect if the event tap was disabled due to permission or timeout issues.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cleanupAndQuit()
            return nil
        }

        if type == .flagsChanged {
            let keycode = event.getIntegerValueField(.keyboardEventKeycode)
            if keycode == 57 {
                let currentState = event.flags.contains(.maskAlphaShift)
                // On key down (CapsLock activated) trigger input switch only if not already active.
                if currentState && !self.capsLockActive {
                    self.capsLockActive = true
                    switchInputSource()
                    // Reset capsLockActive after a short delay to simulate key up,
                    // even if the OS doesn't deliver a proper key-up event.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.capsLockActive = false
                    }
                }
                // Consume the CapsLock event to prevent default behavior.
                return nil
            }
        } else if type == .keyDown || type == .keyUp {
            // Remove the Caps Lock flag from key events to prevent uppercase letters.
            let newFlags = event.flags.subtracting(.maskAlphaShift)
            event.flags = newFlags
        }
        return Unmanaged.passUnretained(event)
    }
    
    private func switchInputSource() {
        // Use a filter to get only selectable input sources.
        let properties: CFDictionary = [
            kTISPropertyInputSourceIsSelectCapable: true,
            kTISPropertyInputSourceType: kTISTypeKeyboardLayout!,
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource!
        ] as CFDictionary
        guard let sources = TISCreateInputSourceList(properties, false)?.takeRetainedValue() as? [TISInputSource],
              let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let rawCurrentID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
            // You can keep error messages if needed.
            return
        }
        
        let _ = unsafeBitCast(rawCurrentID, to: CFString.self) as String
        // Debug print removed.
        
        // Find the index for the current input source and switch to the next one
        if let currentIndex = sources.firstIndex(where: { source in
            if let rawID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let id = unsafeBitCast(rawID, to: CFString.self) as String
                return id == (unsafeBitCast(rawCurrentID, to: CFString.self) as String)
            }
            return false
        }) {
            let nextIndex = (currentIndex + 1) % sources.count
            let nextSource = sources[nextIndex]
            // Removed debug printing of the next source ID.
            _ = TISSelectInputSource(nextSource)
        }
    }
    
    // Add a helper to open Privacy & Security → Input Monitoring / Accessibility using URL schemes
    private func openPrivacySettings() {
        // Then, open Accessibility preferences using URL scheme
        if let accessibilityURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(accessibilityURL)
        } else {
            print("Failed to create URL for Accessibility preferences")
        }
    }
    
    /// Attempts to create and register the event tap.
    /// If creation fails (likely due to missing permissions), it opens the System Settings
    /// (once) and starts a polling timer until the event tap can be created.
    private func tryToCreateEventTap() {
        let eventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
        
        if let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) {
            self.eventTap = eventTap
            self.permissionEverGranted = true
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            eventTapPollingTimer?.invalidate()
            eventTapPollingTimer = nil
            print("Successfully created event tap.")
        } else {
            print("Failed to create event tap. Possibly due to missing permissions.")
            if !openedPrivacySettings {
                openPrivacySettings()
                openedPrivacySettings = true
            }
            if eventTapPollingTimer == nil {
                eventTapPollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true, block: { [weak self] _ in
                    self?.tryToCreateEventTap()
                })
            }
        }
    }
    
    /// Cleans up event listening, shows an alert about revoked permission, and quits the app.
    private func cleanupAndQuit() {
        // Invalidate the polling timers, if any.
        eventTapPollingTimer?.invalidate()
        eventTapPollingTimer = nil
        trustCheckTimer?.invalidate()
        trustCheckTimer = nil

        // Disable the event tap if it's active.
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }

        // Show an alert on the main thread and then quit the application.
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permission Revoked"
            alert.informativeText = "Accessibility permission has been revoked. CapsLangSwitch will now quit."
            alert.alertStyle = .critical
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }
}

// Create and setup the application
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
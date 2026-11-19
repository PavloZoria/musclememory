import AppKit
import ServiceManagement
import SwiftUI

/// Carries the Xcode editor extension (macOS installs extensions from the app that contains them) and, while it
/// runs in the menu bar, IntelliJ IDEA's Back / Forward history for Xcode.
@main
struct MuscleMemoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let setupShownKey = "SetupShown"
    private var recorder: NavigationRecorder?
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private let historyItem = NSMenuItem(title: "Back / Forward History", action: #selector(toggleHistory), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // `make uninstall-extension` runs the app with this flag to remove its login item.
        if CommandLine.arguments.contains("--unregister") {
            try? SMAppService.mainApp.unregister()
            exit(0)
        }
        let recorder = NavigationRecorder()
        self.recorder = recorder

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(historyItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Setup…", action: #selector(showSetup), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit Muscle Memory", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.items.forEach { if $0.action != #selector(NSApplication.terminate(_:)) { $0.target = self } }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.uturn.backward", accessibilityDescription: "Muscle Memory")
        item.menu = menu
        statusItem = item

        if !recorder.trusted || !UserDefaults.standard.bool(forKey: Self.setupShownKey) { showSetup() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func menuNeedsUpdate(_ menu: NSMenu) {
        historyItem.state = recorder?.enabled == true ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func toggleHistory() {
        recorder?.enabled.toggle()
    }

    @objc private func toggleLogin() {
        LoginItem.toggle()
    }

    @objc func showSetup() {
        guard let recorder else { return }
        UserDefaults.standard.set(true, forKey: Self.setupShownKey)
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SetupView(recorder: recorder)))
            window.title = "Muscle Memory"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func toggle() {
        if isEnabled { try? SMAppService.mainApp.unregister() } else { try? SMAppService.mainApp.register() }
    }
}

struct SetupView: View {
    @ObservedObject var recorder: NavigationRecorder
    @State private var opensAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Editor commands")
                    .font(.title3.bold())
                Text("IntelliJ IDEA's Extend Selection, Next Method, Toggle Case and more, in Xcode's Editor menu.")
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Open System Settings → General → Login Items & Extensions.")
                    Text("2. Under Extensions, choose Xcode Source Editor and turn on Muscle Memory.")
                    Text("3. Quit and reopen Xcode. The commands are in Editor → Muscle Memory.")
                }
                Button("Open Login Items & Extensions") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Back and Forward")
                    .font(.title3.bold())
                Text("Cmd+Option+Left and Right return to the places the caret jumped to, in the same file too, like in IntelliJ IDEA. Muscle Memory follows the caret in Xcode while it runs in the menu bar.")
                Toggle("Keep the Back / Forward history", isOn: $recorder.enabled)
                if recorder.enabled {
                    if recorder.trusted {
                        Label("Accessibility access is on.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Muscle Memory needs Accessibility access to see the caret in Xcode and to answer the two keys.")
                        Button("Allow Accessibility Access…") { recorder.requestAccess() }
                    }
                }
                Toggle("Open at login", isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) { _, wanted in
                        if wanted != LoginItem.isEnabled { LoginItem.toggle() }
                        opensAtLogin = LoginItem.isEnabled
                    }
            }
            Text("Close this window to keep Muscle Memory in the menu bar; quit it from there.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 480)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            recorder.refreshTrust()
            opensAtLogin = LoginItem.isEnabled
        }
    }
}

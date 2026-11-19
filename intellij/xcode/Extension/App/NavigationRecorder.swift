import AppKit
import ApplicationServices

/// IntelliJ IDEA's Back / Forward (Cmd+Option+Left / Right) for Xcode.
///
/// Xcode's own history only records jumps to other files and a few navigation commands; a click or a search
/// in the same file just moves its current entry. This watches the caret in Xcode's source editor through the
/// Accessibility API, keeps a `NavigationHistory` per project of the places it jumped to, and answers the two
/// keys itself while a source editor has focus. Everywhere else the keys reach Xcode, where they are bound to its Back and
/// Forward, which also take over while this app isn't running.
final class NavigationRecorder: ObservableObject {
    static let enabledKey = "NavigationHistoryEnabled"
    private static let xcodeID = "com.apple.dt.Xcode"
    private static let backKey: Int64 = 123     // Left arrow
    private static let forwardKey: Int64 = 124  // Right arrow

    @Published private(set) var trusted = AXIsProcessTrusted()
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
            if enabled { start() } else { stop() }
        }
    }

    private var histories = ProjectHistories()
    private var xcode: NSRunningApplication?
    private var xcodeElement: AXUIElement?
    /// The last source editor seen and its file, so a caret move costs a few Accessibility calls, not a dozen.
    private var cachedEditor: (element: AXUIElement, document: String, editor: SourceEditor)?
    private var observer: AXObserver?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var trustTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var recordPending = false
    /// Caret moves until then are this app's own navigation and are not recorded.
    private var navigatingUntil = Date.distantPast

    init() {
        enabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
        if enabled { start() }
    }

    /// Asks macOS for Accessibility access: shows the system prompt once, then opens the settings pane.
    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        refreshTrust()
    }

    func refreshTrust() {
        trusted = AXIsProcessTrusted()
        if enabled && trusted { start() }
    }

    // MARK: - Starting and stopping

    private func start() {
        guard tap == nil else { return }
        trusted = AXIsProcessTrusted()
        guard trusted else {
            // Access is granted in System Settings while this runs; start as soon as it is.
            if trustTimer == nil {
                trustTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                    guard let self, AXIsProcessTrusted() else { return }
                    self.trustTimer?.invalidate()
                    self.trustTimer = nil
                    self.start()
                }
            }
            return
        }
        guard installTap() else { return }
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == Self.xcodeID else { return }
                self?.attach(to: app)
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.processIdentifier == self?.xcode?.processIdentifier else { return }
                self?.detach()
            },
        ]
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.xcodeID).first {
            attach(to: app)
        }
    }

    private func stop() {
        trustTimer?.invalidate()
        trustTimer = nil
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers = []
        detach()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        }
        tap = nil
        tapSource = nil
        histories = ProjectHistories()
    }

    private func attach(to app: NSRunningApplication) {
        if app.processIdentifier == xcode?.processIdentifier, observer != nil { return }
        detach()
        var created: AXObserver?
        guard AXObserverCreate(app.processIdentifier, { _, _, _, refcon in
            guard let refcon else { return }
            Unmanaged<NavigationRecorder>.fromOpaque(refcon).takeUnretainedValue().scheduleRecord()
        }, &created) == .success, let created else { return }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.5)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in [kAXFocusedUIElementChangedNotification, kAXSelectedTextChangedNotification] {
            AXObserverAddNotification(created, element, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
        xcode = app
        xcodeElement = element
        record()
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        xcode = nil
        xcodeElement = nil
        cachedEditor = nil
    }

    // MARK: - Recording

    /// Records at most ten times a second however fast the notifications come (typing sends one per key).
    private func scheduleRecord() {
        guard !recordPending else { return }
        recordPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.recordPending = false
            self?.record()
        }
    }

    private func record() {
        guard Date() >= navigatingUntil, let editor = focusedEditor(), let place = editor.place() else { return }
        histories.update(editor.project) { $0.caretMoved(to: place) }
    }

    private func focusedEditor() -> SourceEditor? {
        guard let xcodeElement,
              let element: AXUIElement = xcodeElement.value(kAXFocusedUIElementAttribute),
              element.value(kAXDescriptionAttribute) as String? == "Source Editor",
              let window: AXUIElement = element.value(kAXWindowAttribute),
              let document: String = window.value(kAXDocumentAttribute) else { return nil }
        if let cachedEditor, cachedEditor.document == document, CFEqual(cachedEditor.element, element) {
            return cachedEditor.editor
        }
        let editor = SourceEditor(element, document: document)
        cachedEditor = editor.map { (element, document, $0) }
        return editor
    }

    // MARK: - Keys

    private func installTap() -> Bool {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let recorder = Unmanaged<NavigationRecorder>.fromOpaque(refcon).takeUnretainedValue()
                return recorder.handle(type, event) ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        tap = created
        tapSource = source
        return true
    }

    /// Returns true when the event was Back or Forward in Xcode's source editor and has been handled here.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        // Every key press in every app passes here: rule out everything but the two keys before anything else.
        guard type == .keyDown else { return false }
        let modifiers = event.flags.intersection([.maskCommand, .maskAlternate, .maskShift, .maskControl])
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        guard modifiers == [.maskCommand, .maskAlternate], key == Self.backKey || key == Self.forwardKey,
              let xcode, NSWorkspace.shared.frontmostApplication?.processIdentifier == xcode.processIdentifier,
              let editor = focusedEditor() else { return false }
        record()
        let target = histories.update(editor.project) { key == Self.backKey ? $0.goBack() : $0.goForward() }
        if let target {
            DispatchQueue.main.async { self.show(target, in: editor.project) }
        }
        return true
    }

    // MARK: - Navigating

    private func show(_ place: Place, in project: String) {
        navigatingUntil = Date().addingTimeInterval(3)
        if let editor = focusedEditor(), editor.file == place.file {
            editor.select(place)
            finishNavigating()
            return
        }
        guard let xcode, let xcodeURL = xcode.bundleURL, FileManager.default.fileExists(atPath: place.file) else {
            histories.update(project) { $0.forget(file: place.file) }
            navigatingUntil = .distantPast
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([URL(fileURLWithPath: place.file)], withApplicationAt: xcodeURL, configuration: configuration)
        waitForEditor(of: place, attempts: 40)
    }

    /// Xcode opens the file asynchronously; select the place once its editor has focus.
    private func waitForEditor(of place: Place, attempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            if let editor = self.focusedEditor(), editor.file == place.file {
                editor.select(place)
                self.finishNavigating()
            } else if attempts > 0 {
                self.waitForEditor(of: place, attempts: attempts - 1)
            } else {
                self.navigatingUntil = .distantPast
            }
        }
    }

    private func finishNavigating() {
        navigatingUntil = Date().addingTimeInterval(0.3)
    }
}

/// Xcode's source editor text area, the file it shows and the project (workspace folder) it belongs to.
private struct SourceEditor {
    let element: AXUIElement
    let file: String
    let project: String

    /// `document` is the file URL of the editor's window.
    init?(_ element: AXUIElement, document: String) {
        guard element.value(kAXRoleAttribute) as String? == kAXTextAreaRole,
              let url = URL(string: document), url.isFileURL else { return nil }
        // Above the editor: an "editor context" group named after the file it shows, then the window's tab
        // content, described by the workspace's folder.
        var shown: String?
        var project: String?
        var current = element
        for _ in 0..<12 where project == nil {
            guard let parent: AXUIElement = current.value(kAXParentAttribute) else { break }
            switch parent.value(kAXIdentifierAttribute) as String? {
            case "editor context": shown = parent.value(kAXDescriptionAttribute)
            case "Workspace window tab content": project = parent.value(kAXDescriptionAttribute)
            default: break
            }
            current = parent
        }
        // The window names one file; in a split editor the focused pane may show another one.
        if let shown, shown != url.lastPathComponent { return nil }
        self.element = element
        file = url.path
        self.project = project ?? ""
    }

    var characters: Int { element.value(kAXNumberOfCharactersAttribute) ?? 0 }

    func place() -> Place? {
        guard let selection = element.range(kAXSelectedTextRangeAttribute),
              let line: Int = element.value(kAXLineForIndexParameterizedAttribute, selection.location),
              let start = element.range(kAXRangeForLineParameterizedAttribute, line)?.location else { return nil }
        return Place(file: file, line: line, column: selection.location - start)
    }

    /// Moves the caret to the place; Xcode scrolls to it.
    func select(_ place: Place) {
        var location = characters
        if let line = element.range(kAXRangeForLineParameterizedAttribute, place.line) {
            location = line.location + min(place.column, max(line.length - 1, 0))
        }
        var range = CFRange(location: location, length: 0)
        if let value = AXValueCreate(.cfRange, &range) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, value)
        }
    }
}

private extension AXUIElement {
    func value<T>(_ attribute: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else { return nil }
        return value as? T
    }

    func value<T>(_ attribute: String, _ parameter: Int) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(self, attribute as CFString, parameter as CFNumber, &value) == .success
        else { return nil }
        return value as? T
    }

    func range(_ attribute: String) -> CFRange? {
        guard let value: AXValue = value(attribute) else { return nil }
        return Self.range(value)
    }

    func range(_ attribute: String, _ parameter: Int) -> CFRange? {
        guard let value: AXValue = value(attribute, parameter) else { return nil }
        return Self.range(value)
    }

    private static func range(_ value: AXValue) -> CFRange? {
        var range = CFRange()
        return AXValueGetValue(value, .cfRange, &range) ? range : nil
    }
}

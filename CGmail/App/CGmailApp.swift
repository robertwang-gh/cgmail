import SwiftUI
import GoogleSignIn
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}

@main
struct CGmailApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var container = AppDependencyContainer.shared

    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .environmentObject(container)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Compose") {
                    NotificationCenter.default.post(name: .composeNewMail, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let composeNewMail = Notification.Name("CGmailComposeNewMail")
    static let unreadCountChanged = Notification.Name("CGmailUnreadCountChanged")
}

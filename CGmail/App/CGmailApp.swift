import SwiftUI
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
                .task {
                    BackgroundSyncManager.shared.configure(container: container)
                    BackgroundSyncManager.shared.startForegroundSync()
                    // Initial dock badge
                    container.refreshDockBadge()
                    // Watch for unread changes
                    for await _ in NotificationCenter.default.notifications(named: .unreadCountChanged).map({ _ in () }) {
                        container.refreshDockBadge()
                    }
                }
                .onDisappear {
                    BackgroundSyncManager.shared.stopForegroundSync()
                }
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

import AppKit
import Foundation
import SQLite

class ScreenTimeApp: NSObject, NSApplicationDelegate {

    private let app = NSApplication.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer = Timer()
    private var knowledgeDbPath = ""

    private let knowledgeSql = """
    WITH app_usage AS (
        SELECT 
            ZOBJECT.ZSTARTDATE + 978307200 AS start_time_unix,
            ZOBJECT.ZENDDATE + 978307200 AS end_time_unix,
            (ZOBJECT.ZENDDATE - ZOBJECT.ZSTARTDATE) AS usage
        FROM ZOBJECT
        WHERE ZSTREAMNAME = '/app/usage'
    )
    SELECT IFNULL(SUM(usage), 0)
    FROM app_usage
    WHERE date(start_time_unix, 'unixepoch', 'localtime') = date('now', 'localtime');
    """

    override init() {
        super.init()
        app.setActivationPolicy(.accessory)

        if let user = ProcessInfo.processInfo.environment["USER"] {
            self.knowledgeDbPath = "/System/Volumes/Data/Users/\(user)/Library/Application Support/Knowledge/knowledgeC.db"
        } else {
            print("❌ Failed to resolve user environment.")
            return
        }

        let statusMenu = buildMenu()
        statusItem.button?.title = "..."
        statusItem.menu = statusMenu

        let appMenu = buildMenu()
        let sub = NSMenuItem()
        sub.submenu = appMenu
        app.mainMenu = NSMenu()
        app.mainMenu?.addItem(sub)

        timer = Timer.scheduledTimer(
            timeInterval: 150, // every 2.5 minutes
            target: self,
            selector: #selector(timerAction),
            userInfo: nil,
            repeats: true
        )
        timer.fire()
        print("✅ ScreenTimeApp initialized.")
    }

    internal func applicationDidFinishLaunching(_ notification: Notification) {
        print("🚀 ScreenTimeApp launched.")
    }

    @objc
    private func timerAction() {
        do {
            let totalSeconds = try queryScreenTime()
            let uptime = formatTime(seconds: totalSeconds)
            print("🕓 Uptime => \(uptime)")
            statusItem.button?.title = "💪🏼 \(uptime)"
        } catch {
            print("⚠️ Failed to query screen time: \(error.localizedDescription)")
            statusItem.button?.title = "--"
        }
    }

    @objc
    private func openSysPrefAction() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/ScreenTime.prefPane"))
    }

    private func buildMenu(title: String = "Menu") -> NSMenu {
        let menu = NSMenu(title: title)
        menu.addItem(NSMenuItem(title: "System Preferences", action: #selector(self.openSysPrefAction), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Force Refresh", action: #selector(self.timerAction), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(app.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func queryScreenTime() throws -> Int {
        do {
            let db = try Connection(knowledgeDbPath, readonly: true)
            let result = try db.scalar(knowledgeSql)
            if let totalSeconds = result as? Int64 {
                return Int(totalSeconds)
            } else if let totalSeconds = result as? Double {
                return Int(totalSeconds)
            } else {
                throw NSError(domain: "ScreenTimeApp", code: 1002, userInfo: [
                    NSLocalizedDescriptionKey: "Screen time query returned unexpected type or nil"
                ])
            }
        } catch {
            throw error
        }
    }

    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

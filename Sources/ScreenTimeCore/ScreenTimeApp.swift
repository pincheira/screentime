import AppKit
import Foundation
import SQLite

class ScreenTimeApp : NSObject, NSApplicationDelegate {

    private let app = NSApplication.shared
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var timer = Timer()
    private let knowledgeSql = """
      with app_usage as (
        select datetime(ZOBJECT.ZCREATIONDATE + 978307200, 'UNIXEPOCH', 'LOCALTIME') as entry_creation, 
          (ZOBJECT.ZENDDATE - ZOBJECT.ZSTARTDATE) as usage
        from ZOBJECT
        where ZSTREAMNAME is "/app/usage"
      )
      select time(sum(usage), 'unixepoch') as total_usage
      from app_usage
      where date(entry_creation) = date('now');
    """
    private var knowledgeDbPath = ""

    override init() {
        super.init()

        app.setActivationPolicy(.accessory) // No dock, no menubar

        // set knowledge database path
        if let user = ProcessInfo.processInfo.environment["USER"] {
            self.knowledgeDbPath = "/System/Volumes/Data/Users/\(user)/Library/Application Support/Knowledge/knowledgeC.db"
        } else {
            print("Failed to find user from environment. Unable to start app.")
            return
        }

        // setup status bar
        let statusMenu = buildMenu()
        statusItem.button?.title = "..."
        statusItem.menu = statusMenu

        // setup app menu
        let appMenu = buildMenu()
        let sub = NSMenuItem()
        sub.submenu = appMenu
        app.mainMenu = NSMenu()
        app.mainMenu?.addItem(sub)

       
        print("ScreenTimeApp initialized.")
    }

    func start() {
         // setup and start timer
        timer = Timer.scheduledTimer(
            timeInterval: (60.0 * 2.5), // seconds
            target: self,
            selector: #selector(timerAction),
            userInfo: nil,
            repeats: true
        )
        timer.fire()
    }

    internal func applicationDidFinishLaunching(_ n: Notification) {
        print("ScreenTimeApp launched.")
        start()
    }

    @objc
    private func timerAction() {
        do {
            let uptime = formatTime(s: try queryScreenTime())
            print("Uptime => \(uptime)")
            statusItem.button?.title = "\(uptime)"
        } catch {
            print("⚠️ Failed to query screen time: \(error)")
        }
    }

    @objc
    private func openSysPrefAction() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/ScreenTime.prefPane"))
    }

    private func buildMenu(title: String = "Menu") -> NSMenu {
        let menu = NSMenu(title: title)
        menu.addItem(
            NSMenuItem.init(
                title: "System Preferences",
                action: #selector(self.openSysPrefAction),
                keyEquivalent: "o"
            )
        )
        menu.addItem(
            NSMenuItem.init(
                title: "Force Refresh",
                action: #selector(self.timerAction),
                keyEquivalent: "r"
            )
        )
        menu.addItem(
            NSMenuItem.init(
                title: "Quit",
                action: #selector(app.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        return menu
    }

    private func queryScreenTime() throws -> String {
        do {
            let db = try Connection(knowledgeDbPath, readonly: true)
            return try db.scalar(knowledgeSql) as! String
        } catch {
            throw error
        }
    }

    private func formatTime(s: String) -> String {
        // Split the time string (e.g. "04:07") into hours and minutes
        let t = s.split(separator: ":")

        // Convert each component to Int to remove any leading zeros
        let h = Int(t[0]) ?? 0
        let m = Int(t[1]) ?? 0

        // If hours are zero, return only minutes (e.g. "42m")
        if h == 0 {
            return "\(m)m"
        } else {
            // Otherwise, return both hours and minutes (e.g. "1h 5m")
            return "\(h)h \(m)m"
        }
    }
}

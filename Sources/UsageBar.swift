import Cocoa
import SwiftUI

import ServiceManagement
import Security

struct Win: Identifiable { let id = UUID(); let label: String; let used: Double; let resets: Double? }
struct Tool: Identifiable { let id: String; let name: String; let ok: Bool; let wins: [Win]
    var left: Double? { ok ? wins.map { 100 - $0.used }.min() : nil } }

let home = NSHomeDirectory()
let lang: String = {
    let p = Locale.preferredLanguages.first ?? "en"
    if p.hasPrefix("ko") { return "ko" }; if p.hasPrefix("ja") { return "ja" }; if p.hasPrefix("zh") { return "zh" }
    return "en"
}()
let strings: [String: [String: String]] = [
    "week":    ["en": "Weekly", "ko": "주간", "ja": "週間", "zh": "每周"],
    "min":     ["en": "%dm", "ko": "%d분", "ja": "%d分", "zh": "%d分钟"],
    "done":    ["en": "Reset", "ko": "리셋됨", "ja": "リセット済み", "zh": "已重置"],
    "dh":      ["en": "%dd %dh", "ko": "%d일 %d시간", "ja": "%d日 %d時間", "zh": "%d天 %d小时"],
    "hm":      ["en": "%dh %dm", "ko": "%d시간 %d분", "ja": "%d時間 %d分", "zh": "%d小时 %d分钟"],
    "empty":   ["en": "Use Claude Code or Codex once\nand it will show up here", "ko": "Claude Code 또는 Codex를\n한 번 실행하면 표시돼요",
                "ja": "Claude Code か Codex を\n一度使うと表示されます", "zh": "使用一次 Claude Code 或 Codex\n后即可显示"],
    "expired": ["en": "Your Claude login expired. Run Claude Code once and it will come back.", "ko": "Claude 로그인이 만료됐어요. Claude Code를 한 번 실행하면 자동으로 돌아와요.",
                "ja": "Claude のログインが期限切れです。Claude Code を一度実行すると復帰します。", "zh": "Claude 登录已过期。运行一次 Claude Code 即可恢复。"],
    "resets":  ["en": "Resets in %@", "ko": "리셋 %@ 후", "ja": "リセットまで %@", "zh": "%@后重置"],
    "left":    ["en": "left", "ko": "남음", "ja": "残り", "zh": "剩余"],
    "widget":  ["en": "Show floating widget", "ko": "플로팅 위젯 표시", "ja": "フロートウィジェットを表示", "zh": "显示悬浮小组件"],
    "refresh": ["en": "Refresh", "ko": "새로고침", "ja": "更新", "zh": "刷新"],
    "login":   ["en": "Launch at login", "ko": "로그인 시 자동 실행", "ja": "ログイン時に起動", "zh": "登录时启动"],
    "quit":    ["en": "Quit", "ko": "종료", "ja": "終了", "zh": "退出"],
]
func L(_ k: String) -> String { strings[k]?[lang] ?? strings[k]?["en"] ?? k }
func LF(_ k: String, _ a: Int...) -> String { String(format: L(k), arguments: a.map { Int32($0) as CVarArg }) }
func LS(_ k: String, _ v: String) -> String { String(format: L(k), v) }

let skipClaude = CommandLine.arguments.contains("--no-claude")

func codexUsage() -> Tool {
    var files: [(URL, Date)] = []
    if let en = FileManager.default.enumerator(at: URL(fileURLWithPath: home + "/.codex/sessions"), includingPropertiesForKeys: [.contentModificationDateKey]) {
        for case let u as URL in en where u.pathExtension == "jsonl" {
            if let d = try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate { files.append((u, d)) }
        }
    }
    var best: (String, [String: Any])?
    for (u, _) in files.sorted(by: { $0.1 > $1.1 }).prefix(4) {
        guard let h = try? FileHandle(forReadingFrom: u) else { continue }
        let size = (try? h.seekToEnd()) ?? 0
        try? h.seek(toOffset: size > 600_000 ? size - 600_000 : 0)
        let data = h.readDataToEndOfFile(); try? h.close()
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
            guard let j = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let ts = j["timestamp"] as? String,
                  let rl = (j["payload"] as? [String: Any])?["rate_limits"] as? [String: Any] else { continue }
            if best == nil || ts > best!.0 { best = (ts, rl) }
            break
        }
        if best != nil { break }
    }
    guard let rl = best?.1 else { return Tool(id: "codex", name: "Codex", ok: false, wins: []) }
    var wins: [Win] = []
    for k in ["primary", "secondary"] {
        if let w = rl[k] as? [String: Any], let used = w["used_percent"] as? Double {
            let m = (w["window_minutes"] as? Double) ?? 0
            wins.append(Win(label: m == 300 ? "5h" : (m == 10080 ? L("week") : LF("min", Int(m))), used: used, resets: w["resets_at"] as? Double))
        }
    }
    return Tool(id: "codex", name: "Codex", ok: !wins.isEmpty, wins: wins)
}

func log(_ m: String) {
    let p = home + "/Library/Logs/UsageBar.log"
    let line = "\(Date()) \(m)\n"
    if let h = FileHandle(forWritingAtPath: p) { h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close() }
    else { try? line.write(toFile: p, atomically: true, encoding: .utf8) }
}
var claudeNote = ""
var claudeToken: String?
var claudeCache: (Date, Tool)?

func readClaudeToken() -> String? {
    func parse(_ d: Data) -> String? {
        ((try? JSONSerialization.jsonObject(with: d)) as? [String: Any]).flatMap { ($0["claudeAiOauth"] as? [String: Any])?["accessToken"] as? String }
    }
    let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "Claude Code-credentials",
                            kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
    var r: CFTypeRef?
    let st = SecItemCopyMatching(q as CFDictionary, &r)
    log("keychain status=\(st)")
    if st == errSecSuccess, let d = r as? Data {
        if let t = parse(d) { return t }
        log("keychain item found but no claudeAiOauth.accessToken (bytes=\(d.count))")
    }
    let hasFile = FileManager.default.fileExists(atPath: home + "/.claude/.credentials.json")
    log("credentials file exists=\(hasFile)")
    if let d = FileManager.default.contents(atPath: home + "/.claude/.credentials.json") { return parse(d) }
    return nil
}

func claudeUsage() -> Tool {
    let none = Tool(id: "claude", name: "Claude", ok: false, wins: [])
    if skipClaude { return none }
    if let c = claudeCache, Date().timeIntervalSince(c.0) < 300 { return c.1 }
    if claudeToken == nil { claudeToken = readClaudeToken() }
    if claudeToken == nil { log("no claude token") }
    guard let tok = claudeToken, let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return claudeCache?.1 ?? none }
    var req = URLRequest(url: url, timeoutInterval: 10)
    req.setValue("Bearer " + tok, forHTTPHeaderField: "Authorization")
    req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
    req.setValue("UsageBar", forHTTPHeaderField: "User-Agent")
    var out: Data?; var code = 0
    let sem = DispatchSemaphore(value: 0)
    URLSession.shared.dataTask(with: req) { d, r, _ in out = d; code = (r as? HTTPURLResponse)?.statusCode ?? 0; sem.signal() }.resume()
    sem.wait()
    log("usage api http=\(code) body=\(String(decoding: (out ?? Data()).prefix(300), as: UTF8.self))")
    if code == 401 { claudeToken = nil; claudeNote = L("expired") }
    else if code == 200 { claudeNote = "" }
    guard code == 200, let d = out, let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return claudeCache?.1 ?? none }
    let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let iso2 = ISO8601DateFormatter()
    var wins: [Win] = []
    for (k, label) in [("five_hour", "5h"), ("seven_day", L("week"))] {
        if let w = j[k] as? [String: Any], let u = (w["utilization"] as? NSNumber)?.doubleValue {
            let ts = (w["resets_at"] as? String).flatMap { iso.date(from: $0) ?? iso2.date(from: $0) }?.timeIntervalSince1970
            wins.append(Win(label: label, used: u, resets: ts))
        }
    }
    let t = Tool(id: "claude", name: "Claude", ok: !wins.isEmpty, wins: wins)
    if t.ok { claudeCache = (Date(), t) }
    return t
}

func fetch() -> (Double, [Tool]) { (Date().timeIntervalSince1970, [claudeUsage(), codexUsage()]) }

func absTime(_ ts: Double?) -> String {
    guard let ts = ts else { return "" }
    let f = DateFormatter(); f.locale = Locale.current; f.setLocalizedDateFormatFromTemplate("EEE jmm")
    return f.string(from: Date(timeIntervalSince1970: ts))
}
func levelColor(_ left: Double?) -> Color {
    guard let l = left else { return .gray }
    return l > 40 ? Color(red: 0.20, green: 0.78, blue: 0.45) : (l > 15 ? Color(red: 1.0, green: 0.68, blue: 0.1) : Color(red: 1.0, green: 0.27, blue: 0.23))
}
func remain(_ ts: Double?, now: Double) -> String {
    guard let ts = ts else { return "–" }
    let s = Int(ts - now); if s <= 0 { return L("done") }
    let d = s / 86400, h = (s % 86400) / 3600, m = (s % 3600) / 60
    return d > 0 ? LF("dh", d, h) : (h > 0 ? LF("hm", h, m) : LF("min", m))
}

struct Ring: View {
    let left: Double?; let size: CGFloat; let line: CGFloat
    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: line)
            Circle().trim(from: 0, to: CGFloat((left ?? 0) / 100))
                .stroke(levelColor(left), style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.frame(width: size, height: size)
    }
}

final class Model: ObservableObject { @Published var note = ""; @Published var now = Date().timeIntervalSince1970; @Published var tools: [Tool] = [] }


struct Tile: View {
    let t: Tool; let now: Double
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Ring(left: t.left, size: 70, line: 8)
                VStack(spacing: -1) {
                    Text(t.left.map { "\(Int($0.rounded()))" } ?? "–").font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text("%").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                }
            }
            Text(t.name).font(.system(size: 12, weight: .semibold))
            ForEach(t.wins) { w in
                VStack(spacing: 1) {
                    Text("\(w.label) · \(Int((100 - w.used).rounded()))% \(L("left"))").font(.system(size: 10, weight: .medium))
                    Text(LS("resets", remain(w.resets, now: now))).font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(absTime(w.resets)).font(.system(size: 9)).foregroundStyle(.tertiary)
                }.padding(.top, 2)
            }
        }.frame(minWidth: 112)
    }
}

struct Widget: View {
    @ObservedObject var m: Model
    var body: some View {
        VStack(spacing: 10) {
        HStack(alignment: .top, spacing: 14) {
            ForEach(m.tools.filter { $0.ok }) { Tile(t: $0, now: m.now) }
            if !m.tools.contains(where: { $0.ok }) {
                Text(L("empty")).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
            if !m.note.isEmpty { Text(m.note).font(.system(size: 10)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 220) }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(VisualEffect())
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 0.5))
    }
}
struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView { let v = NSVisualEffectView(); v.material = .hudWindow; v.blendingMode = .behindWindow; v.state = .active; return v }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

final class App: NSObject, NSApplicationDelegate {
    let model = Model(); var panel: NSPanel!; var host: NSHostingView<Widget>!
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var showWidget: Bool { get { UserDefaults.standard.object(forKey: "showWidget") as? Bool ?? true } set { UserDefaults.standard.set(newValue, forKey: "showWidget") } }
    func applicationDidFinishLaunching(_ n: Notification) {
        host = NSHostingView(rootView: Widget(m: model))
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 150), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.contentView = host; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.level = .floating; panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        host.menu = buildMenu(); item.menu = buildMenu(); item.button?.title = "…"
        if let f = UserDefaults.standard.string(forKey: "pos") { panel.setFrameOrigin(NSPointFromString(f)) } else { place() }
        NotificationCenter.default.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main) { _ in
            UserDefaults.standard.set(NSStringFromPoint(self.panel.frame.origin), forKey: "pos") }
        if showWidget { panel.orderFrontRegardless() }
        refresh(); Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in self.refresh() }
    }
    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        for t in model.tools where t.ok {
            let h = NSMenuItem(title: t.name, action: nil, keyEquivalent: ""); h.isEnabled = false
            h.attributedTitle = NSAttributedString(string: t.name, attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]); menu.addItem(h)
            for w in t.wins {
                let r = LS("resets", remain(w.resets, now: model.now)); let at = absTime(w.resets)
                let m = NSMenuItem(title: "  \(w.label) · \(Int((100 - w.used).rounded()))% \(L("left")) · \(r) (\(at))", action: nil, keyEquivalent: "")
                m.isEnabled = false; menu.addItem(m)
            }
            menu.addItem(.separator())
        }
        if !model.note.isEmpty { let n = NSMenuItem(title: model.note, action: nil, keyEquivalent: ""); n.isEnabled = false; menu.addItem(n); menu.addItem(.separator()) }
        let w = menu.addItem(withTitle: L("widget"), action: #selector(toggleWidget(_:)), keyEquivalent: ""); w.target = self; w.state = showWidget ? .on : .off
        menu.addItem(withTitle: L("refresh"), action: #selector(doRefresh), keyEquivalent: "r").target = self
        let li = menu.addItem(withTitle: L("login"), action: #selector(toggleLogin(_:)), keyEquivalent: ""); li.target = self
        li.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(withTitle: L("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
    func updateBar() {
        let parts = model.tools.filter { $0.ok }.compactMap { t in t.left.map { "\(t.id == "claude" ? "Cl" : "Cx") \(Int($0.rounded()))%" } }
        item.button?.title = parts.isEmpty ? "–" : parts.joined(separator: " · ")
        item.menu = buildMenu(); host.menu = buildMenu()
    }
    @objc func toggleWidget(_ i: NSMenuItem) {
        showWidget.toggle()
        if showWidget { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
        updateBar()
    }
    func place() {
        guard let v = NSScreen.main?.visibleFrame else { return }
        let sz = host.fittingSize
        panel.setFrameOrigin(NSPoint(x: v.maxX - sz.width - 20, y: v.maxY - sz.height - 12))
    }
    func refresh() {
        DispatchQueue.global().async {
            let (now, tools) = fetch()
            DispatchQueue.main.async {
                self.model.now = now; self.model.tools = tools; self.model.note = claudeNote; self.updateBar()
                DispatchQueue.main.async {
                    let top = self.panel.frame.maxY, right = self.panel.frame.maxX, sz = self.host.fittingSize
                    self.panel.setFrame(NSRect(x: right - sz.width, y: top - sz.height, width: sz.width, height: sz.height), display: true)
                }
            }
        }
    }
    @objc func doRefresh() { refresh() }
    @objc func toggleLogin(_ i: NSMenuItem) {
        if SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister(); i.state = .off }
        else { try? SMAppService.mainApp.register(); i.state = .on }
    }
}
let app = NSApplication.shared; let del = App(); app.delegate = del
app.setActivationPolicy(.accessory); app.run()

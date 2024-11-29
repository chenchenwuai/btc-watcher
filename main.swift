import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    private var currentPrice: String = "加载中..."
    private var currentSymbol: String = "BTCUSDT"
    private var currentIcon: String = "₿"
    private var isEnglish: Bool = false
    private var currentApiIndex: Int = 0
    private var isAutoSwitchApi: Bool = true
    private var failedAttempts: Int = 0
    
    private let apiEndpoints = [
        "https://api.binance.com/api/v3/ticker/price",
        "https://api1.binance.com/api/v3/ticker/price",
        "https://api2.binance.com/api/v3/ticker/price",
        "https://api3.binance.com/api/v3/ticker/price",
        "https://api4.binance.com/api/v3/ticker/price"
    ]
    
    private var symbols = [
        ("BTC", "BTCUSDT", "₿"),
        ("ETH", "ETHUSDT", "Ξ"),
        ("DOGE", "DOGEUSDT", "Ð")
    ]
    
    // 语言本地化
    private let localizedStrings: [String: [Bool: String]] = [
        "loading": [true: "Loading...", false: "加载中..."],
        "addCoin": [true: "Add Custom Coin...", false: "添加自定义币种..."],
        "updateInterval": [true: "Update Interval", false: "更新频率"],
        "language": [true: "切换到中文", false: "Switch to English"],
        "quit": [true: "Quit", false: "退出"],
        "addCoinTitle": [true: "Add Custom Coin", false: "添加自定义币种"],
        "addCoinMsg": [true: "Enter the coin symbol (e.g., BTCUSDT):", false: "输入币种代码（例如：BTCUSDT）："],
        "ok": [true: "OK", false: "确定"],
        "cancel": [true: "Cancel", false: "取消"],
        "error": [true: "Error", false: "错误"],
        "invalidCoin": [true: "Invalid coin symbol or API error", false: "无效的币种代码或API错误"],
        "apiEndpoint": [true: "API Endpoint", false: "API接口"],
        "autoSwitch": [true: "Auto Switch API", false: "自动切换API"],
        "manualApi": [true: "Manual API", false: "手动选择API"],
        "api": [true: "API", false: "接口"],
        "about": [true: "About", false: "关于"],
        "aboutTitle": [true: "About BTC Watcher", false: "关于 BTC Watcher"],
        "aboutMessage": [true: """
            BTC Watcher v1.0
            
            A lightweight cryptocurrency price tracking app for macOS.
            
            Features:
            • Real-time price updates
            • Multiple coins support (BTC, ETH, DOGE, etc.)
            • Custom coin addition
            • Auto API switching
            • Multi-language support
            
            Created by chenwuai
            """,
            false: """
            BTC Watcher v1.0
            
            一个轻量级的 macOS 加密货币价格跟踪应用。
            
            功能特点：
            • 实时价格更新
            • 支持多种币种（BTC、ETH、DOGE 等）
            • 自定义币种添加
            • 自动API切换
            • 多语言支持
            
            由 chenwuai 开发
            """]
    ]
    
    func localized(_ key: String) -> String {
        return localizedStrings[key]?[isEnglish] ?? key
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 设置菜单栏显示
        if let button = statusItem.button {
            button.image = nil
            button.title = "\(currentIcon) \(currentPrice)"
        }
        
        setupMenu()
        startTimer()
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // Add Custom Coin menu item
        menu.addItem(NSMenuItem(title: localized("addCoin"), action: #selector(addCustomCoin), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())
        
        // Coins submenu
        for (name, symbol, _) in symbols {
            let item = NSMenuItem(title: name, action: #selector(switchCoin(_:)), keyEquivalent: "")
            item.representedObject = symbol
            item.state = symbol == currentSymbol ? .on : .off
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Update Interval submenu
        menu.addItem(NSMenuItem(title: localized("updateInterval"), action: nil, keyEquivalent: ""))
        let intervalSubmenu = NSMenu()
        intervalSubmenu.addItem(NSMenuItem(title: "1s", action: #selector(setInterval1s), keyEquivalent: "1"))
        intervalSubmenu.addItem(NSMenuItem(title: "2s", action: #selector(setInterval2s), keyEquivalent: "2"))
        intervalSubmenu.addItem(NSMenuItem(title: "5s", action: #selector(setInterval5s), keyEquivalent: "5"))
        if let intervalItem = menu.item(at: menu.items.count - 1) {
            menu.setSubmenu(intervalSubmenu, for: intervalItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // API Endpoint submenu
        menu.addItem(NSMenuItem(title: localized("apiEndpoint"), action: nil, keyEquivalent: ""))
        let apiSubmenu = NSMenu()
        
        // Auto switch option
        let autoItem = NSMenuItem(title: localized("autoSwitch"), action: #selector(toggleAutoSwitch), keyEquivalent: "a")
        autoItem.state = isAutoSwitchApi ? .on : .off
        apiSubmenu.addItem(autoItem)
        
        apiSubmenu.addItem(NSMenuItem.separator())
        
        // Manual API selection
        for (index, _) in apiEndpoints.enumerated() {
            let item = NSMenuItem(title: "\(localized("api")) \(index + 1)", action: #selector(switchApi(_:)), keyEquivalent: "")
            item.representedObject = index
            item.state = (index == currentApiIndex && !isAutoSwitchApi) ? .on : .off
            apiSubmenu.addItem(item)
        }
        
        if let apiItem = menu.item(at: menu.items.count - 1) {
            menu.setSubmenu(apiSubmenu, for: apiItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Language switcher
        menu.addItem(NSMenuItem(title: localized("language"), action: #selector(toggleLanguage), keyEquivalent: "l"))
        
        menu.addItem(NSMenuItem.separator())
        
        // About menu item
        menu.addItem(NSMenuItem(title: localized("about"), action: #selector(showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: localized("quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func toggleAutoSwitch() {
        isAutoSwitchApi.toggle()
        setupMenu()
    }
    
    @objc func switchApi(_ sender: NSMenuItem) {
        if let index = sender.representedObject as? Int {
            currentApiIndex = index
            isAutoSwitchApi = false
            setupMenu()
            updatePrice() // 立即更新价格以测试新API
        }
    }
    
    func getCurrentApiEndpoint() -> String {
        return apiEndpoints[currentApiIndex]
    }
    
    func switchToNextApi() {
        currentApiIndex = (currentApiIndex + 1) % apiEndpoints.count
        print("Switching to API \(currentApiIndex + 1)")
    }
    
    func validateAndAddCoin(_ symbol: String) {
        // 检查是否已存在
        if symbols.contains(where: { $0.1 == symbol }) {
            DispatchQueue.main.async {
                self.currentSymbol = symbol
                if let (_, _, icon) = self.symbols.first(where: { $0.1 == symbol }) {
                    self.currentIcon = icon
                }
                self.setupMenu()
                self.updatePrice()
            }
            return
        }
        
        guard let url = URL(string: "\(getCurrentApiEndpoint())?symbol=\(symbol)") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let _ = json["price"] as? String
            else {
                DispatchQueue.main.async {
                    self?.showError("invalidCoin")
                }
                return
            }
            
            DispatchQueue.main.async {
                let name = symbol.replacingOccurrences(of: "USDT", with: "")
                self.symbols.append((name, symbol, name))
                self.currentSymbol = symbol
                self.currentIcon = name
                self.setupMenu()
                self.updatePrice()
            }
        }.resume()
    }
    
    func formatPrice(_ price: Double) -> String {
        // 对于小于0.01的价格显示8位小数
        // 对于0.01-1之间的价格显示6位小数
        // 对于1-100之间的价格显示4位小数
        // 对于100以上的价格显示2位小数
        let decimals: Int
        if price < 0.01 {
            decimals = 8
        } else if price < 1 {
            decimals = 6
        } else if price < 100 {
            decimals = 4
        } else {
            decimals = 2
        }
        
        // 格式化价格
        let formattedPrice = String(format: "%.\(decimals)f", price)
        
        // 移除末尾的0，但保留小数点后至少一位
        var trimmed = formattedPrice
        while trimmed.hasSuffix("0") && trimmed.contains(".") && trimmed.split(separator: ".")[1].count > 1 {
            trimmed.removeLast()
        }
        
        return trimmed
    }
    
    func updatePrice() {
        guard let url = URL(string: "\(apiEndpoints[currentApiIndex])?symbol=\(currentSymbol)") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error: \(error.localizedDescription)")
                self.handleApiError()
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let priceString = json["price"] as? String,
               let priceValue = Double(priceString) {
                DispatchQueue.main.async {
                    self.failedAttempts = 0
                    self.currentPrice = self.formatPrice(priceValue)
                    self.statusItem.button?.title = "\(self.currentIcon) \(self.currentPrice)"
                }
            }
        }.resume()
    }
    
    @objc func toggleLanguage() {
        isEnglish.toggle()
        setupMenu()
    }
    
    @objc func addCustomCoin() {
        let alert = NSAlert()
        alert.messageText = localized("addCoinTitle")
        alert.informativeText = localized("addCoinMsg")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "BTCUSDT"
        alert.accessoryView = input
        alert.addButton(withTitle: localized("ok"))
        alert.addButton(withTitle: localized("cancel"))
        
        NSApp.activate(ignoringOtherApps: true)
        
        // 显示对话框
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let symbol = input.stringValue.uppercased()
            if !symbol.isEmpty {
                validateAndAddCoin(symbol)
            }
        }
    }
    
    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = localized("error")
        alert.informativeText = localized(message)
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    func startTimer(interval: TimeInterval = 2.0) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updatePrice()
        }
        timer?.fire()
    }
    
    @objc func switchCoin(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        currentSymbol = symbol
        if let (_, _, icon) = symbols.first(where: { $0.1 == symbol }) {
            currentIcon = icon
        }
        setupMenu()
        updatePrice()
    }
    
    @objc func setInterval1s() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updatePrice()
        }
        setupMenu()
    }
    
    @objc func setInterval2s() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updatePrice()
        }
        setupMenu()
    }
    
    @objc func setInterval5s() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updatePrice()
        }
        setupMenu()
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = localized("aboutTitle")
        alert.informativeText = localized("aboutMessage")
        alert.window.maxSize = NSSize(width: 500, height: 1000)  // 增加最大宽度
        alert.window.minSize = NSSize(width: 400, height: 200)   // 设置最小宽度
        alert.alertStyle = .informational
        
        // 添加应用图标
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            alert.icon = image
        }
        
        alert.addButton(withTitle: localized("ok"))
        alert.runModal()
    }
    
    func handleApiError() {
        failedAttempts += 1
        
        if isAutoSwitchApi && failedAttempts >= 3 {
            switchToNextApi()
            failedAttempts = 0
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

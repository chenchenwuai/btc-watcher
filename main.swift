import Cocoa

struct CoinSymbol: Codable {
    let name: String
    let symbol: String
    let icon: String
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    private var currentPrice: String = "Loading..."
    private var currentSymbol: String = "BTCUSDT"
    private var currentIcon: String = "₿"
    private var isEnglish: Bool = true
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
    
    private let defaultSymbols = [
        ("BTC", "BTCUSDT", "₿"),
        ("ETH", "ETHUSDT", "Ξ"),
        ("DOGE", "DOGEUSDT", "Ð")
    ]
    
    private func loadCustomSymbols() {
        if let savedData = UserDefaults.standard.data(forKey: "customSymbols"),
           let savedSymbols = try? JSONDecoder().decode([CoinSymbol].self, from: savedData) {
            let customTuples = savedSymbols.map { ($0.name, $0.symbol, $0.icon) }
            symbols = defaultSymbols + customTuples
        } else {
            symbols = defaultSymbols
        }
    }
    
    private func saveCustomSymbols() {
        let customSymbols = symbols.filter { symbol in
            !defaultSymbols.contains(where: { $0 == symbol })
        }
        let coinSymbols = customSymbols.map { CoinSymbol(name: $0.0, symbol: $0.1, icon: $0.2) }
        if let encodedData = try? JSONEncoder().encode(coinSymbols) {
            UserDefaults.standard.set(encodedData, forKey: "customSymbols")
        }
    }
    
    // Localization
    // 在 localizedStrings 中添加
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
            BTC Watcher v1.1.0
            
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
            BTC Watcher v1.1.0
            
            一个轻量级的 macOS 加密货币价格跟踪应用。
            
            功能特点：
            • 实时价格更新
            • 支持多种币种（BTC、ETH、DOGE 等）
            • 自定义币种添加
            • 自动API切换
            • 多语言支持
            
            由 chenwuai 开发
            """],
        "feedback": [true: "Feedback", false: "反馈"],
        "help": [true: "Help", false: "帮助"],
        "settings": [true: "Settings", false: "设置"],
        "delete": [true: "Delete", false: "删除"],
        "viewContract": [true: "View Contract", false: "查看合约"],
    ]
    
    func localized(_ key: String) -> String {
        return localizedStrings[key]?[isEnglish] ?? key
    }
    
    func getCurrentApiEndpoint() -> String {
        return apiEndpoints[currentApiIndex]
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
    
    func switchToNextApi() {
        currentApiIndex = (currentApiIndex + 1) % apiEndpoints.count
        print("Switching to API \(currentApiIndex + 1)")
    }
    
    func formatPrice(_ price: Double) -> String {
        // Format price based on its value
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
        
        // Format price
        let formattedPrice = String(format: "%.\(decimals)f", price)
        
        // Remove trailing zeros, but keep at least one decimal place
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
    
    func validateAndAddCoin(_ symbol: String) {
        // Check if the coin already exists
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
            guard let self,
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
                // 保存自定义交易对
                self.saveCustomSymbols()
                // 保存最后选择的交易对
                UserDefaults.standard.set(symbol, forKey: "lastSymbol")
                self.setupMenu()
                self.updatePrice()
            }
        }.resume()
    }
    
    @objc func addCustomCoin() {
        let alert = NSAlert()
        alert.messageText = localized("addCoinTitle")
        alert.informativeText = localized("addCoinMsg")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "BTC"
        alert.accessoryView = input
        alert.addButton(withTitle: localized("ok"))
        alert.addButton(withTitle: localized("cancel"))
        
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            input.window?.makeFirstResponder(input)
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            var symbol = input.stringValue.uppercased()
            if !symbol.hasSuffix("USDT") {
                symbol += "USDT"
            }
            if !symbol.isEmpty {
                validateAndAddCoin(symbol)
            }
        }
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
            
            if !defaultSymbols.contains(where: { $0.1 == symbol }) {
                let deleteItem = NSMenuItem(title: localized("delete"), action: #selector(deleteCoin(_:)), keyEquivalent: "")
                deleteItem.representedObject = symbol
                item.submenu = NSMenu()
                item.submenu?.addItem(deleteItem)
            }
            
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add contract link menu item
        let contractUrl = isEnglish 
            ? "https://www.binance.com/en/futures/\(currentSymbol)"
            : "https://www.binance.com/zh-CN/futures/\(currentSymbol)"
        let contractItem = NSMenuItem(title: localized("viewContract"), action: #selector(openContract), keyEquivalent: "")
        contractItem.representedObject = contractUrl
        menu.addItem(contractItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings submenu
        let settingsItem = NSMenuItem(title: localized("settings"), action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()
        
        // Update Interval submenu
        let intervalItem = NSMenuItem(title: localized("updateInterval"), action: nil, keyEquivalent: "")
        let intervalSubmenu = NSMenu()
        intervalSubmenu.addItem(NSMenuItem(title: "1s", action: #selector(setInterval1s), keyEquivalent: "1"))
        intervalSubmenu.addItem(NSMenuItem(title: "2s", action: #selector(setInterval2s), keyEquivalent: "2"))
        intervalSubmenu.addItem(NSMenuItem(title: "5s", action: #selector(setInterval5s), keyEquivalent: "5"))
        settingsSubmenu.addItem(intervalItem)
        settingsSubmenu.setSubmenu(intervalSubmenu, for: intervalItem)
        
        // API settings
        let apiItem = NSMenuItem(title: localized("apiEndpoint"), action: nil, keyEquivalent: "")
        let apiSubmenu = NSMenu()
        let autoItem = NSMenuItem(title: localized("autoSwitch"), action: #selector(toggleAutoSwitch), keyEquivalent: "a")
        autoItem.state = isAutoSwitchApi ? NSControl.StateValue.on : NSControl.StateValue.off
        apiSubmenu.addItem(autoItem)
        apiSubmenu.addItem(NSMenuItem.separator())
        
        for (index, _) in apiEndpoints.enumerated() {
            let item = NSMenuItem(title: "\(localized("api")) \(index + 1)", action: #selector(switchApi(_:)), keyEquivalent: "")
            item.representedObject = index
            item.state = (index == currentApiIndex && !isAutoSwitchApi) ? NSControl.StateValue.on : NSControl.StateValue.off
            apiSubmenu.addItem(item)
        }
        settingsSubmenu.addItem(apiItem)
        settingsSubmenu.setSubmenu(apiSubmenu, for: apiItem)
        
        menu.addItem(settingsItem)
        menu.setSubmenu(settingsSubmenu, for: settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Language switcher
        menu.addItem(NSMenuItem(title: localized("language"), action: #selector(toggleLanguage), keyEquivalent: "l"))
        
        menu.addItem(NSMenuItem.separator())
        
        // Help submenu
        let helpItem = NSMenuItem(title: localized("help"), action: nil, keyEquivalent: "")
        let helpSubmenu = NSMenu()
        
        helpSubmenu.addItem(NSMenuItem(title: localized("about"), action: #selector(showAbout), keyEquivalent: ""))
        helpSubmenu.addItem(NSMenuItem(title: localized("feedback"), action: #selector(openFeedback), keyEquivalent: ""))
        
        menu.addItem(helpItem)
        menu.setSubmenu(helpSubmenu, for: helpItem)
        
        // Quit menu item
        menu.addItem(NSMenuItem(title: localized("quit"), action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 加载语言设置
        isEnglish = UserDefaults.standard.bool(forKey: "isEnglish")
        
        loadCustomSymbols()
        
        // 加载上次选择的交易对
        if let lastSymbol = UserDefaults.standard.string(forKey: "lastSymbol"),
           let lastIcon = symbols.first(where: { $0.1 == lastSymbol })?.2 {
            currentSymbol = lastSymbol
            currentIcon = lastIcon
        }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Set up menu bar display
        if let button = statusItem.button {
            button.image = nil
            button.title = "\(currentIcon) \(currentPrice)"
        }
        
        setupMenu()
        startTimer()
    }

    @objc func switchCoin(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        currentSymbol = symbol
        if let (_, _, icon) = symbols.first(where: { $0.1 == symbol }) {
            currentIcon = icon
            // 保存当前选择的交易对
            UserDefaults.standard.set(symbol, forKey: "lastSymbol")
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
    
    @objc func toggleAutoSwitch() {
        isAutoSwitchApi = !isAutoSwitchApi
        UserDefaults.standard.set(isAutoSwitchApi, forKey: "autoSwitchApi")
        setupMenu()
    }
    
    @objc func switchApi(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        currentApiIndex = index
        isAutoSwitchApi = false
        UserDefaults.standard.set(currentApiIndex, forKey: "currentApiIndex")
        UserDefaults.standard.set(isAutoSwitchApi, forKey: "autoSwitchApi")
        setupMenu()
        updatePrice()
    }
    
    @objc func toggleLanguage() {
        isEnglish = !isEnglish
        UserDefaults.standard.set(isEnglish, forKey: "isEnglish")
        setupMenu()
        currentPrice = localized("loading")
        updatePrice()
    }
    
    @objc func deleteCoin(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        
        // 如果当前显示的是要删除的币种，切换到 BTC
        if symbol == currentSymbol {
            currentSymbol = "BTCUSDT"
            currentIcon = "₿"
        }
        
        // 从数组中移除
        symbols.removeAll(where: { $0.1 == symbol })
        
        // 保存更新后的自定义交易对
        saveCustomSymbols()
        
        // 刷新菜单
        setupMenu()
        
        // 如果需要，更新显示
        if symbol == currentSymbol {
            updatePrice()
        }
    }
    
    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = localized("aboutTitle")
        alert.informativeText = localized("aboutMessage")
        alert.window.maxSize = NSSize(width: 500, height: 1000)  // Increase maximum width
        alert.window.minSize = NSSize(width: 400, height: 200)   // Set minimum width
        alert.alertStyle = .informational
        
        // Add application icon
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            alert.icon = image
        }
        
        alert.addButton(withTitle: localized("ok"))
        alert.runModal()
    }
    
    @objc func openFeedback() {
        if let url = URL(string: "https://github.com/chenchenwuai/btc-watcher/issues") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func handleApiError() {
        failedAttempts += 1
        
        if isAutoSwitchApi && failedAttempts >= 3 {
            switchToNextApi()
            failedAttempts = 0
        }
    }
    
    @objc func openContract(_ sender: NSMenuItem) {
        if let urlString = sender.representedObject as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

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
    
    private var isFuturesMode: Bool = false
    private var proxyHost: String = "127.0.0.1"
    private var proxyPort: String = "7890"
    private var isProxyEnabled: Bool = false
    private var urlSession: URLSession = URLSession.shared
    private var basePrices: [String: Double] = [:]
    
    private var apiEndpoints: [String] {
        return isFuturesMode ? Constants.futuresApiEndpoints : Constants.spotApiEndpoints
    }
    
    private var symbols = Constants.defaultSymbols
    private let defaultSymbols = Constants.defaultSymbols
    
    func localized(_ key: String) -> String {
        return Constants.localized(key, isEnglish: isEnglish)
    }
    
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
    
    func getCurrentApiEndpoint() -> String {
        return apiEndpoints[currentApiIndex]
    }
    
    private func configureUrlSession() {
        if isProxyEnabled && !proxyHost.isEmpty {
            let config = URLSessionConfiguration.default
            config.connectionProxyDictionary = [
                kCFNetworkProxiesSOCKSProxy: proxyHost,
                kCFNetworkProxiesSOCKSPort: Int(proxyPort) ?? 1080,
                kCFNetworkProxiesSOCKSEnable: 1
            ]
            urlSession = URLSession(configuration: config)
        } else {
            urlSession = URLSession.shared
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
    
    func switchToNextApi() {
        currentApiIndex = (currentApiIndex + 1) % apiEndpoints.count
        print("Switching to API \(currentApiIndex + 1)")
    }
    
    func calculateChangePercent(current: Double, base: Double?) -> String {
        guard let base = base, base > 0 else { return "" }
        let percent = ((current - base) / base) * 100
        let sign = percent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, percent)
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
        
        urlSession.dataTask(with: url) { [weak self] data, response, error in
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
                    let basePrice = self.basePrices[self.currentSymbol]
                    let changeStr = self.calculateChangePercent(current: priceValue, base: basePrice)
                    let displayTitle = changeStr.isEmpty ? "\(self.currentIcon) \(self.currentPrice)" : "\(self.currentIcon) \(self.currentPrice) (\(changeStr))"
                    self.statusItem.button?.title = displayTitle
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
        
        urlSession.dataTask(with: url) { [weak self] data, response, error in
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
            
            // 为每个币种添加子菜单
            let coinSubmenu = NSMenu()
            
            // 设置基准价
            let setBaseItem = NSMenuItem(title: localized("setBasePrice"), action: #selector(setBasePrice(_:)), keyEquivalent: "")
            setBaseItem.representedObject = symbol
            coinSubmenu.addItem(setBaseItem)
            
            // 清除基准价（如果已设置）
            if basePrices[symbol] != nil {
                let clearBaseItem = NSMenuItem(title: localized("clearBasePrice"), action: #selector(clearBasePrice(_:)), keyEquivalent: "")
                clearBaseItem.representedObject = symbol
                coinSubmenu.addItem(clearBaseItem)
            }
            
            // 删除自定义币种
            if !defaultSymbols.contains(where: { $0.1 == symbol }) {
                coinSubmenu.addItem(NSMenuItem.separator())
                let deleteItem = NSMenuItem(title: localized("delete"), action: #selector(deleteCoin(_:)), keyEquivalent: "")
                deleteItem.representedObject = symbol
                coinSubmenu.addItem(deleteItem)
            }
            
            if coinSubmenu.items.count > 0 {
                item.submenu = coinSubmenu
            }
            
            menu.addItem(item)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Add contract link menu item
        let contractUrl = Constants.getContractUrl(symbol: currentSymbol, isEnglish: isEnglish)
        let contractItem = NSMenuItem(title: localized("viewContract"), action: #selector(openContract), keyEquivalent: "")
        contractItem.representedObject = contractUrl
        menu.addItem(contractItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings submenu
        let settingsItem = NSMenuItem(title: localized("settings"), action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()
        
        // Trading Mode submenu
        let tradingModeItem = NSMenuItem(title: localized("tradingMode"), action: nil, keyEquivalent: "")
        let tradingModeSubmenu = NSMenu()
        let spotItem = NSMenuItem(title: localized("spotMode"), action: #selector(setSpotMode), keyEquivalent: "")
        spotItem.state = !isFuturesMode ? .on : .off
        tradingModeSubmenu.addItem(spotItem)
        let futuresItem = NSMenuItem(title: localized("futuresMode"), action: #selector(setFuturesMode), keyEquivalent: "")
        futuresItem.state = isFuturesMode ? .on : .off
        tradingModeSubmenu.addItem(futuresItem)
        settingsSubmenu.addItem(tradingModeItem)
        settingsSubmenu.setSubmenu(tradingModeSubmenu, for: tradingModeItem)
        
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
        
        // Proxy Settings submenu
        let proxyItem = NSMenuItem(title: localized("proxySettings"), action: nil, keyEquivalent: "")
        let proxySubmenu = NSMenu()
        let enableProxyItem = NSMenuItem(title: localized("enableProxy"), action: #selector(toggleProxy), keyEquivalent: "")
        enableProxyItem.state = isProxyEnabled ? .on : .off
        proxySubmenu.addItem(enableProxyItem)
        proxySubmenu.addItem(NSMenuItem.separator())
        let proxyHostItem = NSMenuItem(title: "\(localized("proxyHost")): \(proxyHost)", action: #selector(setProxyHost), keyEquivalent: "")
        proxySubmenu.addItem(proxyHostItem)
        let proxyPortItem = NSMenuItem(title: "\(localized("proxyPort")): \(proxyPort)", action: #selector(setProxyPort), keyEquivalent: "")
        proxySubmenu.addItem(proxyPortItem)
        settingsSubmenu.addItem(proxyItem)
        settingsSubmenu.setSubmenu(proxySubmenu, for: proxyItem)
        
        menu.addItem(settingsItem)
        menu.setSubmenu(settingsSubmenu, for: settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Language switcher
        menu.addItem(NSMenuItem(title: localized("language"), action: #selector(toggleLanguage), keyEquivalent: "l"))
        
        menu.addItem(NSMenuItem.separator())
        
        // 在 setupMenu 函数中的帮助菜单部分：
        // Help submenu
        let helpItem = NSMenuItem(title: localized("help"), action: nil, keyEquivalent: "")
        let helpSubmenu = NSMenu()
        
        helpSubmenu.addItem(NSMenuItem(title: localized("version") + " " + Constants.appVersion, action: nil, keyEquivalent: ""))
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
        
        // 加载交易模式设置
        isFuturesMode = UserDefaults.standard.bool(forKey: "isFuturesMode")
        
        // 加载代理设置
        isProxyEnabled = UserDefaults.standard.bool(forKey: "isProxyEnabled")
        if let savedProxyHost = UserDefaults.standard.string(forKey: "proxyHost"), !savedProxyHost.isEmpty {
            proxyHost = savedProxyHost
        }
        if let savedProxyPort = UserDefaults.standard.string(forKey: "proxyPort"), !savedProxyPort.isEmpty {
            proxyPort = savedProxyPort
        }
        
        // 配置 URLSession（根据代理设置）
        configureUrlSession()
        
        // 加载基准价设置
        if let savedBasePrices = UserDefaults.standard.dictionary(forKey: "basePrices") as? [String: Double] {
            basePrices = savedBasePrices
        }
        
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
        if let url = URL(string: Constants.feedbackUrl) {
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
    
    @objc func setSpotMode() {
        isFuturesMode = false
        UserDefaults.standard.set(isFuturesMode, forKey: "isFuturesMode")
        currentApiIndex = 0
        setupMenu()
        updatePrice()
    }
    
    @objc func setFuturesMode() {
        isFuturesMode = true
        UserDefaults.standard.set(isFuturesMode, forKey: "isFuturesMode")
        currentApiIndex = 0
        setupMenu()
        updatePrice()
    }
    
    @objc func toggleProxy() {
        isProxyEnabled = !isProxyEnabled
        UserDefaults.standard.set(isProxyEnabled, forKey: "isProxyEnabled")
        configureUrlSession()
        setupMenu()
    }
    
    @objc func setProxyHost() {
        let alert = NSAlert()
        alert.messageText = localized("proxySettings")
        alert.informativeText = localized("proxyHost")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = proxyHost
        input.placeholderString = "127.0.0.1"
        alert.accessoryView = input
        alert.addButton(withTitle: localized("ok"))
        alert.addButton(withTitle: localized("cancel"))
        
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            input.window?.makeFirstResponder(input)
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let newHost = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !newHost.isEmpty {
                proxyHost = newHost
                UserDefaults.standard.set(proxyHost, forKey: "proxyHost")
                configureUrlSession()
                setupMenu()
            }
        }
    }
    
    @objc func setProxyPort() {
        let alert = NSAlert()
        alert.messageText = localized("proxySettings")
        alert.informativeText = localized("proxyPort")
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.stringValue = proxyPort
        input.placeholderString = "7890"
        alert.accessoryView = input
        alert.addButton(withTitle: localized("ok"))
        alert.addButton(withTitle: localized("cancel"))
        
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            input.window?.makeFirstResponder(input)
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let newPort = input.stringValue.trimmingCharacters(in: .whitespaces)
            if !newPort.isEmpty && Int(newPort) != nil {
                proxyPort = newPort
                UserDefaults.standard.set(proxyPort, forKey: "proxyPort")
                configureUrlSession()
                setupMenu()
            }
        }
    }
    
    @objc func setBasePrice(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        
        let alert = NSAlert()
        alert.messageText = localized("setBasePrice")
        alert.informativeText = "\(symbol)"
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = "60000.00"
        if let existingPrice = basePrices[symbol] {
            input.stringValue = String(existingPrice)
        }
        alert.accessoryView = input
        alert.addButton(withTitle: localized("ok"))
        alert.addButton(withTitle: localized("cancel"))
        
        NSApp.activate(ignoringOtherApps: true)
        
        DispatchQueue.main.async {
            input.window?.makeFirstResponder(input)
        }
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let priceString = input.stringValue.trimmingCharacters(in: .whitespaces)
            if let price = Double(priceString), price > 0 {
                basePrices[symbol] = price
                saveBasePrices()
                setupMenu()
                if symbol == currentSymbol {
                    updatePrice()
                }
            }
        }
    }
    
    @objc func clearBasePrice(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        basePrices.removeValue(forKey: symbol)
        saveBasePrices()
        setupMenu()
        if symbol == currentSymbol {
            updatePrice()
        }
    }
    
    private func saveBasePrices() {
        UserDefaults.standard.set(basePrices, forKey: "basePrices")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

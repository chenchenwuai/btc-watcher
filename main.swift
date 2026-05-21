import Cocoa

struct CoinSymbol: Codable {
    let name: String
    let symbol: String
    let icon: String
}

struct PositionMetrics {
    let quantity: Double
    let margin: Double
    let notional: Double
    let pnl: Double
    let roi: Double
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
    private var positionDirections: [String: String] = [:]
    private var positionInputModes: [String: String] = [:]
    private var positionMargins: [String: Double] = [:]
    private var positionQuantities: [String: Double] = [:]
    private var positionLeverages: [String: Double] = [:]
    private var latestPrices: [String: Double] = [:]
    private var showMenuBarPrice: Bool = true
    private var showMenuBarChange: Bool = true
    private var showMenuBarPnl: Bool = true
    private var showMenuBarRoi: Bool = true
    
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
    
    func calculateChangePercent(current: Double, base: Double?, direction: String) -> String {
        guard let base = base, base > 0 else { return "" }
        let percent = (direction == "short" ? (base - current) : (current - base)) / base * 100
        let sign = percent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, percent)
    }

    func calculatePositionMetrics(symbol: String, current: Double) -> PositionMetrics? {
        guard let entryPrice = basePrices[symbol], entryPrice > 0 else { return nil }
        let leverage = positionLeverages[symbol] ?? 1
        guard leverage > 0 else { return nil }

        let mode = positionInputModes[symbol] ?? "margin"
        let quantity: Double
        let margin: Double
        let notional: Double

        if mode == "quantity" {
            guard let savedQuantity = positionQuantities[symbol], savedQuantity > 0 else { return nil }
            quantity = savedQuantity
            notional = entryPrice * savedQuantity
            margin = notional / leverage
        } else {
            guard let savedMargin = positionMargins[symbol], savedMargin > 0 else { return nil }
            margin = savedMargin
            notional = savedMargin * leverage
            quantity = notional / entryPrice
        }

        let direction = positionDirections[symbol] ?? "long"
        let pnl = direction == "short" ? (entryPrice - current) * quantity : (current - entryPrice) * quantity
        let roi = margin > 0 ? pnl / margin * 100 : 0

        return PositionMetrics(quantity: quantity, margin: margin, notional: notional, pnl: pnl, roi: roi)
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
    
    func formatAmount(_ amount: Double, suffix: String = "") -> String {
        let formatted = String(format: "%.2f", amount)
        return "\(formatted)\(suffix)"
    }

    func formatSignedAmount(_ amount: Double, suffix: String = "") -> String {
        let sign = amount >= 0 ? "+" : ""
        return "\(sign)\(formatAmount(amount, suffix: suffix))"
    }

    func formatLeverage(_ leverage: Double) -> String {
        if leverage.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0fx", leverage)
        }
        return String(format: "%.2fx", leverage)
    }

    func coinName(for symbol: String) -> String {
        return symbols.first(where: { $0.1 == symbol })?.0 ?? symbol.replacingOccurrences(of: "USDT", with: "")
    }

    private func updateStatusTitle(symbol: String, priceValue: Double) {
        currentPrice = formatPrice(priceValue)
        let basePrice = basePrices[symbol]
        let direction = positionDirections[symbol] ?? "long"
        let changeStr = calculateChangePercent(current: priceValue, base: basePrice, direction: direction)
        var details: [String] = []

        if showMenuBarChange && !changeStr.isEmpty {
            details.append(changeStr)
        }
        if let metrics = calculatePositionMetrics(symbol: symbol, current: priceValue) {
            if showMenuBarPnl {
                details.append(formatSignedAmount(metrics.pnl, suffix: "U"))
            }
            if showMenuBarRoi {
                details.append("ROI \(formatSignedAmount(metrics.roi, suffix: "%"))")
            }
        }

        var titleParts = [currentIcon]
        if showMenuBarPrice {
            titleParts.append(currentPrice)
        }
        let titlePrefix = titleParts.joined(separator: " ")
        let displayTitle = details.isEmpty ? titlePrefix : "\(titlePrefix) (\(details.joined(separator: ", ")))"
        statusItem.button?.title = displayTitle
    }

    func updatePrice() {
        let symbol = currentSymbol
        guard let url = URL(string: "\(apiEndpoints[currentApiIndex])?symbol=\(symbol)") else { return }
        
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
                    self.latestPrices[symbol] = priceValue
                    guard symbol == self.currentSymbol else { return }
                    self.updateStatusTitle(symbol: symbol, priceValue: priceValue)
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

            if basePrices[symbol] != nil {
                let direction = positionDirections[symbol] ?? "long"
                let longItem = NSMenuItem(title: localized("longPosition"), action: #selector(setLongPosition(_:)), keyEquivalent: "")
                longItem.representedObject = symbol
                longItem.state = direction == "long" ? .on : .off
                coinSubmenu.addItem(longItem)

                let shortItem = NSMenuItem(title: localized("shortPosition"), action: #selector(setShortPosition(_:)), keyEquivalent: "")
                shortItem.representedObject = symbol
                shortItem.state = direction == "short" ? .on : .off
                coinSubmenu.addItem(shortItem)

                let marginItem = NSMenuItem(title: localized("setMargin"), action: #selector(setPositionMargin(_:)), keyEquivalent: "")
                marginItem.representedObject = symbol
                coinSubmenu.addItem(marginItem)

                let quantityItem = NSMenuItem(title: localized("setQuantity"), action: #selector(setPositionQuantity(_:)), keyEquivalent: "")
                quantityItem.representedObject = symbol
                coinSubmenu.addItem(quantityItem)

                let leverageItem = NSMenuItem(title: localized("setLeverage"), action: #selector(setPositionLeverage(_:)), keyEquivalent: "")
                leverageItem.representedObject = symbol
                coinSubmenu.addItem(leverageItem)

                addPositionSummaryItems(to: coinSubmenu, for: symbol)
            }
            
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

        // Menu bar display submenu
        let displayItem = NSMenuItem(title: localized("menuBarDisplay"), action: nil, keyEquivalent: "")
        let displaySubmenu = NSMenu()
        let showPriceItem = NSMenuItem(title: localized("showPrice"), action: #selector(toggleMenuBarPrice), keyEquivalent: "")
        showPriceItem.state = showMenuBarPrice ? .on : .off
        displaySubmenu.addItem(showPriceItem)
        let showChangeItem = NSMenuItem(title: localized("showChange"), action: #selector(toggleMenuBarChange), keyEquivalent: "")
        showChangeItem.state = showMenuBarChange ? .on : .off
        displaySubmenu.addItem(showChangeItem)
        let showPnlItem = NSMenuItem(title: localized("showPnl"), action: #selector(toggleMenuBarPnl), keyEquivalent: "")
        showPnlItem.state = showMenuBarPnl ? .on : .off
        displaySubmenu.addItem(showPnlItem)
        let showRoiItem = NSMenuItem(title: localized("showRoi"), action: #selector(toggleMenuBarRoi), keyEquivalent: "")
        showRoiItem.state = showMenuBarRoi ? .on : .off
        displaySubmenu.addItem(showRoiItem)
        settingsSubmenu.addItem(displayItem)
        settingsSubmenu.setSubmenu(displaySubmenu, for: displayItem)
        
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

    private func addPositionSummaryItems(to menu: NSMenu, for symbol: String) {
        let leverage = positionLeverages[symbol] ?? 1
        let mode = positionInputModes[symbol] ?? "margin"

        menu.addItem(NSMenuItem.separator())
        let modeTitle = mode == "quantity" ? localized("quantityMode") : localized("marginMode")
        menu.addItem(NSMenuItem(title: "\(localized("inputMode")): \(modeTitle)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "\(localized("leverage")): \(formatLeverage(leverage))", action: nil, keyEquivalent: ""))

        if mode == "quantity" {
            if let quantity = positionQuantities[symbol], quantity > 0 {
                menu.addItem(NSMenuItem(title: "\(localized("quantity")): \(formatPrice(quantity)) \(coinName(for: symbol))", action: nil, keyEquivalent: ""))
                if let entryPrice = basePrices[symbol], entryPrice > 0 {
                    let notional = entryPrice * quantity
                    menu.addItem(NSMenuItem(title: "\(localized("margin")): \(formatAmount(notional / leverage, suffix: "U"))", action: nil, keyEquivalent: ""))
                    menu.addItem(NSMenuItem(title: "\(localized("notional")): \(formatAmount(notional, suffix: "U"))", action: nil, keyEquivalent: ""))
                }
            }
        } else if let margin = positionMargins[symbol], margin > 0 {
            menu.addItem(NSMenuItem(title: "\(localized("margin")): \(formatAmount(margin, suffix: "U"))", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "\(localized("notional")): \(formatAmount(margin * leverage, suffix: "U"))", action: nil, keyEquivalent: ""))
            if let entryPrice = basePrices[symbol], entryPrice > 0 {
                menu.addItem(NSMenuItem(title: "\(localized("quantity")): \(formatPrice(margin * leverage / entryPrice)) \(coinName(for: symbol))", action: nil, keyEquivalent: ""))
            }
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 加载语言设置
        isEnglish = UserDefaults.standard.bool(forKey: "isEnglish")
        
        // 加载交易模式设置
        isFuturesMode = UserDefaults.standard.bool(forKey: "isFuturesMode")

        // 加载菜单栏显示设置
        showMenuBarPrice = UserDefaults.standard.object(forKey: "showMenuBarPrice") as? Bool ?? true
        showMenuBarChange = UserDefaults.standard.object(forKey: "showMenuBarChange") as? Bool ?? true
        showMenuBarPnl = UserDefaults.standard.object(forKey: "showMenuBarPnl") as? Bool ?? true
        showMenuBarRoi = UserDefaults.standard.object(forKey: "showMenuBarRoi") as? Bool ?? true
        
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
        if let savedPositionDirections = UserDefaults.standard.dictionary(forKey: "positionDirections") as? [String: String] {
            positionDirections = savedPositionDirections
        }
        if let savedPositionInputModes = UserDefaults.standard.dictionary(forKey: "positionInputModes") as? [String: String] {
            positionInputModes = savedPositionInputModes
        }
        if let savedPositionMargins = UserDefaults.standard.dictionary(forKey: "positionMargins") as? [String: Double] {
            positionMargins = savedPositionMargins
        }
        if let savedPositionQuantities = UserDefaults.standard.dictionary(forKey: "positionQuantities") as? [String: Double] {
            positionQuantities = savedPositionQuantities
        }
        if let savedPositionLeverages = UserDefaults.standard.dictionary(forKey: "positionLeverages") as? [String: Double] {
            positionLeverages = savedPositionLeverages
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

    @objc func toggleMenuBarPrice() {
        showMenuBarPrice.toggle()
        saveMenuBarDisplaySettings()
        refreshStatusTitleFromCache()
        setupMenu()
    }

    @objc func toggleMenuBarChange() {
        showMenuBarChange.toggle()
        saveMenuBarDisplaySettings()
        refreshStatusTitleFromCache()
        setupMenu()
    }

    @objc func toggleMenuBarPnl() {
        showMenuBarPnl.toggle()
        saveMenuBarDisplaySettings()
        refreshStatusTitleFromCache()
        setupMenu()
    }

    @objc func toggleMenuBarRoi() {
        showMenuBarRoi.toggle()
        saveMenuBarDisplaySettings()
        refreshStatusTitleFromCache()
        setupMenu()
    }

    private func refreshStatusTitleFromCache() {
        if let priceValue = latestPrices[currentSymbol] {
            updateStatusTitle(symbol: currentSymbol, priceValue: priceValue)
        }
    }

    private func saveMenuBarDisplaySettings() {
        UserDefaults.standard.set(showMenuBarPrice, forKey: "showMenuBarPrice")
        UserDefaults.standard.set(showMenuBarChange, forKey: "showMenuBarChange")
        UserDefaults.standard.set(showMenuBarPnl, forKey: "showMenuBarPnl")
        UserDefaults.standard.set(showMenuBarRoi, forKey: "showMenuBarRoi")
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
        if let existingPrice = basePrices[symbol] {
            alert.informativeText = "\(symbol)\n\(localized("basePrice")): \(formatPrice(existingPrice))"
        } else {
            alert.informativeText = "\(symbol)"
        }

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = localized("emptyBasePriceUsesCurrent")
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
            if priceString.isEmpty {
                setBasePriceToCurrentPrice(for: symbol)
            } else if let price = Double(priceString), price > 0 {
                updateBasePrice(price, for: symbol)
            }
        }
    }

    private func setBasePriceToCurrentPrice(for symbol: String) {
        if let latestPrice = latestPrices[symbol] {
            updateBasePrice(latestPrice, for: symbol)
            return
        }

        guard let url = URL(string: "\(getCurrentApiEndpoint())?symbol=\(symbol)") else { return }

        urlSession.dataTask(with: url) { [weak self] data, _, _ in
            guard let self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let priceString = json["price"] as? String,
                  let price = Double(priceString),
                  price > 0
            else {
                DispatchQueue.main.async {
                    self?.showError("invalidCoin")
                }
                return
            }

            DispatchQueue.main.async {
                self.latestPrices[symbol] = price
                self.updateBasePrice(price, for: symbol)
            }
        }.resume()
    }

    private func updateBasePrice(_ price: Double, for symbol: String) {
        basePrices[symbol] = price
        if positionDirections[symbol] == nil {
            positionDirections[symbol] = "long"
        }
        saveBasePrices()
        savePositionSettings()
        setupMenu()
        if symbol == currentSymbol {
            updatePrice()
        }
    }

    @objc func setLongPosition(_ sender: NSMenuItem) {
        setPositionDirection("long", sender: sender)
    }

    @objc func setShortPosition(_ sender: NSMenuItem) {
        setPositionDirection("short", sender: sender)
    }

    private func setPositionDirection(_ direction: String, sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        positionDirections[symbol] = direction
        savePositionDirections()
        setupMenu()
        if symbol == currentSymbol {
            updatePrice()
        }
    }

    @objc func setPositionMargin(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        showPositionValueAlert(
            symbol: symbol,
            titleKey: "setMargin",
            placeholder: "10",
            existingValue: positionMargins[symbol],
            suffix: "U"
        ) { [weak self] value in
            self?.positionMargins[symbol] = value
            self?.positionInputModes[symbol] = "margin"
            self?.savePositionSettings()
            self?.setupMenu()
            if symbol == self?.currentSymbol {
                self?.updatePrice()
            }
        }
    }

    @objc func setPositionQuantity(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        showPositionValueAlert(
            symbol: symbol,
            titleKey: "setQuantity",
            placeholder: "10000",
            existingValue: positionQuantities[symbol],
            suffix: coinName(for: symbol)
        ) { [weak self] value in
            self?.positionQuantities[symbol] = value
            self?.positionInputModes[symbol] = "quantity"
            self?.savePositionSettings()
            self?.setupMenu()
            if symbol == self?.currentSymbol {
                self?.updatePrice()
            }
        }
    }

    @objc func setPositionLeverage(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        showPositionValueAlert(
            symbol: symbol,
            titleKey: "setLeverage",
            placeholder: "50",
            existingValue: positionLeverages[symbol],
            suffix: "x"
        ) { [weak self] value in
            self?.positionLeverages[symbol] = value
            self?.savePositionSettings()
            self?.setupMenu()
            if symbol == self?.currentSymbol {
                self?.updatePrice()
            }
        }
    }

    private func showPositionValueAlert(
        symbol: String,
        titleKey: String,
        placeholder: String,
        existingValue: Double?,
        suffix: String,
        onSave: (Double) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = localized(titleKey)
        alert.informativeText = "\(symbol) \(suffix)"

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = placeholder
        if let existingValue = existingValue, existingValue > 0 {
            input.stringValue = formatPrice(existingValue)
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
            let valueString = input.stringValue.trimmingCharacters(in: .whitespaces)
            if let value = Double(valueString), value > 0 {
                onSave(value)
            }
        }
    }
    
    @objc func clearBasePrice(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        basePrices.removeValue(forKey: symbol)
        positionDirections.removeValue(forKey: symbol)
        positionInputModes.removeValue(forKey: symbol)
        positionMargins.removeValue(forKey: symbol)
        positionQuantities.removeValue(forKey: symbol)
        positionLeverages.removeValue(forKey: symbol)
        saveBasePrices()
        savePositionSettings()
        setupMenu()
        if symbol == currentSymbol {
            updatePrice()
        }
    }
    
    private func saveBasePrices() {
        UserDefaults.standard.set(basePrices, forKey: "basePrices")
    }

    private func savePositionDirections() {
        UserDefaults.standard.set(positionDirections, forKey: "positionDirections")
    }

    private func savePositionSettings() {
        savePositionDirections()
        UserDefaults.standard.set(positionInputModes, forKey: "positionInputModes")
        UserDefaults.standard.set(positionMargins, forKey: "positionMargins")
        UserDefaults.standard.set(positionQuantities, forKey: "positionQuantities")
        UserDefaults.standard.set(positionLeverages, forKey: "positionLeverages")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

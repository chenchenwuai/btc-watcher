import Cocoa

extension AppDelegate {
    func updateStatusTitle(symbol: String, priceValue: Double) {
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

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = localized("error")
        alert.informativeText = localized(message)
        alert.alertStyle = .warning
        alert.runModal()
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

    @objc func switchCoin(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        currentSymbol = symbol
        if let (_, _, icon) = symbols.first(where: { $0.1 == symbol }) {
            currentIcon = icon
            UserDefaults.standard.set(symbol, forKey: "lastSymbol")
        }
        setupMenu()
        updatePrice()
    }

    @objc func setInterval1s() {
        startTimer(interval: 1.0, fireImmediately: false)
        setupMenu()
    }

    @objc func setInterval2s() {
        startTimer(interval: 2.0, fireImmediately: false)
        setupMenu()
    }

    @objc func setInterval5s() {
        startTimer(interval: 5.0, fireImmediately: false)
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

    func refreshStatusTitleFromCache() {
        if let priceValue = latestPrices[currentSymbol] {
            updateStatusTitle(symbol: currentSymbol, priceValue: priceValue)
        }
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

        if symbol == currentSymbol {
            currentSymbol = "BTCUSDT"
            currentIcon = "₿"
        }

        symbols.removeAll(where: { $0.1 == symbol })
        saveCustomSymbols()
        setupMenu()

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
        alert.window.maxSize = NSSize(width: 500, height: 1000)
        alert.window.minSize = NSSize(width: 400, height: 200)
        alert.alertStyle = .informational

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
}

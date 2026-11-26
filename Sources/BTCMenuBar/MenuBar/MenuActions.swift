import Cocoa

extension AppDelegate {
    func updateStatusTitle(symbol: String, priceValue: Double?) {
        var details: [String] = []
        var stalePosition = false

        if usesBinancePositions {
            details = binancePositionDetails(for: symbol)
            stalePosition = binancePositionSyncError != nil && !details.isEmpty
        } else if let priceValue {
            let direction = positionDirections[symbol] ?? "long"
            let change = calculateChangePercent(current: priceValue, base: basePrices[symbol], direction: direction)
            if showMenuBarChange && !change.isEmpty {
                details.append(change)
            }
            if let metrics = calculatePositionMetrics(symbol: symbol, current: priceValue) {
                if showMenuBarPnl {
                    details.append(formatSignedAmount(metrics.pnl, suffix: "U"))
                }
                if showMenuBarRoi {
                    details.append("ROI \(formatSignedAmount(metrics.roi, suffix: "%"))")
                }
            }
        }

        var titleParts = [currentIcon]
        if showMenuBarPrice {
            titleParts.append(priceValue.map(formatPrice) ?? "—")
        }
        let titlePrefix = titleParts.joined(separator: " ")
        var displayTitle = details.isEmpty ? titlePrefix : "\(titlePrefix) (\(details.joined(separator: ", ")))"
        if priceValue != nil && watchlistRefreshFailed && (showMenuBarPrice || (!usesBinancePositions && !details.isEmpty)) {
            displayTitle += " · \(localized("staleQuote"))"
        }
        if stalePosition {
            displayTitle += " · \(localized("binanceStalePositions"))"
        }
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
            var symbol = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !symbol.isEmpty else { return }
            if !symbol.hasSuffix("USDT") {
                symbol += "USDT"
            }
            validateAndAddCoin(symbol)
        }
    }

    @objc func switchCoin(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        updateSelectedSymbol(symbol)
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
        updateStatusTitle(symbol: currentSymbol, priceValue: latestPrices[currentSymbol])
    }

    @objc func switchApi(_ sender: NSMenuItem) {
        guard let index = sender.representedObject as? Int else { return }
        cancelPriceUpdate()
        currentApiIndex = index
        failedAttempts = 0
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
        refreshStatusTitleFromCache()
        updatePrice()
    }

    @objc func deleteCoin(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        let isDeletingCurrentSymbol = symbol == currentSymbol

        if isDeletingCurrentSymbol {
            currentSymbol = "BTCUSDT"
            currentIcon = "₿"
            UserDefaults.standard.set(currentSymbol, forKey: "lastSymbol")
        }

        symbols.removeAll(where: { $0.1 == symbol })
        latestPrices.removeValue(forKey: symbol)
        cancelPriceUpdate()
        useAllSpotPrices = false
        saveCustomSymbols()
        setupMenu()
        refreshStatusTitleFromCache()
        updatePrice()
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
        setTradingMode(isFutures: false)
    }

    @objc func setFuturesMode() {
        setTradingMode(isFutures: true)
    }

    private func setTradingMode(isFutures: Bool) {
        guard isFuturesMode != isFutures else { return }
        cancelPriceUpdate()
        isFuturesMode = isFutures
        latestPrices.removeAll()
        watchlistRefreshFailed = false
        useAllSpotPrices = false
        failedAttempts = 0
        UserDefaults.standard.set(isFuturesMode, forKey: "isFuturesMode")
        currentApiIndex = 0
        UserDefaults.standard.set(currentApiIndex, forKey: "currentApiIndex")
        setupMenu()
        restartBinancePositionSync()
        updatePrice()
    }

    @objc func toggleProxy() {
        isProxyEnabled = !isProxyEnabled
        UserDefaults.standard.set(isProxyEnabled, forKey: "isProxyEnabled")
        configureUrlSession()
        setupMenu()
        updatePrice()
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
                updatePrice()
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
                updatePrice()
            }
        }
    }
}

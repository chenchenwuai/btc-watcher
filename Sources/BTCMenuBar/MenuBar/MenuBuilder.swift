import Cocoa

extension AppDelegate {
    func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: localized("addCoin"), action: #selector(addCustomCoin), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())

        for (name, symbol, icon) in symbols {
            let item = NSMenuItem(title: watchlistTitle(name: name, symbol: symbol), action: nil, keyEquivalent: "")
            item.representedObject = CoinSymbol(name: name, symbol: symbol, icon: icon)
            item.state = symbol == currentSymbol ? .on : .off

            let coinSubmenu = NSMenu()

            let selectItem = NSMenuItem(title: localized("showCoinInMenuBar"), action: #selector(switchCoin(_:)), keyEquivalent: "")
            selectItem.representedObject = symbol
            coinSubmenu.addItem(selectItem)

            let ordersItem = NSMenuItem(title: localized("binanceOpenOrders"), action: #selector(showBinanceOrders(_:)), keyEquivalent: "")
            ordersItem.representedObject = symbol
            coinSubmenu.addItem(ordersItem)

            if !usesBinancePositions {
                let editItem = NSMenuItem(title: localized("editPosition"), action: #selector(editPosition(_:)), keyEquivalent: "")
                editItem.representedObject = symbol
                coinSubmenu.addItem(editItem)

                if basePrices[symbol] != nil {
                    let clearBaseItem = NSMenuItem(title: localized("clearBasePrice"), action: #selector(clearBasePrice(_:)), keyEquivalent: "")
                    clearBaseItem.representedObject = symbol
                    coinSubmenu.addItem(clearBaseItem)
                    addPositionSummaryItems(to: coinSubmenu, for: symbol)
                }
            }

            if !defaultSymbols.contains(where: { $0.1 == symbol }) {
                coinSubmenu.addItem(NSMenuItem.separator())
                let deleteItem = NSMenuItem(title: localized("delete"), action: #selector(deleteCoin(_:)), keyEquivalent: "")
                deleteItem.representedObject = symbol
                coinSubmenu.addItem(deleteItem)
            }

            item.submenu = coinSubmenu
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        if usesBinancePositions {
            menu.addItem(NSMenuItem(title: localized("binancePositions"), action: #selector(showBinancePositions), keyEquivalent: ""))
        }

        let contractUrl = Constants.getContractUrl(symbol: currentSymbol, isEnglish: isEnglish)
        let contractItem = NSMenuItem(title: localized("viewContract"), action: #selector(openContract), keyEquivalent: "")
        contractItem.representedObject = contractUrl
        menu.addItem(contractItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: localized("settings"), action: nil, keyEquivalent: "")
        let settingsSubmenu = NSMenu()

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

        let intervalItem = NSMenuItem(title: localized("updateInterval"), action: nil, keyEquivalent: "")
        let intervalSubmenu = NSMenu()
        intervalSubmenu.addItem(NSMenuItem(title: "1s", action: #selector(setInterval1s), keyEquivalent: "1"))
        intervalSubmenu.addItem(NSMenuItem(title: "2s", action: #selector(setInterval2s), keyEquivalent: "2"))
        intervalSubmenu.addItem(NSMenuItem(title: "5s", action: #selector(setInterval5s), keyEquivalent: "5"))
        settingsSubmenu.addItem(intervalItem)
        settingsSubmenu.setSubmenu(intervalSubmenu, for: intervalItem)

        let displayItem = NSMenuItem(title: localized("menuBarDisplay"), action: nil, keyEquivalent: "")
        let displaySubmenu = NSMenu()
        let showPriceItem = NSMenuItem(title: localized("showPrice"), action: #selector(toggleMenuBarPrice), keyEquivalent: "")
        showPriceItem.state = showMenuBarPrice ? .on : .off
        displaySubmenu.addItem(showPriceItem)
        let trendItem = NSMenuItem(title: localized("showPriceTrend"), action: nil, keyEquivalent: "")
        let trendSubmenu = NSMenu()
        for period in PriceTrendPeriod.allCases {
            let title: String
            switch period {
            case .off: title = localized("priceTrendOff")
            case .live: title = localized("priceTrendLive")
            case .fifteenMinutes, .oneHour, .fourHours: title = period.rawValue
            }
            let periodItem = NSMenuItem(title: title, action: #selector(selectPriceTrendPeriod(_:)), keyEquivalent: "")
            periodItem.representedObject = period
            periodItem.state = priceTrendPeriod == period ? .on : .off
            trendSubmenu.addItem(periodItem)
        }
        trendItem.submenu = trendSubmenu
        displaySubmenu.addItem(trendItem)
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

        settingsSubmenu.addItem(NSMenuItem(title: localized("binanceAccount"), action: #selector(configureBinanceAccount), keyEquivalent: ""))
        let syncItem = NSMenuItem(title: localized("binanceSyncPositions"), action: #selector(toggleBinancePositionSync), keyEquivalent: "")
        syncItem.state = isBinancePositionSyncEnabled ? .on : .off
        settingsSubmenu.addItem(syncItem)

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
        menu.addItem(NSMenuItem(title: localized("language"), action: #selector(toggleLanguage), keyEquivalent: "l"))
        menu.addItem(NSMenuItem.separator())

        let helpItem = NSMenuItem(title: localized("help"), action: nil, keyEquivalent: "")
        let helpSubmenu = NSMenu()

        helpSubmenu.addItem(NSMenuItem(title: localized("version") + " " + Constants.appVersion, action: nil, keyEquivalent: ""))
        helpSubmenu.addItem(NSMenuItem(title: localized("about"), action: #selector(showAbout), keyEquivalent: ""))
        helpSubmenu.addItem(NSMenuItem(title: localized("feedback"), action: #selector(openFeedback), keyEquivalent: ""))

        menu.addItem(helpItem)
        menu.setSubmenu(helpSubmenu, for: helpItem)

        menu.addItem(NSMenuItem(title: localized("quit"), action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func refreshWatchlistTitles() {
        guard let menu = statusItem.menu else { return }
        for item in menu.items {
            guard let coin = item.representedObject as? CoinSymbol else { continue }
            let title = watchlistTitle(name: coin.name, symbol: coin.symbol)
            if item.title != title {
                item.title = title
            }
        }
    }

    private func watchlistTitle(name: String, symbol: String) -> String {
        guard let price = latestPrices[symbol] else { return "\(name)   —" }
        let suffix = watchlistRefreshFailed ? " (\(localized("staleQuote")))" : ""
        return "\(name)   \(formatPrice(price))\(suffix)"
    }

    private func addPositionSummaryItems(to menu: NSMenu, for symbol: String) {
        let leverage = positionLeverages[symbol] ?? 1
        let mode = positionInputMode(for: symbol)

        menu.addItem(NSMenuItem.separator())
        let modeTitle = mode == .quantity ? localized("quantityMode") : localized("marginMode")
        menu.addItem(NSMenuItem(title: "\(localized("inputMode")): \(modeTitle)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "\(localized("leverage")): \(formatLeverage(leverage))", action: nil, keyEquivalent: ""))

        guard let size = positionSize(for: symbol) else { return }
        menu.addItem(NSMenuItem(title: "\(localized("margin")): \(formatAmount(size.margin, suffix: "U"))", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "\(localized("quantity")): \(formatPrice(size.quantity)) \(coinName(for: symbol))", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "\(localized("notional")): \(formatAmount(size.notional, suffix: "U"))", action: nil, keyEquivalent: ""))
    }
}

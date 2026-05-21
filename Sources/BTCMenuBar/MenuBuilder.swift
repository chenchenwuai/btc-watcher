import Cocoa

extension AppDelegate {
    func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: localized("addCoin"), action: #selector(addCustomCoin), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())

        for (name, symbol, _) in symbols {
            let item = NSMenuItem(title: name, action: #selector(switchCoin(_:)), keyEquivalent: "")
            item.representedObject = symbol
            item.state = symbol == currentSymbol ? .on : .off

            let coinSubmenu = NSMenu()

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

            if basePrices[symbol] != nil {
                let clearBaseItem = NSMenuItem(title: localized("clearBasePrice"), action: #selector(clearBasePrice(_:)), keyEquivalent: "")
                clearBaseItem.representedObject = symbol
                coinSubmenu.addItem(clearBaseItem)
            }

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

    func addPositionSummaryItems(to menu: NSMenu, for symbol: String) {
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
}

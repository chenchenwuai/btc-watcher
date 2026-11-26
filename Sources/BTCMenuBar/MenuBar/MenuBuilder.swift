import Cocoa

extension AppDelegate {
    func setupMenu() {
        let menu = NSMenu()

        let quoteItem = NSMenuItem(title: localized("quotePanel"), action: #selector(showQuotePanel), keyEquivalent: "")
        quoteItem.target = self
        menu.addItem(quoteItem)
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

        let settingsItem = NSMenuItem(title: localized("settings"), action: #selector(showSettingsWindow), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let shortcuts: [(String, Selector, String)] = [
            ("1s", #selector(setInterval1s), "1"),
            ("2s", #selector(setInterval2s), "2"),
            ("5s", #selector(setInterval5s), "5"),
            (localized("autoSwitch"), #selector(toggleAutoSwitch), "a"),
            (localized("language"), #selector(toggleLanguage), "l"),
        ]
        for (title, action, key) in shortcuts {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            item.isHidden = true
            item.allowsKeyEquivalentWhenHidden = true
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: localized("quit"), action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
        refreshQuotePanel()
        settingsWindow?.refresh()
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

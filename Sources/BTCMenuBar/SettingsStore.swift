import Foundation

extension AppDelegate {
    func loadSettings() {
        isEnglish = UserDefaults.standard.bool(forKey: "isEnglish")
        isFuturesMode = UserDefaults.standard.bool(forKey: "isFuturesMode")

        showMenuBarPrice = UserDefaults.standard.object(forKey: "showMenuBarPrice") as? Bool ?? true
        showMenuBarChange = UserDefaults.standard.object(forKey: "showMenuBarChange") as? Bool ?? true
        showMenuBarPnl = UserDefaults.standard.object(forKey: "showMenuBarPnl") as? Bool ?? true
        showMenuBarRoi = UserDefaults.standard.object(forKey: "showMenuBarRoi") as? Bool ?? true

        isProxyEnabled = UserDefaults.standard.bool(forKey: "isProxyEnabled")
        if let savedProxyHost = UserDefaults.standard.string(forKey: "proxyHost"), !savedProxyHost.isEmpty {
            proxyHost = savedProxyHost
        }
        if let savedProxyPort = UserDefaults.standard.string(forKey: "proxyPort"), !savedProxyPort.isEmpty {
            proxyPort = savedProxyPort
        }

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
    }

    func loadCustomSymbols() {
        if let savedData = UserDefaults.standard.data(forKey: "customSymbols"),
           let savedSymbols = try? JSONDecoder().decode([CoinSymbol].self, from: savedData) {
            let customTuples = savedSymbols.map { ($0.name, $0.symbol, $0.icon) }
            symbols = defaultSymbols + customTuples
        } else {
            symbols = defaultSymbols
        }
    }

    func saveCustomSymbols() {
        let customSymbols = symbols.filter { symbol in
            !defaultSymbols.contains(where: { $0 == symbol })
        }
        let coinSymbols = customSymbols.map { CoinSymbol(name: $0.0, symbol: $0.1, icon: $0.2) }
        if let encodedData = try? JSONEncoder().encode(coinSymbols) {
            UserDefaults.standard.set(encodedData, forKey: "customSymbols")
        }
    }

    func restoreLastSelectedSymbol() {
        if let lastSymbol = UserDefaults.standard.string(forKey: "lastSymbol"),
           let lastIcon = symbols.first(where: { $0.1 == lastSymbol })?.2 {
            currentSymbol = lastSymbol
            currentIcon = lastIcon
        }
    }

    func saveBasePrices() {
        UserDefaults.standard.set(basePrices, forKey: "basePrices")
    }

    func savePositionDirections() {
        UserDefaults.standard.set(positionDirections, forKey: "positionDirections")
    }

    func savePositionSettings() {
        savePositionDirections()
        UserDefaults.standard.set(positionInputModes, forKey: "positionInputModes")
        UserDefaults.standard.set(positionMargins, forKey: "positionMargins")
        UserDefaults.standard.set(positionQuantities, forKey: "positionQuantities")
        UserDefaults.standard.set(positionLeverages, forKey: "positionLeverages")
    }

    func saveMenuBarDisplaySettings() {
        UserDefaults.standard.set(showMenuBarPrice, forKey: "showMenuBarPrice")
        UserDefaults.standard.set(showMenuBarChange, forKey: "showMenuBarChange")
        UserDefaults.standard.set(showMenuBarPnl, forKey: "showMenuBarPnl")
        UserDefaults.standard.set(showMenuBarRoi, forKey: "showMenuBarRoi")
    }
}

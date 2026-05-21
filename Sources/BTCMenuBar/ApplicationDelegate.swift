import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var currentPrice: String = "Loading..."
    var currentSymbol: String = "BTCUSDT"
    var currentIcon: String = "₿"
    var isEnglish: Bool = true
    var currentApiIndex: Int = 0
    var isAutoSwitchApi: Bool = true
    var failedAttempts: Int = 0

    var isFuturesMode: Bool = false
    var proxyHost: String = "127.0.0.1"
    var proxyPort: String = "7890"
    var isProxyEnabled: Bool = false
    var urlSession: URLSession = URLSession.shared
    var basePrices: [String: Double] = [:]
    var positionDirections: [String: String] = [:]
    var positionInputModes: [String: String] = [:]
    var positionMargins: [String: Double] = [:]
    var positionQuantities: [String: Double] = [:]
    var positionLeverages: [String: Double] = [:]
    var latestPrices: [String: Double] = [:]
    var showMenuBarPrice: Bool = true
    var showMenuBarChange: Bool = true
    var showMenuBarPnl: Bool = true
    var showMenuBarRoi: Bool = true

    var apiEndpoints: [String] {
        return isFuturesMode ? Constants.futuresApiEndpoints : Constants.spotApiEndpoints
    }

    var symbols = Constants.defaultSymbols
    let defaultSymbols = Constants.defaultSymbols

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        loadSettings()
        configureUrlSession()
        loadCustomSymbols()
        restoreLastSelectedSymbol()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = nil
            button.title = "\(currentIcon) \(currentPrice)"
        }

        setupMenu()
        startTimer()
    }
}

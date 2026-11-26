import Foundation

struct Constants {
    static let appVersion = "v1.4.4"
    
    static let spotApiEndpoints = [
        "https://api.binance.com/api/v3/ticker/price",
        "https://api1.binance.com/api/v3/ticker/price",
        "https://api2.binance.com/api/v3/ticker/price",
        "https://api3.binance.com/api/v3/ticker/price",
        "https://api4.binance.com/api/v3/ticker/price"
    ]
    
    static let futuresApiEndpoints = [
        "https://fapi.binance.com/fapi/v1/ticker/price",
        "https://fapi1.binance.com/fapi/v1/ticker/price",
        "https://fapi2.binance.com/fapi/v1/ticker/price",
        "https://fapi3.binance.com/fapi/v1/ticker/price",
        "https://fapi4.binance.com/fapi/v1/ticker/price"
    ]
    
    static let defaultSymbols = [
        ("BTC", "BTCUSDT", "₿"),
        ("ETH", "ETHUSDT", "Ξ"),
        ("DOGE", "DOGEUSDT", "Ð")
    ]
    
    static let localizedStrings: [String: [Bool: String]] = [
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
        "binanceAccount": [true: "Binance Account…", false: "币安账户…"],
        "binanceOpenOrders": [true: "My Open Orders…", false: "我的挂单…"],
        "binancePositions": [true: "Binance Positions…", false: "币安持仓…"],
        "binanceSyncPositions": [true: "Sync Binance Futures Positions", false: "自动同步币安合约持仓"],
        "binanceLoadingPositions": [true: "Syncing Binance positions…", false: "正在同步币安持仓…"],
        "binanceEmptyPositions": [true: "No open USDⓈ-M Futures positions.", false: "当前没有 U 本位合约持仓。"],
        "binancePositionsError": [true: "Could not sync Binance positions.", false: "无法同步币安持仓。"],
        "binanceStalePositions": [true: "Stale positions", false: "持仓未更新"],
        "binanceRetryPositions": [true: "Retry Sync", false: "重试同步"],
        "binanceEntryPrice": [true: "Entry price", false: "开仓均价"],
        "binanceMarkPrice": [true: "Mark price", false: "标记价格"],
        "binanceAccountInstructions": [true: "Enter your Binance HMAC credentials. Both keys are saved only in macOS Keychain. The Secret Key is used on this Mac to sign requests. Queries go directly to Binance with the API Key and signature.", false: "请输入币安 HMAC 凭证。两项密钥仅保存到 macOS 钥匙串。Secret Key 只在本机用于签名，查询请求携带 API Key 和签名直接发送给币安。"],
        "binanceTestAndSave": [true: "Test and Save", false: "测试并保存"],
        "binanceAccountSaved": [true: "Connection successful. Both keys were saved to macOS Keychain.", false: "连接成功，两项密钥已保存到 macOS 钥匙串。"],
        "binanceEnterCredentials": [true: "Enter both keys without spaces or line breaks.", false: "请填写 API Key 和 Secret Key，密钥中不能包含空格或换行。"],
        "binanceMissingCredentials": [true: "Enter both keys in Settings → Binance Account.", false: "请前往「设置 → 币安账户」填写 API Key 和 Secret Key。"],
        "binanceKeychainReadError": [true: "Could not read Keychain. Check BTCWatcher's access to the item.", false: "无法读取钥匙串，请检查 BTCWatcher 对该条目的访问权限。"],
        "binanceKeychainSaveError": [true: "Could not save the keys to Keychain.", false: "无法将密钥存入钥匙串。"],
        "binanceRequestInProgress": [true: "A Binance account request is already in progress.", false: "正在查询币安账户，请稍候。"],
        "binanceRequestError": [true: "Could not retrieve open orders from Binance.", false: "无法获取币安挂单。"],
        "binanceClockError": [true: "Check that your Mac's date and time are set automatically.", false: "请检查 Mac 是否启用了自动设置日期与时间。"],
        "binancePermissionError": [true: "Check your API Key, account permissions and any IP restrictions.", false: "请检查 API Key、账户读取权限和 IP 白名单。"],
        "binanceEmptyOrders": [true: "No open orders for this symbol.", false: "该交易对暂无挂单。"],
        "binanceOrderPrice": [true: "Order price", false: "委托价"],
        "binanceTriggerPrice": [true: "Trigger price", false: "触发价"],
        "binanceExecutedQuantity": [true: "Filled", false: "已成交"],
        "binanceClosePosition": [true: "Close entire position", false: "全部平仓"],
        "autoSwitch": [true: "Auto Switch API", false: "自动切换API"],
        "manualApi": [true: "Manual API", false: "手动选择API"],
        "api": [true: "API", false: "接口"],
        "about": [true: "About", false: "关于"],
        "aboutTitle": [true: "About BTC Watcher", false: "关于 BTC Watcher"],
        "aboutMessage": [true: """
            BTC Watcher
            
            A lightweight cryptocurrency price tracking app for macOS.
            
            Features:
            • Real-time price updates
            • Multiple coins support (BTC, ETH, DOGE, etc.)
            • Custom coin addition
            • Auto API switching
            • Multi-language support
            • Quick access to Binance futures
            
            Created by chenwuai
            """,
            false: """
            BTC Watcher
            
            一个轻量级的 macOS 加密货币价格跟踪应用。
            
            功能特点：
            • 实时价格更新
            • 支持多种币种（BTC、ETH、DOGE 等）
            • 自定义币种添加
            • 自动API切换
            • 多语言支持
            • 快速跳转币安合约页面
            
            由 chenwuai 开发
            """],
        "version": [true: "Version", false: "版本"],
        "feedback": [true: "Feedback", false: "反馈"],
        "help": [true: "Help", false: "帮助"],
        "settings": [true: "Settings", false: "设置"],
        "delete": [true: "Delete", false: "删除"],
        "viewContract": [true: "View Contract", false: "查看合约"],
        "showCoinInMenuBar": [true: "Show in Menu Bar", false: "在菜单栏显示"],
        "staleQuote": [true: "Stale", false: "旧报价"],
        "editPosition": [true: "Edit Position…", false: "编辑仓位…"],
        "savePosition": [true: "Save", false: "保存"],
        "clearBasePrice": [true: "Clear Position and Base Price", false: "清除仓位和基准价"],
        "entryPrice": [true: "Entry Price (USDT)", false: "开仓价（USDT）"],
        "positionDirection": [true: "Direction", false: "方向"],
        "useCurrentPrice": [true: "Use Current Price", false: "使用当前价格"],
        "currentPriceUnavailable": [true: "No current quote. Enter an entry price manually.", false: "当前暂无可用报价，可手动填写开仓价。"],
        "optionalPositionAmount": [true: "Optional", false: "选填"],
        "invalidPositionValues": [true: "Use positive numbers for prices and amounts.", false: "价格、杠杆和仓位数值须大于零。"],
        "longPosition": [true: "Long", false: "做多"],
        "shortPosition": [true: "Short", false: "做空"],
        "margin": [true: "Margin", false: "保证金"],
        "quantity": [true: "Quantity", false: "数量"],
        "leverage": [true: "Leverage", false: "倍数"],
        "notional": [true: "Notional Value", false: "名义价值"],
        "inputMode": [true: "Mode", false: "模式"],
        "marginMode": [true: "Margin", false: "按保证金"],
        "quantityMode": [true: "Quantity", false: "按数量"],
        "menuBarDisplay": [true: "Menu Bar Display", false: "菜单栏显示"],
        "showPrice": [true: "Price", false: "价格"],
        "showPriceTrend": [true: "Price Trend", false: "价格走势"],
        "priceTrendOff": [true: "Off", false: "关闭"],
        "priceTrendLive": [true: "Live 5m", false: "实时 5m"],
        "priceTrendDescription": [true: "Price trend for up to five minutes", false: "最近五分钟内的价格走势"],
        "priceTrendKlineDescription": [true: "%@ candlestick price trend", false: "%@ K 线价格走势"],
        "showChange": [true: "Entry Change", false: "相对开仓价变化"],
        "showPnl": [true: "Unrealized PnL", false: "未实现盈亏"],
        "showRoi": [true: "ROI", false: "ROI"],
        "tradingMode": [true: "Trading Mode", false: "交易模式"],
        "spotMode": [true: "Spot", false: "现货"],
        "futuresMode": [true: "Futures", false: "合约"],
        "proxySettings": [true: "Proxy Settings", false: "代理设置"],
        "proxyHost": [true: "Proxy Host", false: "代理主机"],
        "proxyPort": [true: "Proxy Port", false: "代理端口"],
        "enableProxy": [true: "Enable Proxy", false: "启用代理"],
    ]
    
    static func localized(_ key: String, isEnglish: Bool) -> String {
        return localizedStrings[key]?[isEnglish] ?? key
    }
    
    static let contractBaseUrl = [
        true: "https://www.binance.com/en/futures/",
        false: "https://www.binance.com/zh-CN/futures/"
    ]
    
    static func getContractUrl(symbol: String, isEnglish: Bool) -> String {
        return contractBaseUrl[isEnglish]! + symbol
    }
    
    static let feedbackUrl = "https://github.com/chenchenwuai/btc-watcher/issues"
}

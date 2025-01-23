import Foundation

struct Constants {
    static let appVersion = "v1.2.1"
    
    static let apiEndpoints = [
        "https://api.binance.com/api/v3/ticker/price",
        "https://api1.binance.com/api/v3/ticker/price",
        "https://api2.binance.com/api/v3/ticker/price",
        "https://api3.binance.com/api/v3/ticker/price",
        "https://api4.binance.com/api/v3/ticker/price"
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

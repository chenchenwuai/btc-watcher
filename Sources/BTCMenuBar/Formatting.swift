import Foundation

extension AppDelegate {
    func localized(_ key: String) -> String {
        return Constants.localized(key, isEnglish: isEnglish)
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

        let formattedPrice = String(format: "%.\(decimals)f", price)
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
}

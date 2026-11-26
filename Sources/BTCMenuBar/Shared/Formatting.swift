import Foundation

extension AppDelegate {
    func localized(_ key: String) -> String {
        return Constants.localized(key, isEnglish: isEnglish)
    }

    func calculateChangePercent(current: Double, base: Double?, direction: String) -> String {
        guard let base = base, base.isFinite, base > 0 else { return "" }
        let percent = (direction == "short" ? (base - current) : (current - base)) / base * 100
        guard percent.isFinite else { return "" }
        let sign = percent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, percent)
    }

    func positionInputMode(for symbol: String) -> PositionInputMode {
        positionInputModes[symbol].flatMap(PositionInputMode.init(rawValue:)) ?? .margin
    }

    func positionSize(for symbol: String) -> PositionSize? {
        let mode = positionInputMode(for: symbol)
        let amount = mode == .quantity ? positionQuantities[symbol] : positionMargins[symbol]
        guard let entryPrice = basePrices[symbol], let amount else { return nil }
        return PositionSize(entryPrice: entryPrice, leverage: positionLeverages[symbol] ?? 1, mode: mode, amount: amount)
    }

    func calculatePositionMetrics(symbol: String, current: Double) -> PositionMetrics? {
        guard let entryPrice = basePrices[symbol], let size = positionSize(for: symbol) else { return nil }

        let direction = positionDirections[symbol] ?? "long"
        let pnl = direction == "short" ? (entryPrice - current) * size.quantity : (current - entryPrice) * size.quantity
        let roi = pnl / size.margin * 100
        guard pnl.isFinite, roi.isFinite else { return nil }

        return PositionMetrics(quantity: size.quantity, margin: size.margin, notional: size.notional, pnl: pnl, roi: roi)
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

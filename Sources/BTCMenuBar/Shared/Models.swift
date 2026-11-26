import Foundation

struct CoinSymbol: Codable {
    let name: String
    let symbol: String
    let icon: String
}

struct PriceTicker: Decodable {
    let symbol: String
    let price: String

    var value: Double? {
        guard let value = Double(price), value.isFinite, value > 0 else { return nil }
        return value
    }
}

enum PositionInputMode: String {
    case margin
    case quantity
}

struct PositionSize {
    let quantity: Double
    let margin: Double
    let notional: Double

    init?(entryPrice: Double, leverage: Double, mode: PositionInputMode, amount: Double) {
        guard entryPrice.isFinite, entryPrice > 0, leverage.isFinite, leverage > 0,
              amount.isFinite, amount > 0 else { return nil }

        switch mode {
        case .margin:
            margin = amount
            notional = margin * leverage
            quantity = notional / entryPrice
        case .quantity:
            quantity = amount
            notional = entryPrice * quantity
            margin = notional / leverage
        }

        guard quantity.isFinite, quantity > 0, margin.isFinite, margin > 0,
              notional.isFinite, notional > 0 else { return nil }
    }
}

struct PositionMetrics {
    let quantity: Double
    let margin: Double
    let notional: Double
    let pnl: Double
    let roi: Double
}

import Foundation

struct CoinSymbol: Codable {
    let name: String
    let symbol: String
    let icon: String
}

struct PositionMetrics {
    let quantity: Double
    let margin: Double
    let notional: Double
    let pnl: Double
    let roi: Double
}

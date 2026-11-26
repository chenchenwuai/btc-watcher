import Cocoa

enum PriceTrendPeriod: String, CaseIterable {
    case off
    case live
    case fifteenMinutes = "15m"
    case oneHour = "1h"
    case fourHours = "4h"

    var klineInterval: String? {
        switch self {
        case .off, .live: return nil
        case .fifteenMinutes, .oneHour, .fourHours: return rawValue
        }
    }
}

struct HistoricalPriceTrend {
    struct Selection: Equatable {
        let symbol: String
        let isFutures: Bool
        let interval: String
    }

    struct Candle: Decodable {
        let openTime: TimeInterval
        let closeTime: TimeInterval
        var price: Double

        init(from decoder: Decoder) throws {
            var row = try decoder.unkeyedContainer()
            let open = try row.decode(Int64.self)
            for _ in 0..<3 {
                _ = try row.decode(String.self) // Open, high, and low prices
            }
            let closePrice = try row.decode(String.self)
            _ = try row.decode(String.self) // Volume
            let close = try row.decode(Int64.self)
            guard open > 0, close >= open,
                  let price = Double(closePrice), price.isFinite, price > 0 else {
                throw DecodingError.dataCorruptedError(in: row, debugDescription: "Invalid price or time in K-line")
            }
            openTime = TimeInterval(open) / 1000
            closeTime = TimeInterval(close) / 1000
            self.price = price
        }
    }

    let selection: Selection
    var candles: [Candle] = []
    var request: (id: UUID, task: URLSessionDataTask)?
    var retryAfter: ContinuousClock.Instant = .now
    var refreshFailed = false

    mutating func applyQuote(_ price: Double, requestedAt: TimeInterval, receivedAt: TimeInterval) {
        guard let last = candles.last, last.openTime <= requestedAt,
              requestedAt <= receivedAt, receivedAt <= last.closeTime else { return }
        candles[candles.count - 1].price = price
    }
}

extension AppDelegate {
    var historicalTrendSelection: HistoricalPriceTrend.Selection? {
        guard let interval = priceTrendPeriod.klineInterval else { return nil }
        return .init(symbol: currentSymbol, isFutures: isFuturesMode, interval: interval)
    }

    func cancelHistoricalTrendRequest() {
        historicalPriceTrend?.request?.task.cancel()
        historicalPriceTrend?.request = nil
        historicalPriceTrend?.retryAfter = .now
    }

    func refreshHistoricalTrendIfNeeded() {
        let selection = historicalTrendSelection
        if historicalPriceTrend?.selection != selection {
            cancelHistoricalTrendRequest()
            historicalPriceTrend = selection.map { HistoricalPriceTrend(selection: $0) }
        }

        guard let trend = historicalPriceTrend, trend.request == nil, trend.retryAfter <= .now,
              (trend.candles.last?.closeTime ?? 0) < Date().timeIntervalSince1970,
              var urlComponents = URLComponents(string: apiEndpoints[currentApiIndex]) else { return }

        urlComponents.path = trend.selection.isFutures ? "/fapi/v1/klines" : "/api/v3/klines"
        urlComponents.queryItems = [
            URLQueryItem(name: "symbol", value: trend.selection.symbol),
            URLQueryItem(name: "interval", value: trend.selection.interval),
            URLQueryItem(name: "limit", value: "30"),
        ]
        guard let url = urlComponents.url else { return }

        let requestID = UUID()
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            let success = error == nil && (response as? HTTPURLResponse).map { (200..<300).contains($0.statusCode) } == true
            let candles = success ? data.flatMap { try? JSONDecoder().decode([HistoricalPriceTrend.Candle].self, from: $0) } : nil

            RunLoop.main.perform(inModes: [.default, .eventTracking, .modalPanel]) { [weak self] in
                guard let self, self.historicalTrendSelection == selection,
                      self.historicalPriceTrend?.request?.id == requestID else { return }
                self.historicalPriceTrend?.request = nil
                if let candles, let last = candles.last, zip(candles, candles.dropFirst()).allSatisfy({ $0.closeTime < $1.openTime }) {
                    self.historicalPriceTrend?.candles = candles
                    self.historicalPriceTrend?.refreshFailed = false
                    // When the exchange has not opened the next candle yet, avoid polling it every tick.
                    self.historicalPriceTrend?.retryAfter = last.closeTime < Date().timeIntervalSince1970 ? .now + .seconds(30) : .now
                } else {
                    self.historicalPriceTrend?.refreshFailed = true
                    self.historicalPriceTrend?.retryAfter = .now + .seconds(30)
                }

                self.refreshStatusTitleFromCache()
            }
        }
        historicalPriceTrend?.request = (requestID, task)
        task.resume()
    }
}

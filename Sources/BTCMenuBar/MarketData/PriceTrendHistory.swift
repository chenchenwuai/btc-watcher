struct PriceTrendHistory {
    struct Sample {
        let time: ContinuousClock.Instant
        let price: Double
    }

    private struct Pair: Hashable {
        let symbol: String
        let isFutures: Bool
    }

    private static let window = Duration.seconds(300)
    private static let maximumGap = Duration.seconds(15)
    private static let maximumSamples = 300

    private var samplesByPair: [Pair: [Sample]] = [:]

    mutating func record(_ prices: [String: Double], isFutures: Bool, at time: ContinuousClock.Instant = .now) {
        let cutoff = time - Self.window

        for (symbol, price) in prices {
            let pair = Pair(symbol: symbol, isFutures: isFutures)
            if let last = samplesByPair[pair]?.last {
                guard last.time < time else { continue }
                // Restart the line after a gap so it does not imply a price path through missing data.
                if last.time.duration(to: time) > Self.maximumGap {
                    samplesByPair[pair] = nil
                }
            }

            samplesByPair[pair, default: []].removeAll { $0.time < cutoff }
            if samplesByPair[pair, default: []].count >= Self.maximumSamples {
                samplesByPair[pair, default: []].removeFirst()
            }
            samplesByPair[pair, default: []].append(Sample(time: time, price: price))
        }
    }

    func samples(for symbol: String, isFutures: Bool, at time: ContinuousClock.Instant = .now) -> [Sample] {
        let cutoff = time - Self.window
        return samplesByPair[Pair(symbol: symbol, isFutures: isFutures)]?.filter { $0.time >= cutoff } ?? []
    }

    mutating func remove(symbol: String) {
        samplesByPair.removeValue(forKey: Pair(symbol: symbol, isFutures: false))
        samplesByPair.removeValue(forKey: Pair(symbol: symbol, isFutures: true))
    }
}

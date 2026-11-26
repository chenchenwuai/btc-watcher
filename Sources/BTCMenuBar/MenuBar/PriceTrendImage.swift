import Cocoa

extension AppDelegate {
    func priceTrendImage(for symbol: String, hasLatestPrice: Bool) -> NSImage? {
        let points: [(time: TimeInterval, price: Double)]
        let description: String
        if priceTrendPeriod == .live {
            guard hasLatestPrice else { return nil }
            let samples = priceTrendHistory.samples(for: symbol, isFutures: isFuturesMode)
            guard let first = samples.first else { return nil }
            points = samples.map { (first.time.duration(to: $0.time) / .seconds(1), $0.price) }
            description = localized("priceTrendDescription")
        } else {
            guard let selection = historicalTrendSelection, selection.symbol == symbol,
                  let trend = historicalPriceTrend, trend.selection == selection else { return nil }
            points = trend.candles.map { ($0.openTime, $0.price) }
            description = String(format: localized("priceTrendKlineDescription"), selection.interval)
        }

        guard let first = points.first, let last = points.last, last.time > first.time,
              let minimum = points.min(by: { $0.price < $1.price })?.price,
              let maximum = points.max(by: { $0.price < $1.price })?.price else { return nil }

        let duration = last.time - first.time
        let spread = maximum - minimum
        let image = NSImage(size: NSSize(width: 36, height: 12), flipped: false) { rect in
            let plot = rect.insetBy(dx: 2, dy: 2)
            let path = NSBezierPath()
            path.lineWidth = 1.25
            path.lineCapStyle = .round
            path.lineJoinStyle = .round

            for (index, sample) in points.enumerated() {
                let elapsed = sample.time - first.time
                let height = spread > 0 ? (sample.price - minimum) / spread : 0.5
                let point = NSPoint(
                    x: plot.minX + plot.width * CGFloat(elapsed / duration),
                    y: plot.minY + plot.height * CGFloat(height)
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.line(to: point)
                }
            }

            NSColor.black.setStroke()
            path.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = description
        return image
    }
}

import Cocoa

extension AppDelegate {
    func configureUrlSession() {
        cancelPriceUpdate()
        cancelHistoricalTrendRequest()
        urlSession.invalidateAndCancel()
        urlSession = URLSession(configuration: configureNetwork(.default))
        failedAttempts = 0
        if statusItem != nil && usesBinancePositions { restartBinancePositionSync() }
    }

    func configureNetwork(_ config: URLSessionConfiguration) -> URLSessionConfiguration {
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12

        if isProxyEnabled && !proxyHost.isEmpty {
            config.connectionProxyDictionary = [
                kCFNetworkProxiesSOCKSProxy: proxyHost,
                kCFNetworkProxiesSOCKSPort: Int(proxyPort) ?? 1080,
                kCFNetworkProxiesSOCKSEnable: 1
            ]
        }

        return config
    }

    func startTimer(interval: TimeInterval = 2.0, fireImmediately: Bool = true) {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.updatePrice()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        RunLoop.main.add(newTimer, forMode: .eventTracking)
        timer = newTimer
        if fireImmediately {
            newTimer.fire()
        }
    }

    func cancelPriceUpdate() {
        priceRequest?.task.cancel()
        priceRequest = nil
    }

    func updatePrice() {
        refreshHistoricalTrendIfNeeded()
        guard priceRequest == nil, var components = URLComponents(string: apiEndpoints[currentApiIndex]) else { return }

        let watchedSymbols = Set(symbols.map { $0.1 })
        let requestsSpotSubset = !isFuturesMode && !useAllSpotPrices
        if requestsSpotSubset, let data = try? JSONEncoder().encode(watchedSymbols.sorted()) {
            components.queryItems = [URLQueryItem(name: "symbols", value: String(decoding: data, as: UTF8.self))]
        }
        guard let url = components.url else { return }

        let requestID = UUID()
        let requestedAt = Date().timeIntervalSince1970
        let task = urlSession.dataTask(with: url) { [weak self] data, response, error in
            let receivedAt = Date().timeIntervalSince1970
            let status = (response as? HTTPURLResponse)?.statusCode
            let tickers = status.map { (200..<300).contains($0) } == true && error == nil
                ? data.flatMap { try? JSONDecoder().decode([PriceTicker].self, from: $0) }
                : nil
            let invalidSpotSymbol = requestsSpotSubset && status == 400 && data.flatMap {
                (try? JSONSerialization.jsonObject(with: $0) as? [String: Any])?["code"] as? Int
            } == -1121

            RunLoop.main.perform(inModes: [.default, .eventTracking, .modalPanel]) { [weak self] in
                guard let self, self.priceRequest?.id == requestID else { return }
                self.priceRequest = nil

                if invalidSpotSymbol {
                    // A futures-only or delisted symbol can invalidate an entire spot batch.
                    self.useAllSpotPrices = true
                    self.updatePrice()
                    return
                }

                if let tickers {
                    var prices: [String: Double] = [:]
                    for ticker in tickers where watchedSymbols.contains(ticker.symbol) {
                        prices[ticker.symbol] = ticker.value
                    }
                    self.latestPrices = prices
                    if self.priceTrendPeriod != .off {
                        self.priceTrendHistory.record(prices, isFutures: self.isFuturesMode)
                    } else if let price = prices[self.currentSymbol] {
                        self.priceTrendHistory.record([self.currentSymbol: price], isFutures: self.isFuturesMode)
                    }
                    if let price = prices[self.currentSymbol], self.historicalPriceTrend?.selection == self.historicalTrendSelection {
                        self.historicalPriceTrend?.applyQuote(price, requestedAt: requestedAt, receivedAt: receivedAt)
                    }
                    self.watchlistRefreshFailed = false
                    self.failedAttempts = 0
                } else {
                    self.watchlistRefreshFailed = true
                    self.handleApiError()
                }

                self.refreshWatchlistTitles()
                self.refreshStatusTitleFromCache()
                self.refreshQuotePanel()
            }
        }
        priceRequest = (requestID, task)
        task.resume()
    }

    func updateSelectedSymbol(_ symbol: String) {
        guard let (_, _, icon) = symbols.first(where: { $0.1 == symbol }) else { return }
        currentSymbol = symbol
        currentIcon = icon
        UserDefaults.standard.set(symbol, forKey: "lastSymbol")
        setupMenu()
        refreshStatusTitleFromCache()
        updatePrice()
    }

    func validateAndAddCoin(_ symbol: String) {
        if symbols.contains(where: { $0.1 == symbol }) {
            updateSelectedSymbol(symbol)
            return
        }

        let endpoint = apiEndpoints[currentApiIndex]
        guard var components = URLComponents(string: endpoint) else { return }
        components.queryItems = [URLQueryItem(name: "symbol", value: symbol)]
        guard let url = components.url else { return }

        let session = urlSession
        session.dataTask(with: url) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode
            let ticker = status.map { (200..<300).contains($0) } == true && error == nil
                ? data.flatMap { try? JSONDecoder().decode(PriceTicker.self, from: $0) }
                : nil

            DispatchQueue.main.async { [weak self] in
                guard let self, self.urlSession === session, self.apiEndpoints[self.currentApiIndex] == endpoint else { return }
                guard let ticker, ticker.symbol == symbol, let price = ticker.value else {
                    self.showError("invalidCoin")
                    return
                }

                if !self.symbols.contains(where: { $0.1 == symbol }) {
                    let name = String(symbol.dropLast("USDT".count))
                    self.symbols.append((name, symbol, name))
                    self.cancelPriceUpdate()
                    self.useAllSpotPrices = false
                    self.saveCustomSymbols()
                }

                self.latestPrices[symbol] = price
                self.updateSelectedSymbol(symbol)
            }
        }.resume()
    }

    private func handleApiError() {
        failedAttempts += 1
        if isAutoSwitchApi && failedAttempts >= 3 {
            cancelHistoricalTrendRequest()
            currentApiIndex = (currentApiIndex + 1) % apiEndpoints.count
            UserDefaults.standard.set(currentApiIndex, forKey: "currentApiIndex")
            print("Switching to API \(currentApiIndex + 1)")
            failedAttempts = 0
        }
    }
}

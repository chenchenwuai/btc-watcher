import Foundation

extension AppDelegate {
    func getCurrentApiEndpoint() -> String {
        return apiEndpoints[currentApiIndex]
    }

    func configureUrlSession() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12

        if isProxyEnabled && !proxyHost.isEmpty {
            config.connectionProxyDictionary = [
                kCFNetworkProxiesSOCKSProxy: proxyHost,
                kCFNetworkProxiesSOCKSPort: Int(proxyPort) ?? 1080,
                kCFNetworkProxiesSOCKSEnable: 1
            ]
        }

        urlSession = URLSession(configuration: config)
    }

    func startTimer(interval: TimeInterval = 2.0, fireImmediately: Bool = true) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updatePrice()
        }
        if fireImmediately {
            timer?.fire()
        }
    }

    func switchToNextApi() {
        currentApiIndex = (currentApiIndex + 1) % apiEndpoints.count
        UserDefaults.standard.set(currentApiIndex, forKey: "currentApiIndex")
        print("Switching to API \(currentApiIndex + 1)")
    }

    func updatePrice() {
        let symbol = currentSymbol
        guard let url = URL(string: "\(apiEndpoints[currentApiIndex])?symbol=\(symbol)") else { return }

        urlSession.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("Error: \(error.localizedDescription)")
                self.handleApiError()
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let data = data,
                  let priceValue = self.parsePrice(from: data)
            else {
                self.handleApiError()
                return
            }

            DispatchQueue.main.async {
                self.failedAttempts = 0
                self.latestPrices[symbol] = priceValue
                guard symbol == self.currentSymbol else { return }
                self.updateStatusTitle(symbol: symbol, priceValue: priceValue)
            }
        }.resume()
    }

    func parsePrice(from data: Data) -> Double? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let priceString = json["price"] as? String,
              let priceValue = Double(priceString)
        else {
            return nil
        }

        return priceValue
    }

    func fetchPrice(symbol: String, completion: @escaping (Double?) -> Void) {
        guard let url = URL(string: "\(getCurrentApiEndpoint())?symbol=\(symbol)") else {
            completion(nil)
            return
        }

        urlSession.dataTask(with: url) { [weak self] data, response, error in
            guard let self else {
                completion(nil)
                return
            }

            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let data = data,
                  let priceValue = self.parsePrice(from: data)
            else {
                completion(nil)
                return
            }

            completion(priceValue)
        }.resume()
    }

    func updateSelectedSymbol(_ symbol: String) {
        currentSymbol = symbol
        if let (_, _, icon) = symbols.first(where: { $0.1 == symbol }) {
            currentIcon = icon
        }
        UserDefaults.standard.set(symbol, forKey: "lastSymbol")
        setupMenu()
        updatePrice()
    }

    func addValidatedCoin(_ symbol: String) {
        let name = symbol.replacingOccurrences(of: "USDT", with: "")
        symbols.append((name, symbol, name))
        currentSymbol = symbol
        currentIcon = name
        saveCustomSymbols()
        UserDefaults.standard.set(symbol, forKey: "lastSymbol")
        setupMenu()
        updatePrice()
    }

    func validateAndAddCoin(_ symbol: String) {
        if symbols.contains(where: { $0.1 == symbol }) {
            DispatchQueue.main.async {
                self.updateSelectedSymbol(symbol)
            }
            return
        }

        fetchPrice(symbol: symbol) { [weak self] price in
            guard let self, let price else {
                DispatchQueue.main.async {
                    self?.showError("invalidCoin")
                }
                return
            }

            DispatchQueue.main.async {
                self.latestPrices[symbol] = price
                self.addValidatedCoin(symbol)
            }
        }
    }

    func handleApiError() {
        DispatchQueue.main.async {
            self.failedAttempts += 1

            if self.isAutoSwitchApi && self.failedAttempts >= 3 {
                self.switchToNextApi()
                self.failedAttempts = 0
            }
        }
    }
}

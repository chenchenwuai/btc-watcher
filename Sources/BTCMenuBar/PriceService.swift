import Foundation

extension AppDelegate {
    func getCurrentApiEndpoint() -> String {
        return apiEndpoints[currentApiIndex]
    }

    func configureUrlSession() {
        if isProxyEnabled && !proxyHost.isEmpty {
            let config = URLSessionConfiguration.default
            config.connectionProxyDictionary = [
                kCFNetworkProxiesSOCKSProxy: proxyHost,
                kCFNetworkProxiesSOCKSPort: Int(proxyPort) ?? 1080,
                kCFNetworkProxiesSOCKSEnable: 1
            ]
            urlSession = URLSession(configuration: config)
        } else {
            urlSession = URLSession.shared
        }
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

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let priceString = json["price"] as? String,
               let priceValue = Double(priceString) {
                DispatchQueue.main.async {
                    self.failedAttempts = 0
                    self.latestPrices[symbol] = priceValue
                    guard symbol == self.currentSymbol else { return }
                    self.updateStatusTitle(symbol: symbol, priceValue: priceValue)
                }
            }
        }.resume()
    }

    func validateAndAddCoin(_ symbol: String) {
        if symbols.contains(where: { $0.1 == symbol }) {
            DispatchQueue.main.async {
                self.currentSymbol = symbol
                if let (_, _, icon) = self.symbols.first(where: { $0.1 == symbol }) {
                    self.currentIcon = icon
                }
                self.setupMenu()
                self.updatePrice()
            }
            return
        }

        guard let url = URL(string: "\(getCurrentApiEndpoint())?symbol=\(symbol)") else { return }

        urlSession.dataTask(with: url) { [weak self] data, response, error in
            guard let self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let _ = json["price"] as? String
            else {
                DispatchQueue.main.async {
                    self?.showError("invalidCoin")
                }
                return
            }

            DispatchQueue.main.async {
                let name = symbol.replacingOccurrences(of: "USDT", with: "")
                self.symbols.append((name, symbol, name))
                self.currentSymbol = symbol
                self.currentIcon = name
                self.saveCustomSymbols()
                UserDefaults.standard.set(symbol, forKey: "lastSymbol")
                self.setupMenu()
                self.updatePrice()
            }
        }.resume()
    }

    func handleApiError() {
        failedAttempts += 1

        if isAutoSwitchApi && failedAttempts >= 3 {
            switchToNextApi()
            failedAttempts = 0
        }
    }
}

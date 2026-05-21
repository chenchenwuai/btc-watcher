import Cocoa

extension AppDelegate {
    @objc func setBasePrice(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }

        let alert = NSAlert()
        alert.messageText = localized("setBasePrice")
        if let existingPrice = basePrices[symbol] {
            alert.informativeText = "\(symbol)\n\(localized("basePrice")): \(formatPrice(existingPrice))"
        } else {
            alert.informativeText = "\(symbol)"
        }

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = localized("emptyBasePriceUsesCurrent")
        alert.accessoryView = input
        alert.addButton(withTitle: localized("ok"))
        alert.addButton(withTitle: localized("cancel"))

        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            input.window?.makeFirstResponder(input)
        }

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let priceString = input.stringValue.trimmingCharacters(in: .whitespaces)
            if priceString.isEmpty {
                setBasePriceToCurrentPrice(for: symbol)
            } else if let price = Double(priceString), price > 0 {
                updateBasePrice(price, for: symbol)
            }
        }
    }

    func setBasePriceToCurrentPrice(for symbol: String) {
        if let latestPrice = latestPrices[symbol] {
            updateBasePrice(latestPrice, for: symbol)
            return
        }

        guard let url = URL(string: "\(getCurrentApiEndpoint())?symbol=\(symbol)") else { return }

        urlSession.dataTask(with: url) { [weak self] data, _, _ in
            guard let self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let priceString = json["price"] as? String,
                  let price = Double(priceString),
                  price > 0
            else {
                DispatchQueue.main.async {
                    self?.showError("invalidCoin")
                }
                return
            }

            DispatchQueue.main.async {
                self.latestPrices[symbol] = price
                self.updateBasePrice(price, for: symbol)
            }
        }.resume()
    }

    func updateBasePrice(_ price: Double, for symbol: String) {
        basePrices[symbol] = price
        if positionDirections[symbol] == nil {
            positionDirections[symbol] = "long"
        }
        saveBasePrices()
        savePositionSettings()
        setupMenu()
        if symbol == currentSymbol {
            updatePrice()
        }
    }

    @objc func setLongPosition(_ sender: NSMenuItem) {
        setPositionDirection("long", sender: sender)
    }

    @objc func setShortPosition(_ sender: NSMenuItem) {
        setPositionDirection("short", sender: sender)
    }

    func setPositionDirection(_ direction: String, sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        positionDirections[symbol] = direction
        savePositionDirections()
        setupMenu()
        if symbol == currentSymbol {
            updatePrice()
        }
    }

    @objc func setPositionMargin(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        showPositionValueAlert(
            symbol: symbol,
            titleKey: "setMargin",
            placeholder: "10",
            existingValue: positionMargins[symbol],
            suffix: "U"
        ) { [weak self] value in
            self?.positionMargins[symbol] = value
            self?.positionInputModes[symbol] = "margin"
            self?.savePositionSettings()
            self?.setupMenu()
            if symbol == self?.currentSymbol {
                self?.updatePrice()
            }
        }
    }

    @objc func setPositionQuantity(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        showPositionValueAlert(
            symbol: symbol,
            titleKey: "setQuantity",
            placeholder: "10000",
            existingValue: positionQuantities[symbol],
            suffix: coinName(for: symbol)
        ) { [weak self] value in
            self?.positionQuantities[symbol] = value
            self?.positionInputModes[symbol] = "quantity"
            self?.savePositionSettings()
            self?.setupMenu()
            if symbol == self?.currentSymbol {
                self?.updatePrice()
            }
        }
    }

    @objc func setPositionLeverage(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        showPositionValueAlert(
            symbol: symbol,
            titleKey: "setLeverage",
            placeholder: "50",
            existingValue: positionLeverages[symbol],
            suffix: "x"
        ) { [weak self] value in
            self?.positionLeverages[symbol] = value
            self?.savePositionSettings()
            self?.setupMenu()
            if symbol == self?.currentSymbol {
                self?.updatePrice()
            }
        }
    }

    func showPositionValueAlert(
        symbol: String,
        titleKey: String,
        placeholder: String,
        existingValue: Double?,
        suffix: String,
        onSave: (Double) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = localized(titleKey)
        alert.informativeText = "\(symbol) \(suffix)"

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        input.placeholderString = placeholder
        if let existingValue = existingValue, existingValue > 0 {
            input.stringValue = formatPrice(existingValue)
        }
        alert.accessoryView = input
        alert.addButton(withTitle: localized("ok"))
        alert.addButton(withTitle: localized("cancel"))

        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            input.window?.makeFirstResponder(input)
        }

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            let valueString = input.stringValue.trimmingCharacters(in: .whitespaces)
            if let value = Double(valueString), value > 0 {
                onSave(value)
            }
        }
    }

    @objc func clearBasePrice(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        basePrices.removeValue(forKey: symbol)
        positionDirections.removeValue(forKey: symbol)
        positionInputModes.removeValue(forKey: symbol)
        positionMargins.removeValue(forKey: symbol)
        positionQuantities.removeValue(forKey: symbol)
        positionLeverages.removeValue(forKey: symbol)
        saveBasePrices()
        savePositionSettings()
        setupMenu()
        if symbol == currentSymbol {
            updatePrice()
        }
    }
}

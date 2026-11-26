import Cocoa

extension AppDelegate {
    @objc func configureBinanceAccount() {
        guard !isBinanceRequestInProgress else { return showError("binanceRequestInProgress") }

        let alert = NSAlert()
        alert.messageText = localized("binanceAccount")
        alert.informativeText = localized("binanceAccountInstructions")

        let apiKeyInput = NSSecureTextField()
        let secretKeyInput = NSSecureTextField()
        apiKeyInput.setAccessibilityLabel("API Key")
        secretKeyInput.setAccessibilityLabel("Secret Key")
        let fields = NSGridView(views: [
            [NSTextField(labelWithString: "API Key"), apiKeyInput],
            [NSTextField(labelWithString: "Secret Key"), secretKeyInput]
        ])
        fields.rowSpacing = 8
        fields.columnSpacing = 12
        apiKeyInput.widthAnchor.constraint(equalToConstant: 225).isActive = true
        secretKeyInput.widthAnchor.constraint(equalTo: apiKeyInput.widthAnchor).isActive = true
        fields.frame.size = fields.fittingSize
        alert.accessoryView = fields
        alert.addButton(withTitle: localized("binanceTestAndSave"))
        alert.addButton(withTitle: localized("cancel"))

        defer {
            apiKeyInput.stringValue = ""
            secretKeyInput.stringValue = ""
        }
        NSApp.activate(ignoringOtherApps: true)
        alert.window.initialFirstResponder = apiKeyInput
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let apiKey = apiKeyInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let secretKey = secretKeyInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, !secretKey.isEmpty,
              apiKey.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              secretKey.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return showError("binanceEnterCredentials")
        }
        requestBinanceOrders(symbol: currentSymbol, credentialsToSave: BinanceCredentials(apiKey: apiKey, secretKey: Data(secretKey.utf8)))
    }

    @objc func showBinanceOrders(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }
        requestBinanceOrders(symbol: symbol, credentialsToSave: nil)
    }

    private func requestBinanceOrders(symbol: String, credentialsToSave: BinanceCredentials?) {
        guard !isBinanceRequestInProgress else { return showError("binanceRequestInProgress") }
        isBinanceRequestInProgress = true
        let futures = isFuturesMode
        let configuration = configureNetwork(.ephemeral)

        Task { @MainActor in
            defer { isBinanceRequestInProgress = false }
            let market = localized(futures ? "futuresMode" : "spotMode")
            let context = "\(symbol) · \(market)"
            do {
                let credentials = try await Task.detached {
                    try credentialsToSave ?? BinanceCredentials.load()
                }.value
                let orders = try await BinanceAccountService().openOrders(
                    symbol: symbol, futures: futures, apiKey: credentials.apiKey, secretKey: credentials.secretKey,
                    configuration: configuration
                )
                if credentialsToSave != nil {
                    try await Task.detached { try credentials.save() }.value
                    if usesBinancePositions { restartBinancePositionSync(using: credentials) }
                    showBinanceAlert(title: localized("binanceAccount"), message: "\(context)\n\(localized("binanceAccountSaved"))")
                } else {
                    showOpenOrders(orders, context: context)
                }
            } catch {
                showBinanceAlert(title: localized("error"), message: "\(context)\n\(binanceErrorMessage(error))", style: .warning)
            }
        }
    }

    private func showOpenOrders(_ orders: [BinanceOpenOrder], context: String) {
        let title = localized("binanceOpenOrders")
        let message = orders.isEmpty ? "\(context)\n\(localized("binanceEmptyOrders"))" : "\(context) · \(orders.count)"
        showBinanceList(title: title, message: message, rows: orders.map(orderDescription))
    }

    @discardableResult
    func showBinanceList(title: String, message: String, rows: [String], retry: Bool = false) -> NSApplication.ModalResponse {
        guard !rows.isEmpty else { return showBinanceAlert(title: title, message: message, retry: retry) }

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 400, height: min(260, rows.count * 72 + 12)))
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        let text = NSTextView(frame: NSRect(origin: .zero, size: scroll.contentSize))
        text.isEditable = false
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        text.textContainerInset = NSSize(width: 8, height: 8)
        text.font = .systemFont(ofSize: NSFont.systemFontSize)
        text.string = rows.joined(separator: "\n\n")
        scroll.documentView = text

        return showBinanceAlert(title: title, message: message, accessory: scroll, retry: retry)
    }

    private func orderDescription(_ order: BinanceOpenOrder) -> String {
        let positionSide = order.positionSide.flatMap { $0 == "BOTH" ? nil : $0 }
        let heading = [order.side, positionSide, order.orderType ?? order.type, order.algoStatus ?? order.status]
            .compactMap { $0 }.joined(separator: " · ")

        var details: [String] = []
        if let price = Decimal(string: order.price), price > 0 {
            details.append("\(localized("binanceOrderPrice")) \(order.price)")
        }
        if let trigger = order.triggerPrice ?? order.stopPrice, let price = Decimal(string: trigger), price > 0 {
            details.append("\(localized("binanceTriggerPrice")) \(trigger)")
        }
        if order.closePosition == true {
            details.append(localized("binanceClosePosition"))
        } else if let quantity = order.quantity ?? order.origQty {
            details.append("\(localized("quantity")) \(quantity)")
        }
        if let filled = order.executedQty, let quantity = Decimal(string: filled), quantity > 0 {
            details.append("\(localized("binanceExecutedQuantity")) \(filled)")
        }
        return details.isEmpty ? heading : "\(heading)\n\(details.joined(separator: " · "))"
    }

    func binanceErrorMessage(_ error: Error, requestError: String = "binanceRequestError") -> String {
        switch error {
        case BinanceCredentials.Failure.missingCredentials, BinanceCredentials.Failure.invalidCredentials:
            return localized("binanceMissingCredentials")
        case BinanceCredentials.Failure.read(let status):
            return "\(localized("binanceKeychainReadError")) (\(status))"
        case BinanceCredentials.Failure.save(let status):
            return "\(localized("binanceKeychainSaveError")) (\(status))"
        case BinanceAccountService.Failure.rejected(let status, let code):
            let hint: String
            switch code {
            case -1021: hint = "\n" + localized("binanceClockError")
            case -2014, -2015: hint = "\n" + localized("binancePermissionError")
            default: hint = ""
            }
            let reason = code.map { "Binance \($0)" } ?? "HTTP \(status)"
            return "\(localized(requestError)) (\(reason))\(hint)"
        default:
            return localized(requestError)
        }
    }

    @discardableResult
    private func showBinanceAlert(title: String, message: String, accessory: NSView? = nil,
                                  style: NSAlert.Style = .informational, retry: Bool = false) -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.accessoryView = accessory
        alert.alertStyle = style
        alert.addButton(withTitle: localized("ok"))
        if retry { alert.addButton(withTitle: localized("binanceRetryPositions")) }
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}

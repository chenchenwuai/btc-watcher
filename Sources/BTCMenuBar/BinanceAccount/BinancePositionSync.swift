import Cocoa

extension AppDelegate {
    var usesBinancePositions: Bool { isFuturesMode && isBinancePositionSyncEnabled }

    @objc func toggleBinancePositionSync() {
        isBinancePositionSyncEnabled.toggle()
        UserDefaults.standard.set(isBinancePositionSyncEnabled, forKey: "syncBinancePositions")
        restartBinancePositionSync()
        setupMenu()
    }

    func restartBinancePositionSync(using savedCredentials: BinanceCredentials? = nil) {
        binancePositionSyncTask?.cancel()
        binancePositionSyncTask = nil
        binancePositions = []
        binancePositionSyncError = nil
        hasSyncedBinancePositions = false
        refreshStatusTitleFromCache()
        guard usesBinancePositions else { return }

        let configuration = configureNetwork(.ephemeral)
        binancePositionSyncTask = Task { @MainActor [weak self] in
            defer {
                if !Task.isCancelled { self?.binancePositionSyncTask = nil }
            }
            do {
                let credentials = try await Task.detached {
                    try savedCredentials ?? BinanceCredentials.load()
                }.value
                let service = BinanceAccountService()
                while !Task.isCancelled {
                    do {
                        let positions = try await service.futuresPositions(
                            apiKey: credentials.apiKey, secretKey: credentials.secretKey, configuration: configuration
                        )
                        try Task.checkCancellation()
                        self?.binancePositions = positions
                        self?.binancePositionSyncError = nil
                        self?.hasSyncedBinancePositions = true
                    } catch BinanceAccountService.Failure.rejected(let status, let code)
                        where status == 401 || status == 418 || status == 429 || code == -2014 || code == -2015 {
                        // Pause automatic requests until the user can correct access or retry later.
                        throw BinanceAccountService.Failure.rejected(httpStatus: status, code: code)
                    } catch {
                        try Task.checkCancellation()
                        self?.binancePositionSyncError = error
                    }
                    self?.refreshStatusTitleFromCache()
                    try await Task.sleep(for: .seconds(30))
                }
            } catch {
                guard !Task.isCancelled else { return }
                self?.binancePositionSyncError = error
                self?.refreshStatusTitleFromCache()
            }
        }
    }

    @objc func showBinancePositions() {
        guard usesBinancePositions else { return }
        let positions = binancePositions.sorted { ($0.symbol, $0.positionSide) < ($1.symbol, $1.positionSide) }
        let message: String
        if let error = binancePositionSyncError {
            let reason = binanceErrorMessage(error, requestError: "binancePositionsError")
            message = positions.isEmpty ? reason : "\(reason)\n\(localized("binanceStalePositions"))"
        } else if hasSyncedBinancePositions {
            message = positions.isEmpty ? localized("binanceEmptyPositions") : "\(localized("futuresMode")) · \(positions.count)"
        } else {
            message = localized("binanceLoadingPositions")
        }

        let retry = binancePositionSyncTask == nil && binancePositionSyncError != nil
        let response = showBinanceList(title: localized("binancePositions"), message: message,
                                       rows: positions.map(binancePositionDescription), retry: retry)
        if response == .alertSecondButtonReturn { restartBinancePositionSync() }
    }

    func binancePositionDetails(for symbol: String) -> [String] {
        let positions = binancePositions.filter { $0.symbol == symbol }
        guard let first = positions.first else { return [] }

        var details: [String] = []
        if showMenuBarChange && positions.count == 1 {
            let change = calculateChangePercent(current: first.markPrice, base: first.entryPrice,
                                                direction: first.isShort ? "short" : "long")
            if !change.isEmpty { details.append(change) }
        }

        guard positions.allSatisfy({ $0.marginAsset == first.marginAsset }) else { return details }
        let pnl = positions.reduce(0) { $0 + $1.unrealizedPnl }
        if showMenuBarPnl { details.append(formatSignedAmount(pnl, suffix: " \(first.marginAsset)")) }
        if showMenuBarRoi && positions.allSatisfy({ $0.initialMargin > 0 }) {
            let margin = positions.reduce(0) { $0 + $1.initialMargin }
            let roi = pnl / margin * 100
            if roi.isFinite { details.append("ROI \(formatSignedAmount(roi, suffix: "%"))") }
        }
        return details
    }

    private func binancePositionDescription(_ position: BinanceFuturesPosition) -> String {
        let direction = localized(position.isShort ? "shortPosition" : "longPosition")
        let entry = "\(localized("binanceEntryPrice")) \(formatPrice(position.entryPrice))"
        let mark = "\(localized("binanceMarkPrice")) \(formatPrice(position.markPrice))"
        let quantity = "\(localized("quantity")) \(position.quantity)"
        let pnl = "\(localized("showPnl")) \(formatSignedAmount(position.unrealizedPnl, suffix: " \(position.marginAsset)"))"
        return "\(position.symbol) · \(direction)\n\(entry) · \(mark)\n\(quantity) · \(pnl)"
    }
}

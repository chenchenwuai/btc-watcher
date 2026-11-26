import Cocoa

extension AppDelegate {
    @objc func editPosition(_ sender: NSMenuItem) {
        guard let symbol = sender.representedObject as? String else { return }

        let alert = NSAlert()
        alert.messageText = localized("editPosition")
        alert.informativeText = symbol
        let saveButton = alert.addButton(withTitle: localized("savePosition"))
        alert.addButton(withTitle: localized("cancel"))

        let editor = PositionEditorView(app: self, symbol: symbol)
        editor.onValidityChange = { [weak saveButton] isValid in
            saveButton?.isEnabled = isValid
        }
        saveButton.isEnabled = editor.draft != nil
        alert.accessoryView = editor
        alert.window.initialFirstResponder = editor.entryField
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn, let draft = editor.draft else { return }

        basePrices[symbol] = draft.entryPrice
        positionDirections[symbol] = editor.direction
        positionInputModes[symbol] = editor.mode.rawValue
        positionLeverages[symbol] = draft.leverage
        switch editor.mode {
        case .margin:
            positionMargins[symbol] = draft.amount
        case .quantity:
            positionQuantities[symbol] = draft.amount
        }

        saveBasePrices()
        savePositionSettings()
        setupMenu()
        refreshStatusTitleFromCache()
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
        refreshStatusTitleFromCache()
    }
}

private final class PositionEditorView: NSView, NSTextFieldDelegate {
    private unowned let app: AppDelegate
    private let symbol: String
    private let directionPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let modePicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let amountField = NSTextField()
    private let amountLabel = NSTextField(labelWithString: "")
    private let leverageField = NSTextField()
    private let preview = NSTextField(labelWithString: "")
    private var amountInputs: [PositionInputMode: String]

    let entryField = NSTextField()
    var onValidityChange: ((Bool) -> Void)?
    private(set) var mode: PositionInputMode

    var direction: String {
        directionPicker.indexOfSelectedItem == 1 ? "short" : "long"
    }

    var draft: (entryPrice: Double, leverage: Double, amount: Double?, size: PositionSize?)? {
        guard let entryPrice = positiveValue(entryField), let leverage = positiveValue(leverageField) else { return nil }
        if amountField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (entryPrice, leverage, nil, nil)
        }

        guard let amount = positiveValue(amountField),
              let size = PositionSize(entryPrice: entryPrice, leverage: leverage, mode: mode, amount: amount) else { return nil }
        return (entryPrice, leverage, amount, size)
    }

    init(app: AppDelegate, symbol: String) {
        self.app = app
        self.symbol = symbol
        mode = app.positionInputMode(for: symbol)
        amountInputs = [
            .margin: app.positionMargins[symbol].map { String($0) } ?? "",
            .quantity: app.positionQuantities[symbol].map { String($0) } ?? "",
        ]
        super.init(frame: .zero)

        entryField.stringValue = app.basePrices[symbol].map { String($0) } ?? ""
        leverageField.stringValue = String(app.positionLeverages[symbol] ?? 1)
        amountField.placeholderString = app.localized("optionalPositionAmount")
        for field in [entryField, leverageField, amountField] {
            field.delegate = self
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 128).isActive = true
        }

        let currentPriceButton = NSButton(title: app.localized("useCurrentPrice"), target: self, action: #selector(useCurrentPrice))
        let entryControls = NSStackView(views: [entryField, currentPriceButton])
        entryControls.orientation = .horizontal
        entryControls.alignment = .centerY
        entryControls.spacing = 8

        directionPicker.addItems(withTitles: [app.localized("longPosition"), app.localized("shortPosition")])
        directionPicker.selectItem(at: app.positionDirections[symbol] == "short" ? 1 : 0)
        modePicker.addItems(withTitles: [app.localized("marginMode"), app.localized("quantityMode")])
        modePicker.selectItem(at: mode == .quantity ? 1 : 0)
        modePicker.target = self
        modePicker.action = #selector(changeInputMode)
        updateAmountField()

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: app.localized("entryPrice")), entryControls],
            [NSTextField(labelWithString: app.localized("positionDirection")), directionPicker],
            [NSTextField(labelWithString: app.localized("inputMode")), modePicker],
            [amountLabel, amountField],
            [NSTextField(labelWithString: app.localized("leverage")), leverageField],
        ])
        grid.rowSpacing = 8
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill

        preview.textColor = .secondaryLabelColor
        preview.lineBreakMode = .byTruncatingTail
        preview.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [grid, preview])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12

        updatePreview()
        frame.size = stack.fittingSize
        stack.frame = bounds
        stack.autoresizingMask = [.width, .height]
        addSubview(stack)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func controlTextDidChange(_ notification: Notification) {
        updatePreview()
    }

    @objc private func useCurrentPrice() {
        guard !app.watchlistRefreshFailed, let price = app.latestPrices[symbol] else {
            preview.stringValue = app.localized("currentPriceUnavailable")
            return
        }

        entryField.stringValue = String(price)
        updatePreview()
    }

    @objc private func changeInputMode() {
        amountInputs[mode] = amountField.stringValue
        mode = modePicker.indexOfSelectedItem == 1 ? .quantity : .margin
        updateAmountField()
        updatePreview()
    }

    private func updateAmountField() {
        amountLabel.stringValue = mode == .quantity
            ? "\(app.localized("quantity")) (\(app.coinName(for: symbol)))"
            : "\(app.localized("margin")) (USDT)"
        amountField.stringValue = amountInputs[mode] ?? ""
    }

    private func updatePreview() {
        if let draft {
            let notional = draft.size.map { app.formatAmount($0.notional, suffix: " USDT") } ?? "—"
            preview.stringValue = "\(app.localized("notional")): \(notional)"
            onValidityChange?(true)
        } else {
            preview.stringValue = app.localized("invalidPositionValues")
            onValidityChange?(false)
        }
    }

    private func positiveValue(_ field: NSTextField) -> Double? {
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(text), value.isFinite, value > 0 else { return nil }
        return value
    }
}

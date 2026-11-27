import Cocoa
import SwiftUI

extension AppDelegate {
    @objc func showSettingsWindow() {
        let window = settingsWindow ?? SettingsWindow(app: self)
        settingsWindow = window
        if window.isMiniaturized { window.deminiaturize(nil) }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

final class SettingsWindow: NSWindow, NSWindowDelegate {
    private let model: SettingsWindowModel

    init(app: AppDelegate) {
        model = SettingsWindowModel(app: app)
        super.init(
            contentRect: NSRect(origin: .zero, size: SettingsView.size),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        appearance = NSAppearance(named: .aqua)
        delegate = self
        contentView = NSHostingView(rootView: SettingsView(model: model))
        refresh()
        center()
    }

    func refresh() {
        title = model.app.localized("preferences")
        model.objectWillChange.send()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard modifiers == .command, let editor = firstResponder as? NSTextView,
              editor.isFieldEditor else { return super.performKeyEquivalent(with: event) }

        switch event.charactersIgnoringModifiers {
        case "a": editor.selectAll(nil)
        case "v": editor.paste(nil)
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        model.app.settingsWindow = nil
    }
}

private final class SettingsWindowModel: ObservableObject {
    enum AccountStatus {
        case testing, saved, failed(String)
    }

    enum UpdateStatus {
        case checking, current, available(ReleaseUpdate), failed
    }

    unowned let app: AppDelegate
    @Published private(set) var accountStatus: AccountStatus?
    @Published private(set) var updateStatus: UpdateStatus?
    @Published private(set) var canCheckForUpdates = true

    var isTestingAccount: Bool {
        if case .testing = accountStatus { return true }
        return false
    }

    init(app: AppDelegate) {
        self.app = app
#if BTCWATCHER_SPARKLE
        app.updaterController?.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)
#endif
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
#if BTCWATCHER_SPARKLE
        if let updater = app.updaterController {
            updater.checkForUpdates(nil)
            return
        }
#endif
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? String(Constants.appVersion.dropFirst())
        let session = URLSession(configuration: app.configureNetwork(.ephemeral))
        canCheckForUpdates = false
        updateStatus = .checking
        Task { @MainActor [weak self] in
            defer {
                session.finishTasksAndInvalidate()
                self?.canCheckForUpdates = true
            }
            do {
                let update = try await ReleaseUpdate.check(currentVersion: currentVersion, session: session)
                self?.updateStatus = update.map(UpdateStatus.available) ?? .current
            } catch {
                self?.updateStatus = .failed
            }
        }
    }

    func testAndSaveAccount(apiKey: String, secretKey: String) {
        accountStatus = .testing
        Task { @MainActor [weak self, app] in
            if let error = await app.testAndSaveBinanceAccount(apiKey: apiKey, secretKey: secretKey) {
                self?.accountStatus = .failed(error)
            } else {
                self?.accountStatus = .saved
            }
        }
    }
}

private struct SettingsView: View {
    static let size = CGSize(width: 520, height: 332)

    private enum Tab: String, CaseIterable {
        case general = "settingsGeneral"
        case menuBar = "settingsMenuBar"
        case network = "settingsNetwork"
        case account = "settingsAccount"
        case help = "help"
    }

    @ObservedObject var model: SettingsWindowModel
    @State private var tab: Tab = .general
    @State private var proxyHost: String
    @State private var proxyPort: String
    @State private var invalidProxyAddress = false
    @State private var apiKey = ""
    @State private var secretKey = ""

    private var app: AppDelegate { model.app }
    private let accent = Color(red: 1, green: 0.63, blue: 0.08)
    private let ink = Color(red: 0.21, green: 0.23, blue: 0.25)
    private let muted = Color(red: 0.36, green: 0.40, blue: 0.43)
    private let line = Color(red: 0.90, green: 0.91, blue: 0.92)

    init(model: SettingsWindowModel) {
        self.model = model
        _proxyHost = State(initialValue: model.app.proxyHost)
        _proxyPort = State(initialValue: model.app.proxyPort)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                ForEach(Tab.allCases, id: \.self) { item in
                    Button {
                        tab = item
                    } label: {
                        Text(label(item.rawValue))
                            .font(.system(size: 14, weight: tab == item ? .semibold : .medium))
                            .foregroundStyle(tab == item ? ink : muted)
                            .padding(.horizontal, 4)
                            .frame(height: 43)
                            .contentShape(Rectangle())
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(tab == item ? accent : .clear).frame(height: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Color(red: 0.98, green: 0.98, blue: 0.98))

            line.frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    switch tab {
                    case .general: generalSettings
                    case .menuBar: menuBarSettings
                    case .network: networkSettings
                    case .account: accountSettings
                    case .help: helpSettings
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.white)
        .foregroundStyle(ink)
        .tint(.blue)
    }

    private var generalSettings: some View {
        VStack(spacing: 0) {
            row("settingsLanguage", inline: true) {
                Picker(selection: binding({ app.isEnglish }, set: { _ in app.toggleLanguage() })) {
                    Text("简体中文").tag(false)
                    Text("English").tag(true)
                } label: { Text(label("settingsLanguage")) }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
            }
            row("tradingMode", inline: true) {
                Picker(selection: binding({ app.isFuturesMode }, set: { app.setTradingMode(isFutures: $0) })) {
                    Text(label("spotMode")).tag(false)
                    Text(label("futuresMode")).tag(true)
                } label: { Text(label("tradingMode")) }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
            }
            row("updateInterval", inline: true) {
                Picker(selection: binding({ Int(app.timer?.timeInterval ?? 2) }, set: { app.setUpdateInterval(Double($0)) })) {
                    ForEach([1, 2, 5], id: \.self) { seconds in
                        Text("\(seconds)s").tag(seconds)
                    }
                } label: { Text(label("updateInterval")) }
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
                .labelsHidden()
            }
        }
    }

    private var menuBarSettings: some View {
        VStack(spacing: 0) {
            toggle("showPrice", isOn: binding({ app.showMenuBarPrice }, set: { _ in app.toggleMenuBarPrice() }))
            row("showPriceTrend") {
                Picker(selection: binding({ app.priceTrendPeriod }, set: { app.selectPriceTrendPeriod($0) })) {
                    ForEach(PriceTrendPeriod.allCases, id: \.self) { period in
                        Text(trendLabel(period)).tag(period)
                    }
                } label: { Text(label("showPriceTrend")) }
                .labelsHidden()
                .frame(width: 128)
            }
            toggle("showChange", isOn: binding({ app.showMenuBarChange }, set: { _ in app.toggleMenuBarChange() }))
            toggle("showPnl", isOn: binding({ app.showMenuBarPnl }, set: { _ in app.toggleMenuBarPnl() }))
            toggle("showRoi", isOn: binding({ app.showMenuBarRoi }, set: { _ in app.toggleMenuBarRoi() }))
        }
    }

    private var networkSettings: some View {
        VStack(spacing: 0) {
            row("apiEndpoint") {
                Picker(selection: binding({ app.isAutoSwitchApi ? -1 : app.currentApiIndex }, set: { index in
                    if index == -1 { app.toggleAutoSwitch() } else { app.switchApi(index) }
                })) {
                    Text(label("autoSwitch")).tag(-1)
                    ForEach(app.apiEndpoints.indices, id: \.self) { index in
                        Text("\(label("api")) \(index + 1)").tag(index)
                    }
                } label: { Text(label("apiEndpoint")) }
                .labelsHidden()
                .frame(width: 128)
            }
            toggle("enableProxy", isOn: binding({ app.isProxyEnabled }, set: { _ in app.toggleProxy() }))
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    field(label("proxyHost")) {
                        TextField(label("proxyHost"), text: $proxyHost)
                    }
                    field(label("proxyPort")) {
                        TextField(label("proxyPort"), text: $proxyPort)
                    }
                    .frame(width: 128)
                }
                HStack {
                    if invalidProxyAddress {
                        Text(label("proxyInvalidAddress")).foregroundStyle(.red)
                    }
                    Spacer()
                    Button(label("savePosition"), action: saveProxyAddress)
                        .disabled(proxyHost == app.proxyHost && proxyPort == app.proxyPort)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }

    private var accountSettings: some View {
        VStack(spacing: 0) {
            toggle("binanceSyncPositions", isOn: binding({ app.isBinancePositionSyncEnabled }, set: { _ in app.toggleBinancePositionSync() }))
            VStack(alignment: .leading, spacing: 10) {
                Text(label("binanceAccount"))
                    .font(.system(size: 13, weight: .medium))
                Text(label("binanceAccountInstructions"))
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    field("API Key") { SecureField("API Key", text: $apiKey) }
                    field("Secret Key") { SecureField("Secret Key", text: $secretKey) }
                }
                .disabled(model.isTestingAccount)
                HStack {
                    accountStatus
                    Spacer()
                    Button(label("binanceTestAndSave")) {
                        model.testAndSaveAccount(apiKey: apiKey, secretKey: secretKey)
                        apiKey = ""
                        secretKey = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isTestingAccount || apiKey.isEmpty || secretKey.isEmpty)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }

    private var helpSettings: some View {
        VStack(spacing: 0) {
            row("version") {
                Text(Constants.appVersion).foregroundStyle(muted)
            }
            HStack(spacing: 12) {
                Button(label("checkForUpdates"), action: model.checkForUpdates)
                    .disabled(!model.canCheckForUpdates)
                Button(label("about"), action: app.showAbout)
                Button(label("feedback"), action: app.openFeedback)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            HStack(spacing: 8) {
                updateStatus
                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch model.updateStatus {
        case .checking:
            ProgressView().controlSize(.small)
            Text(label("updateChecking")).foregroundStyle(muted)
        case .current:
            Text(label("updateCurrent")).foregroundStyle(muted)
        case .available(let release):
            Text(String(format: label("updateAvailable"), release.version))
            Link(label("updateDownload"), destination: release.pageURL)
        case .failed:
            Text(label("updateCheckFailed")).foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }

    @ViewBuilder
    private var accountStatus: some View {
        switch model.accountStatus {
        case .testing:
            ProgressView().controlSize(.small)
            Text(label("binanceTesting")).foregroundStyle(muted)
        case .saved:
            Text(label("binanceAccountSaved")).foregroundStyle(.green)
        case .failed(let message):
            Text(message).foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }

    private func row<Control: View>(_ key: String, inline: Bool = false, @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label(key))
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: inline ? 144 : nil, alignment: .leading)
                if !inline { Spacer(minLength: 20) }
                control()
                if inline { Spacer(minLength: 0) }
            }
            .padding(.horizontal, 24)
            .frame(minHeight: inline ? 72 : 56)
            line.frame(height: 1)
        }
    }

    private func toggle(_ key: String, isOn: Binding<Bool>) -> some View {
        row(key) {
            Toggle(label(key), isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private func field<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .accessibilityHidden(true)
            control().textFieldStyle(.roundedBorder)
        }
    }

    private func binding<Value: Equatable>(_ read: @escaping () -> Value, set write: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: read, set: { value in
            if value != read() { write(value) }
        })
    }

    private func saveProxyAddress() {
        invalidProxyAddress = !app.saveProxyAddress(host: proxyHost, port: proxyPort)
        if !invalidProxyAddress {
            proxyHost = app.proxyHost
            proxyPort = app.proxyPort
        }
    }

    private func trendLabel(_ period: PriceTrendPeriod) -> String {
        switch period {
        case .off: return label("priceTrendOff")
        case .live: return label("priceTrendLive")
        default: return period.rawValue
        }
    }

    private func label(_ key: String) -> String {
        app.localized(key)
    }
}

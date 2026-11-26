import Cocoa
import SwiftUI

extension AppDelegate {
    @objc func showQuotePanel() {
        guard let button = statusItem.button, let window = button.window, let screen = window.screen else { return }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let panel = quotePanel ?? QuotePanel()
        quotePanel = panel
        panel.updateQuote(from: self)
        panel.show(below: anchor, within: screen.visibleFrame)
    }

    func refreshQuotePanel() {
        guard let quotePanel, quotePanel.isVisible else { return }
        quotePanel.updateQuote(from: self)
    }
}

final class QuotePanel: NSPanel {
    private let hostingView = QuotePanelHostingView(rootView: QuotePanelView())

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: QuotePanelView.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        hidesOnDeactivate = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        contentView = hostingView
    }

    override var canBecomeKey: Bool { true }

    func show(below anchor: NSRect, within screenFrame: NSRect) {
        if !isVisible {
            let inset: CGFloat = 8
            let x = min(max(anchor.midX - frame.width / 2, screenFrame.minX + inset), screenFrame.maxX - frame.width - inset)
            let y = min(anchor.minY, screenFrame.maxY) - frame.height - inset
            setFrameOrigin(NSPoint(x: x, y: max(screenFrame.minY + inset, y)))
        }
        makeKeyAndOrderFront(nil)
    }

    func updateQuote(from app: AppDelegate) {
        let price = app.latestPrices[app.currentSymbol]
        let samples = app.priceTrendHistory.samples(for: app.currentSymbol, isFutures: app.isFuturesMode)
        let status: QuotePanelView.Status
        if price == nil {
            status = .unavailable
        } else if app.watchlistRefreshFailed {
            status = .stale
        } else {
            status = .live
        }

        hostingView.rootView = QuotePanelView(
            isEnglish: app.isEnglish,
            pair: app.currentSymbol,
            icon: app.currentIcon,
            isFutures: app.isFuturesMode,
            price: price.map(app.formatPrice),
            samples: samples,
            status: status,
            onClose: { [weak self] in self?.orderOut(nil) }
        )
        title = app.localized("quotePanel")
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }
}

private final class QuotePanelHostingView: NSHostingView<QuotePanelView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

private struct QuotePanelDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

struct QuotePanelView: View {
    enum Status: String {
        case live = "quotePanelLive"
        case stale = "staleQuote"
        case unavailable = "quotePanelUnavailable"
    }

    static let size = CGSize(width: 336, height: 278)

    var isEnglish = true
    var pair = ""
    var icon = ""
    var isFutures = false
    var price: String?
    var samples: [PriceTrendHistory.Sample] = []
    var status: Status = .unavailable
    var onClose: () -> Void = {}

    private let ink = Color(red: 0.21, green: 0.23, blue: 0.25)
    private let muted = Color(red: 0.36, green: 0.40, blue: 0.43)
    private let rule = Color(red: 0.91, green: 0.92, blue: 0.93)
    private let accent = Color(red: 1, green: 0.63, blue: 0.08)
    private let blue = Color(red: 0.08, green: 0.48, blue: 0.94)
    private let mint = Color(red: 0.03, green: 0.68, blue: 0.48)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    Text(label("quotePanel"))
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxHeight: .infinity)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(accent).frame(height: 2).accessibilityHidden(true)
                        }
                    Spacer(minLength: 0)
                }
                .overlay {
                    QuotePanelDragArea()
                        .accessibilityHidden(true)
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(muted)
                        .frame(width: 28, height: 28)
                        .background(rule.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain)
                .help(label("quotePanelClose"))
                .accessibilityLabel(Text(label("quotePanelClose")))
            }
            .padding(.horizontal, 18)
            .frame(height: 43)

            rule.frame(height: 1).accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(icon)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.45)
                        .padding(.horizontal, 3)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(Color(red: 0.57, green: 0.33, blue: 0.02))
                        .background(accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityHidden(true)
                    Text(pair)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(label(isFutures ? "futuresMode" : "spotMode"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(muted)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(price ?? "—")
                        .font(.system(size: 35, weight: .medium, design: .monospaced))
                        .tracking(-1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("USDT")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(muted)
                }
                .accessibilityElement(children: .combine)
                .padding(.top, 8)

                chart
                    .frame(height: 65)
                    .padding(.top, 9)
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity)

            rule.frame(height: 1).accessibilityHidden(true)

            HStack {
                Text(label("quotePanelPeriod"))
                Spacer()
                HStack(spacing: 5) {
                    Circle()
                        .fill(status == .live ? mint : muted)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(label(status.rawValue))
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(muted)
            .padding(.horizontal, 18)
            .frame(height: 37)
            .background(Color(red: 0.96, green: 0.97, blue: 0.97))
        }
        .foregroundStyle(ink)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(.black.opacity(0.11), lineWidth: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onExitCommand(perform: onClose)
    }

    @ViewBuilder
    private var chart: some View {
        if let first = samples.first, let last = samples.last, last.time > first.time,
           let low = samples.map(\.price).min(), let high = samples.map(\.price).max() {
            Canvas { context, size in
                let plot = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 3)
                let duration = first.time.duration(to: last.time) / .seconds(1)
                let spread = high - low
                let points = samples.map { sample in
                    let elapsed = first.time.duration(to: sample.time) / .seconds(1)
                    let fraction = spread > 0 ? (high - sample.price) / spread : 0.5
                    return CGPoint(x: plot.minX + plot.width * elapsed / duration, y: plot.minY + (plot.height - 8) * fraction)
                }
                let line = Path { path in path.addLines(points) }
                var area = line
                area.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                area.addLine(to: CGPoint(x: plot.minX, y: plot.maxY))
                area.closeSubpath()
                context.fill(area, with: .linearGradient(
                    Gradient(colors: [blue.opacity(0.22), mint.opacity(0.09)]),
                    startPoint: CGPoint(x: 0, y: plot.minY),
                    endPoint: CGPoint(x: 0, y: plot.maxY)
                ))
                context.stroke(line, with: .color(blue), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label("priceTrendDescription")))
        } else {
            RoundedRectangle(cornerRadius: 7)
                .fill(rule.opacity(0.4))
                .overlay {
                    if price != nil {
                        Text(label("quotePanelCollecting"))
                            .font(.system(size: 11))
                            .foregroundStyle(muted)
                    }
                }
        }
    }

    private func label(_ key: String) -> String {
        Constants.localized(key, isEnglish: isEnglish)
    }
}

// The bug report / idea form a Settings screen opens; sends through FeedbackSender or falls back to email (D-126).

import SwiftUI
import CoreKitServices

/// Every word on the form, supplied by the game in its own languages.
public struct FeedbackFormText: Sendable {
    public var title: String
    public var subtitle: String
    public var bug: String
    public var idea: String
    public var placeholder: String
    /// Says what goes along with the message (version, device model) and that nothing else does.
    public var disclosure: String
    public var send: String
    public var sent: String
    public var failed: String
    public var tooShort: String
    public var tooLong: String
    /// Takes the seconds to wait, e.g. "Sent a moment ago — try again in %lld s".
    public var tooSoon: String
    public var close: String
    /// Shown instead of Send when the game has no relay configured.
    public var emailInstead: String

    public init(title: String, subtitle: String, bug: String, idea: String, placeholder: String, disclosure: String,
                send: String, sent: String, failed: String, tooShort: String, tooLong: String, tooSoon: String,
                close: String, emailInstead: String) {
        self.title = title
        self.subtitle = subtitle
        self.bug = bug
        self.idea = idea
        self.placeholder = placeholder
        self.disclosure = disclosure
        self.send = send
        self.sent = sent
        self.failed = failed
        self.tooShort = tooShort
        self.tooLong = tooLong
        self.tooSoon = tooSoon
        self.close = close
        self.emailInstead = emailInstead
    }

    /// The line for a refusal, or nil.
    public func message(for error: FeedbackError) -> String {
        switch error {
        case .tooShort: tooShort
        case .tooLong: tooLong
        case .tooSoon(let seconds): String(format: tooSoon, seconds)
        case .failed: failed
        }
    }
}

public struct FeedbackForm: View {
    @Environment(\.gameTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    private let text: FeedbackFormText
    private let sender: FeedbackSender?
    private let context: String
    private let email: String
    private let onClose: () -> Void

    @State private var kind: FeedbackReport.Kind = .bug
    @State private var message = ""
    @State private var sending = false
    @State private var sent = false
    @State private var notice: String?
    @FocusState private var focused: Bool

    /// `sender` nil means no relay: the button opens a prefilled email to `email` instead.
    public init(text: FeedbackFormText, sender: FeedbackSender?, context: String, email: String, onClose: @escaping () -> Void) {
        self.text = text
        self.sender = sender
        self.context = context
        self.email = email
        self.onClose = onClose
    }

    public var body: some View {
        let ink = theme.palette.onSurface.resolved(for: colorScheme)
        let primary = theme.palette.primary.resolved(for: colorScheme)
        let surface = theme.palette.surface.resolved(for: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(text.title).font(theme.typography.title).foregroundStyle(ink)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(ink)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(ink.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(text.close)
                }
                Text(text.subtitle).font(.system(size: 15)).foregroundStyle(ink.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                if sent {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(primary)
                        Text(text.sent).font(.system(size: 17, weight: .semibold)).foregroundStyle(ink).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    HStack(spacing: 8) {
                        chip(.bug, text.bug, ink: ink, primary: primary)
                        chip(.idea, text.idea, ink: ink, primary: primary)
                    }
                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text(text.placeholder).font(.system(size: 16)).foregroundStyle(ink.opacity(0.4))
                                .padding(.horizontal, 5).padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $message)
                            .focused($focused)
                            .font(.system(size: 16)).foregroundStyle(ink)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 18).fill(surface)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(focused ? primary.opacity(0.6) : ink.opacity(0.1), lineWidth: 1)))
                    HStack {
                        Text(text.disclosure).font(.system(size: 12)).foregroundStyle(ink.opacity(0.5))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text("\(message.count)/\(FeedbackSender.maximumLength)").font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(message.count > FeedbackSender.maximumLength ? Color.red : ink.opacity(0.4))
                    }
                    if let notice {
                        Text(notice).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(red: 1, green: 0.42, blue: 0.3))
                    }
                    Button(action: submit) {
                        HStack(spacing: 8) {
                            if sending { ProgressView().tint(theme.palette.background.resolved(for: colorScheme)) }
                            Text(sender == nil ? text.emailInstead : text.send).font(.system(size: 18, weight: .heavy))
                        }
                        .foregroundStyle(theme.palette.background.resolved(for: colorScheme))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(RoundedRectangle(cornerRadius: 18).fill(primary))
                    }
                    .buttonStyle(.plain)
                    .disabled(sending)
                    .opacity(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
            .padding(20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(theme.palette.background.resolved(for: colorScheme).ignoresSafeArea())
        .onAppear { focused = true }
    }

    private func chip(_ value: FeedbackReport.Kind, _ label: String, ink: Color, primary: Color) -> some View {
        let on = kind == value
        return Button { kind = value } label: {
            Text(label).font(.system(size: 15, weight: .bold))
                .foregroundStyle(on ? theme.palette.background.resolved(for: colorScheme) : ink.opacity(0.8))
                .padding(.horizontal, 18).frame(minHeight: 40)
                .background(Capsule().fill(on ? primary : ink.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func submit() {
        let report = FeedbackReport.current(kind: kind, message: message, context: context)
        guard let sender else {
            if let url = FeedbackForm.mailURL(to: email, report: report) { openURL(url) }
            return
        }
        if let problem = sender.problem(with: message) {
            notice = text.message(for: problem)
            return
        }
        notice = nil
        sending = true
        Task {
            do {
                try await sender.send(report)
                sent = true
            } catch let error as FeedbackError {
                notice = text.message(for: error)
            } catch {
                notice = text.failed
            }
            sending = false
        }
    }

    /// A prefilled email with the same fields the relay would get.
    static func mailURL(to email: String, report: FeedbackReport) -> URL? {
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = email
        let body = "\(report.message)\n\n— \(report.kind.rawValue) · \(report.appVersion) (\(report.build)) · iOS \(report.osVersion) · \(report.device)"
            + (report.context.isEmpty ? "" : " · \(report.context)")
        parts.queryItems = [URLQueryItem(name: "subject", value: report.kind == .bug ? "Bug report" : "Idea"),
                            URLQueryItem(name: "body", value: body)]
        return parts.url
    }
}

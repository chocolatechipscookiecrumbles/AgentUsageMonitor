import SwiftUI

struct QuotaMenuView: View {
    @ObservedObject var viewModel: QuotaViewModel

    var body: some View {
        Group {
            if let plan = viewModel.presentation.planType {
                Text("Codex plan: \(plan.capitalized)")
            } else {
                Text("Codex quota unavailable")
            }
            if let credits = viewModel.presentation.creditBalance {
                Text("Credits: \(credits)")
            }
            if let count = viewModel.presentation.availableResetCredits {
                Text("Available reset credits: \(count)")
            }
            ForEach(viewModel.presentation.resetCreditExpiryDates, id: \.self) { expiry in
                Text("Reset credit expires: \(expiry.formatted(date: .abbreviated, time: .shortened))")
            }
            Divider()
            QuotaWindowRow(title: "5-hour limit", window: viewModel.presentation.fiveHour)
            QuotaWindowRow(title: "Weekly limit", window: viewModel.presentation.weekly)
            Divider()
            Text("Verification: \(viewModel.presentation.confirmation.displayName)")
                .foregroundStyle(statusColor)
            if let detail = viewModel.presentation.detail { Text(detail).font(.caption) }
            Text("Last refresh: \(viewModel.presentation.collectedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
            Toggle("Quota alerts", isOn: Binding(
                get: { viewModel.alertsEnabled },
                set: { viewModel.setAlertsEnabled($0) }
            ))
            Button(viewModel.isRefreshing ? "Refreshing…" : "Refresh now") { viewModel.refresh() }
                .disabled(viewModel.isRefreshing)
            Divider()
            Button("Quit Codex Usage Monitor") { NSApplication.shared.terminate(nil) }
        }
        .padding(10)
        .frame(minWidth: 340, alignment: .leading)
        .onAppear { viewModel.start() }
    }

    private var statusColor: Color {
        switch viewModel.presentation.confirmation {
        case .confirmed, .confirmedAfterRetry: .primary
        case .cachedLastKnownGood, .unconfirmed: .orange
        case .unavailable: .secondary
        }
    }
}

private struct QuotaWindowRow: View {
    let title: String
    let window: QuotaWindow?

    var body: some View {
        if let window {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title): \(window.usedPercent)% used · \(window.remainingPercent)% remaining")
                if let resetAt = window.resetAt {
                    Text("Resets: \(resetAt.formatted(date: .abbreviated, time: .shortened))").font(.caption)
                }
            }
        } else {
            Text("\(title): unavailable")
        }
    }
}

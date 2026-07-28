import Charts
import SwiftUI

/// The Token activity card: an intraday chart of 30-minute intervals followed
/// by provider-native token rows, Requests, bounded Model Usage, and the last
/// observed request.
///
/// Everything it shows comes from local records on this Mac. It is deliberately
/// independent of quota, so it stays useful while a provider is disconnected,
/// and it never presents these totals as account usage or quota consumption.
struct ProviderTokenActivityCard: View {
    let presentation: ProviderTokenActivityPresentation

    @Environment(\.colorScheme) private var colorScheme
    /// Hover lives entirely in the view. It changes the detail line and the
    /// highlighted bar, never the rows and never the card's height.
    @State private var hoveredBucket: LocalActivityBucket?

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.activitySectionSpacing) {
            header

            switch presentation.content {
            case .compact(let message, let detail):
                compactBody(message: message, detail: detail)
            case .expanded(let expanded):
                expandedBody(expanded)
            }
        }
        .padding(.horizontal, MenuPopoverTheme.cardHorizontalPadding)
        .padding(.vertical, MenuPopoverTheme.cardVerticalPadding)
        .background(theme.cardBackground, in: RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius))
        .shadow(
            color: theme.cardShadow,
            radius: MenuPopoverTheme.cardShadowRadius,
            y: MenuPopoverTheme.cardShadowY
        )
    }

    private var header: some View {
        HStack(spacing: MenuPopoverTheme.activityHeaderSpacing) {
            Image(systemName: "chart.bar")
                .font(.system(size: MenuPopoverTheme.creditIconSize))
                .foregroundStyle(theme.icon)

            VStack(alignment: .leading, spacing: MenuPopoverTheme.activityHeaderTextSpacing) {
                Text(ProviderTokenActivityPresentation.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(theme.primaryText)

                Text(ProviderTokenActivityPresentation.scope)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 0)

            if case .expanded(let expanded) = presentation.content {
                Text(expanded.todayTokens)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
                    .accessibilityLabel("Tokens today")
                    .accessibilityValue(expanded.todayExactTokens)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func compactBody(message: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.activityRowSpacing) {
            Text(message)
                .font(.callout)
                .foregroundStyle(theme.primaryText)

            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func expandedBody(_ expanded: ProviderTokenActivityPresentation.Expanded) -> some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.activitySectionSpacing) {
            chart(expanded)

            Rectangle()
                .fill(theme.divider)
                .frame(height: MenuPopoverTheme.dividerHeight)

            metricColumns(expanded)

            if !expanded.modelUsage.isEmpty {
                Rectangle()
                    .fill(theme.divider)
                    .frame(height: MenuPopoverTheme.dividerHeight)

                VStack(alignment: .leading, spacing: MenuPopoverTheme.activityRowSpacing) {
                    ForEach(expanded.modelUsage) { model in
                        modelRow(model)
                    }
                }
            }

            if let lastRequest = expanded.lastRequest {
                Rectangle()
                    .fill(theme.divider)
                    .frame(height: MenuPopoverTheme.dividerHeight)

                lastRequestRow(lastRequest)
            }
        }
    }

    // MARK: - Chart

    private func chart(_ expanded: ProviderTokenActivityPresentation.Expanded) -> some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.activityChartTopSpacing) {
            // Reserving this line at a fixed height is what lets hover change
            // its text without moving the plot or resizing the popover.
            Text(hoverDetailText(expanded))
                .font(.caption)
                .foregroundStyle(hoveredBucket == nil ? theme.secondaryText : theme.primaryText)
                .lineLimit(1)
                .frame(height: MenuPopoverTheme.activityHoverDetailHeight, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)

            if expanded.hasObservedActivity {
                plot(expanded)
            } else {
                emptyPlot(expanded)
            }
        }
    }

    private func plot(_ expanded: ProviderTokenActivityPresentation.Expanded) -> some View {
        Chart(expanded.buckets) { bucket in
            BarMark(
                x: .value("Interval", bucket.startedAt),
                y: .value("Tokens", bucket.totalTokens)
            )
            .foregroundStyle(barTint(for: bucket))
        }
        .chartLegend(.hidden)
        .chartXScale(domain: expanded.dayStartedAt...expanded.domainEndsAt)
        .chartXAxis {
            AxisMarks(values: axisDates(expanded)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yAxisValues(expanded)) { value in
                AxisValueLabel {
                    if let tokens = value.as(Double.self) {
                        Text(ProviderTokenActivityPresentation.compactTokens(Int64(tokens)))
                            .font(.caption2)
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
        .frame(height: MenuPopoverTheme.activityChartHeight)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredBucket = bucket(at: location, proxy: proxy, geometry: geometry, in: expanded)
                        case .ended:
                            hoveredBucket = nil
                        }
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity chart, 30-minute intervals since midnight")
        .accessibilityValue(expanded.chartAccessibilityValue)
    }

    /// A readable day with no observed tokens keeps the plot's frame rather
    /// than collapsing or inventing bars.
    private func emptyPlot(_ expanded: ProviderTokenActivityPresentation.Expanded) -> some View {
        RoundedRectangle(cornerRadius: MenuPopoverTheme.cardCornerRadius / 2)
            .fill(theme.progressTrack.opacity(0.5))
            .frame(height: MenuPopoverTheme.activityChartHeight)
            .overlay {
                Text(ProviderTokenActivityPresentation.emptyDay)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Activity chart, 30-minute intervals since midnight")
            .accessibilityValue(expanded.chartAccessibilityValue)
    }

    private func hoverDetailText(_ expanded: ProviderTokenActivityPresentation.Expanded) -> String {
        guard expanded.hasObservedActivity else { return " " }
        guard let hoveredBucket else { return ProviderTokenActivityPresentation.hoverResting }
        return ProviderTokenActivityPresentation.hoverDetail(for: hoveredBucket)
    }

    private func barTint(for bucket: LocalActivityBucket) -> Color {
        let accent = presentation.provider.settingsPresentationTint
        guard let hoveredBucket else { return accent }
        return hoveredBucket.id == bucket.id ? accent : accent.opacity(0.45)
    }

    private func bucket(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        in expanded: ProviderTokenActivityPresentation.Expanded
    ) -> LocalActivityBucket? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let origin = geometry[plotFrame].origin
        guard let date: Date = proxy.value(atX: location.x - origin.x) else { return nil }
        return expanded.buckets.last { $0.startedAt <= date }
    }

    /// At most three labels: the day's start, its midpoint, and the end of the
    /// interval in progress. More than that cannot be read at 340 points.
    private func axisDates(_ expanded: ProviderTokenActivityPresentation.Expanded) -> [Date] {
        let start = expanded.dayStartedAt
        let end = expanded.domainEndsAt
        let midpoint = start.addingTimeInterval(end.timeIntervalSince(start) / 2)
        return [start, midpoint, end]
    }

    private func yAxisValues(_ expanded: ProviderTokenActivityPresentation.Expanded) -> [Double] {
        let maximum = expanded.buckets.map(\.totalTokens).max() ?? 0
        guard maximum > 0 else { return [0] }
        let rounded = Double(maximum)
        return [0, rounded / 2, rounded]
    }

    // MARK: - Rows

    /// The four categories and Requests are paired into two columns, which
    /// costs three rows instead of five and puts the popover's spare width to
    /// work. Columns are filled top-down so each provider's input-side and
    /// output-side categories stay together.
    private func metricColumns(_ expanded: ProviderTokenActivityPresentation.Expanded) -> some View {
        let cells = expanded.categories + [expanded.requests]
        let split = (cells.count + 1) / 2

        return HStack(alignment: .top, spacing: MenuPopoverTheme.activityMetricColumnSpacing) {
            metricColumn(Array(cells.prefix(split)))
            metricColumn(Array(cells.dropFirst(split)))
        }
    }

    private func metricColumn(_ rows: [ProviderTokenActivityPresentation.Row]) -> some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.activityRowSpacing) {
            ForEach(rows) { row in
                detailRow(label: row.label, value: row.value, accessibilityValue: row.accessibilityValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailRow(label: String, value: String, accessibilityValue: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.activityMetricLabelSpacing) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(value == "Unavailable" ? theme.neutral : theme.primaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
    }

    private func modelRow(_ model: ProviderTokenActivityPresentation.ModelRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.activityHeaderSpacing) {
            Text(model.shortName)
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(model.value)
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.primaryText)

            Text("\(model.sharePercent)%")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
                .frame(width: MenuPopoverTheme.activityModelShareWidth, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.shortName)
        .accessibilityValue(model.accessibilityValue)
    }

    private func lastRequestRow(_ lastRequest: ProviderTokenActivityPresentation.LastRequest) -> some View {
        VStack(alignment: .leading, spacing: MenuPopoverTheme.activityLastRequestSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: MenuPopoverTheme.activityHeaderSpacing) {
                Text("Last Request")
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)

                Spacer(minLength: 0)

                Text(lastRequest.totalAndTime)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.primaryText)
            }

            Text(lastRequest.shortModelName)
                .font(.caption2)
                .foregroundStyle(theme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Last Request")
        .accessibilityValue(lastRequest.accessibilityValue)
    }

    private var theme: MenuPopoverTheme {
        MenuPopoverTheme.resolve(for: colorScheme)
    }
}

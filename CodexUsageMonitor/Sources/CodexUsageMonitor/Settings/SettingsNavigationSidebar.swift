import SwiftUI

struct SettingsNavigationSidebar: View {
    @Binding var selection: SettingsTab
    @State private var searchText = ""
    @Environment(\.settingsAppearancePalette) private var palette

    private var filteredTabs: [SettingsTab] {
        guard !searchText.isEmpty else { return SettingsTab.allCases }
        return SettingsTab.allCases.filter { $0.title.localizedStandardContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(palette.searchFieldBackground, in: .rect(cornerRadius: 7))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(filteredTabs) { tab in
                        Button {
                            SettingsDestinationSelection.select(tab, using: $selection)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: tab.systemImage)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .background(tab.navigationTint.opacity(selection == tab ? 1 : 0.65), in: .rect(cornerRadius: 6))

                                Text(tab.title)
                                    .font(.system(size: 13, weight: .medium))

                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(selection == tab ? .primary : .secondary)
                            .padding(.horizontal, 10)
                            .frame(height: 38)
                            .contentShape(.rect)
                            .background(selection == tab ? palette.sidebarSelection : .clear, in: .rect(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selection == tab ? .isSelected : [])
                    }

                    if filteredTabs.isEmpty {
                        Text("No settings found")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(width: SettingsLayoutMetrics.sidebarWidth)
        .background(palette.sidebarBackground)
    }
}

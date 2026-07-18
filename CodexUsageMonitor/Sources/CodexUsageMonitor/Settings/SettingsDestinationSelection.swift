import SwiftUI

@MainActor
enum SettingsDestinationSelection {
    static func select(_ destination: SettingsTab, using selection: Binding<SettingsTab>) {
        perform { selection.wrappedValue = destination }
    }

    static func select(_ destination: SettingsTab, in settings: AppSettings) {
        perform { settings.selectedSettingsTab = destination }
    }

    private static func perform(_ update: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, update)
    }
}

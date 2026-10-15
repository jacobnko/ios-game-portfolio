// A settings row saying whether progress syncs through iCloud, with a hint when it does not.

import SwiftUI

public struct ICloudStatusRow: View {
    private let status: ICloudStatus
    private let showsDivider: Bool

    public init(status: ICloudStatus, showsDivider: Bool = false) {
        self.status = status
        self.showsDivider = showsDivider
    }

    public var body: some View {
        SettingsRow(CommonStrings.settingsICloudSync.text, systemImage: "icloud", detail: hint, showsDivider: showsDivider) {
            StatusPill(status.isSyncing ? CommonStrings.settingsOn.text : CommonStrings.settingsOff.text,
                       isPositive: status.isSyncing)
        }
    }

    private var hint: String? {
        switch status {
        case .on: nil
        case .off: CommonStrings.settingsICloudOffHint.text
        case .restricted: CommonStrings.settingsICloudRestricted.text
        case .unavailable: CommonStrings.settingsICloudUnavailable.text
        }
    }
}

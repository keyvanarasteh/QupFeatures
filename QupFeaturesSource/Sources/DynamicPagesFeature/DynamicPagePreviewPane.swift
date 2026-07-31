import DesignSystem
import DynamicUI
import SwiftUI

/// Live SDUI preview with optional forced content-width chips.
public struct DynamicPagePreviewPane: View {
    public enum WidthPreset: String, CaseIterable, Identifiable, Sendable {
        case auto
        case phone
        case tablet
        case desktop

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .auto: "Auto"
            case .phone: "Phone"
            case .tablet: "Tablet"
            case .desktop: "Desktop"
            }
        }

        /// Forced content width for classifier testing; nil = container.
        public var forcedWidth: CGFloat? {
            switch self {
            case .auto: nil
            case .phone: 390
            case .tablet: 900
            case .desktop: 1280
            }
        }
    }

    let bodyJSON: String
    @Binding var widthPreset: WidthPreset

    @Environment(\.cupertinoColors) private var colors

    public init(bodyJSON: String, widthPreset: Binding<WidthPreset> = .constant(.auto)) {
        self.bodyJSON = bodyJSON
        self._widthPreset = widthPreset
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Label("Live preview", systemImage: "eye")
                    .font(Theme.Typography.subheadline.weight(.semibold))
                Spacer()
                Picker("Width", selection: $widthPreset) {
                    ForEach(WidthPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

            if let message = DynamicPageBodyCodec.validationMessage(for: bodyJSON) {
                EmptyStateView(
                    title: "Invalid document",
                    message: message,
                    systemImage: "exclamationmark.triangle"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    DynamicHostView(
                        json: bodyJSON,
                        forcedWidth: widthPreset.forcedWidth,
                        embedStyle: .page,
                        installExtensions: DynamicPagesDynamicUI.installExtensions
                    )
                    .frame(
                        maxWidth: widthPreset.forcedWidth ?? .infinity,
                        alignment: .topLeading
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .background(colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.md))
            }
        }
    }
}

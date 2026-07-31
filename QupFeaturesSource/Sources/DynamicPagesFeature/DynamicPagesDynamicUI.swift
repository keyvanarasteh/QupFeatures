import DynamicUI
import DynamicUIComponents
import DynamicUIHPC
import DynamicUILayout

/// Cupertino-standard DynamicUI install list for page management previews
/// (matches MenuFeature: Layout → EQ → HPC).
@MainActor
public enum DynamicPagesDynamicUI {
    public static let installExtensions: [DynamicNodeExtensionInstall] = [
        DynamicUILayout.install,
        DynamicUIComponents.install,
        DynamicUIHPC.install,
    ]
}

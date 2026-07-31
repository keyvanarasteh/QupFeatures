import DesignSystem
import SwiftUI
import WebKit

// MARK: - Lab view

/// 3D digital-twin viewer for the Ar-Ge grow lab, rendered from the bundled
/// standalone Three.js scenes maintained at `ar-ge/labratovar/lab-pro*.html`.
/// Both builds are static, resource-only HTML (three.js itself still loads
/// from unpkg over the network) — the picker lets either platform preview
/// the other's build.
public struct MantarlifeLabView: View {
    @Environment(\.cupertinoColors) private var colors
    @State private var build: MantarlifeLabBuild

    public init() {
        #if os(iOS)
        _build = State(initialValue: .mobile)
        #else
        _build = State(initialValue: .pro)
        #endif
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker("Sürüm", selection: $build) {
                ForEach(MantarlifeLabBuild.allCases) { build in
                    Text(build.title).tag(build)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)

            Rectangle()
                .fill(colors.border)
                .frame(height: 1)

            ZStack {
                colors.bg
                if let url = build.resourceURL {
                    MantarlifeLabWebView(url: url)
                } else {
                    ContentUnavailableView(
                        "Sahne bulunamadı",
                        systemImage: "exclamationmark.triangle",
                        description: Text("\(build.fileName).html paket kaynaklarında yok.")
                    )
                }
            }
        }
        .background(colors.bg)
        .navigationTitle("Ar-Ge Lab · 3D")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .bottom)
        #endif
    }
}

enum MantarlifeLabBuild: String, CaseIterable, Identifiable {
    case pro
    case mobile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pro: "Masaüstü"
        case .mobile: "Mobil"
        }
    }

    var fileName: String {
        switch self {
        case .pro: "lab-pro"
        case .mobile: "lab-pro-mobile"
        }
    }

    var resourceURL: URL? {
        Bundle.module.url(forResource: fileName, withExtension: "html")
    }
}

// MARK: - WebKit bridge

#if os(macOS)
private struct MantarlifeLabWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        makeMantarlifeLabPlatformWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url, into: webView)
    }

    func makeCoordinator() -> MantarlifeLabWebViewCoordinator {
        MantarlifeLabWebViewCoordinator()
    }
}
#else
private struct MantarlifeLabWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        makeMantarlifeLabPlatformWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(url, into: webView)
    }

    func makeCoordinator() -> MantarlifeLabWebViewCoordinator {
        MantarlifeLabWebViewCoordinator()
    }
}
#endif

@MainActor
private func makeMantarlifeLabPlatformWebView() -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = true

    let webView = WKWebView(frame: .zero, configuration: configuration)
    #if os(macOS)
    webView.setValue(false, forKey: "drawsBackground")
    #else
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    #endif
    return webView
}

@MainActor
private final class MantarlifeLabWebViewCoordinator {
    private var lastURL: URL?

    func load(_ url: URL, into webView: WKWebView) {
        guard url != lastURL else { return }
        lastURL = url
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

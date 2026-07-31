import FoundationModelsKit
import SwiftUI

// MARK: - q-hpc-panel inspired AI v2 style palette
enum AIV2Style {
    static let accentIndigo = Color(red: 99/255, green: 102/255, blue: 241/255)
    static let accentBlue = Color(red: 59/255, green: 130/255, blue: 246/255)
    static let accentEmerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let accentViolet = Color(red: 139/255, green: 92/255, blue: 246/255)
    static let accentAmber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let accentSky = Color(red: 14/255, green: 165/255, blue: 233/255)
    static let accentPink = Color(red: 236/255, green: 72/255, blue: 153/255)
    static let accentOrange = Color(red: 249/255, green: 115/255, blue: 22/255)
}

// MARK: - Stat card (tiny uppercase label + bold number)
struct AIStatCard: View {
    let label: String
    let value: String
    var foreground: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(foreground)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Stat strip (horizontal scrollable row of stat cards)
struct AIStatsRow: View {
    let values: [(String, String, Color?)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, item in
                    AIStatCard(label: item.0, value: item.1, foreground: item.2 ?? .primary)
                        .frame(minWidth: 110)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Provider chip (toggle button styled like q-hpc-panel chips)
struct AIChipToggle: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let accent: Color
    var isCredentialed: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 12, weight: isCredentialed ? .semibold : .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                if isSelected {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? accent.opacity(0.1) : (isCredentialed ? accent.opacity(0.06) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(
                                isSelected ? accent.opacity(0.5) : (isCredentialed ? accent.opacity(0.4) : Color.gray.opacity(0.3)),
                                lineWidth: isSelected || isCredentialed ? 1.25 : 1
                            )
                    )
            )
            .foregroundStyle(isSelected ? accent : (isCredentialed ? accent.opacity(0.9) : .secondary))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section header with uppercase label
struct AISectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .medium))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Badge pill
struct AIBadge: View {
    let text: String
    var good: Bool = true
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .black))
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(good ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
            )
            .foregroundStyle(good ? Color.green : .secondary)
    }
}

// MARK: - Status dot indicator
struct AIStatusDot: View {
    let active: Bool
    var body: some View {
        Circle()
            .fill(active ? Color.green : Color.red.opacity(0.6))
            .frame(width: 8, height: 8)
    }
}

// MARK: - Resource error banner (styled like q-hpc-panel)
struct AIErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(message)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
            Button("Retry", action: retry)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.red.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.red.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundStyle(.red)
        .padding(.horizontal)
    }
}

// MARK: - Apple on-device availability banner
struct AIOnDeviceAvailabilityBanner: View {
    let availability: FoundationModelsAvailability

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: availability.isAvailable ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10))
            Text(availability.message)
                .font(.system(size: 12))
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((availability.isAvailable ? Color.green : Color.orange).opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke((availability.isAvailable ? Color.green : Color.orange).opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundStyle(availability.isAvailable ? .green : .orange)
    }
}

// MARK: - Loading shimmer placeholder
struct AILoadingPlaceholder: View {
    var count: Int = 4
    var height: CGFloat = 36
    var body: some View {
        VStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary.opacity(0.5))
                    .frame(height: height)
                    .shimmering()
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Empty state styled as a card
struct AIEmptyCard: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal)
    }
}

// MARK: - Modal overlay backdrop (q-hpc-panel style)
struct AIModalOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder let content: Content
    var body: some View {
        if isPresented {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .transition(.opacity)
                .onTapGesture { isPresented = false }
                .overlay(
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                )
                .zIndex(100)
                .transition(.opacity.animation(.easeOut(duration: 0.15)))
        }
    }
}

// MARK: - Modal card (the actual modal content wrapper)
struct AIModalCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.background)
                .shadow(color: .black.opacity(0.15), radius: 20, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }
}

// MARK: - Inline form card (slide-down effect)
struct AIFormCard<Content: View>: View {
    @Binding var isPresented: Bool
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        if isPresented {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                content
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring(response: 0.25), value: isPresented)
        }
    }
}

// MARK: - Key-value row for modals
struct AIKVRow: View {
    let label: String
    let value: String
    var mono: Bool = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            Spacer()
            Text(value)
                .font(.system(size: 12, design: mono ? .monospaced : .default))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct AIKVBoolRow: View {
    let label: String
    let value: Bool?
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            if let value {
                Text(value ? "Yes" : "No")
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(value ? Color.green.opacity(0.1) : Color.gray.opacity(0.15))
                    )
                    .foregroundStyle(value ? Color.green : .secondary)
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

struct AIKVChipsRow: View {
    let label: String
    let values: [String]?
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(minWidth: 80, alignment: .leading)
            Spacer()
            if let values, !values.isEmpty {
                HStack(spacing: 4) {
                    ForEach(values, id: \.self) { v in
                        Text(v)
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.quaternary.opacity(0.3))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Simple shimmer modifier
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: .clear, location: phase - 0.3),
                            .init(color: .white.opacity(0.15), location: phase),
                            .init(color: .clear, location: phase + 0.3),
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: geo.size.width * phase)
                    .animation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false), value: phase)
                }
            )
            .clipped()
            .onAppear { phase = 1.5 }
    }
}

extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

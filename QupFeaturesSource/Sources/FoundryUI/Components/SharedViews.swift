import DesignSystem
import SwiftUI

// MARK: - Toast

enum Toast: Equatable {
    case success(String)
    case error(String)

    var text: String {
        switch self { case .success(let t), .error(let t): t }
    }

    var isError: Bool {
        if case .error = self { true } else { false }
    }
}

extension View {
    func toastView(_ toast: Toast) -> some View {
        HStack {
            Image(systemName: toast.isError ? "xmark.circle" : "checkmark.circle")
            Text(toast.text).font(Theme.Typography.caption)
        }
        .foregroundStyle(toast.isError ? Color.red : Color.green)
        .padding(Theme.Spacing.sm)
        .background(toast.isError ? Color.red.opacity(0.08) : Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(toast.isError ? Color.red.opacity(0.2) : Color.green.opacity(0.2)))
    }

    func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(error).font(Theme.Typography.caption)
        }
        .foregroundStyle(Color.red)
        .padding(Theme.Spacing.sm)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm).stroke(Color.red.opacity(0.15)))
    }

    func labelled(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label.uppercased()).font(Theme.Typography.caption2.weight(.semibold)).foregroundStyle(Color.gray)
            content()
        }
    }

    func infoRow(_ label: String, _ value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label).font(Theme.Typography.caption).foregroundStyle(Color.gray)
            Spacer()
            Text(value).font(mono ? Theme.Typography.caption.monospaced() : Theme.Typography.caption).lineLimit(1)
        }
    }
}

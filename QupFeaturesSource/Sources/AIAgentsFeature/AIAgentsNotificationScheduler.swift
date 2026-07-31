import QupCore
import Foundation
import UserNotifications

/// Schedules local reminders for `AgentAccount` usage windows. Abstracted behind
/// a protocol so tests can swap in a no-op implementation — `UNUserNotificationCenter`
/// crashes when driven from a bare SwiftPM test host (no app bundle).
public protocol AIAgentsNotifying: Sendable {
    func isAuthorized() async -> Bool
    @discardableResult func requestAuthorization() async -> Bool
    func reschedule(for account: AgentAccount) async
    func cancelAll(for account: AgentAccount) async
}

/// Real implementation: local-only, no remote push. Every request is built from
/// data the user typed in by hand.
public struct LiveAIAgentsNotifier: AIAgentsNotifying {
    public init() {}

    private func identifierPrefix(for accountID: UUID) -> String {
        "tech.qline.aiagents.\(accountID.uuidString)"
    }

    /// Current notification authorization, without prompting.
    public func isAuthorized() async -> Bool {
        await PermissionRegistry.snapshot(for: .notifications).isGranted
    }

    /// Prompts the system permission dialog. Only call this from an explicit
    /// user action (a button tap), never on load.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        await PermissionRegistry.requestPermission(for: .notifications)
    }

    /// Cancels every pending request for `account`, then re-schedules from its
    /// current limits. Safe to call on every save, including when reminders
    /// are turned off (the cancel-all step still runs).
    public func reschedule(for account: AgentAccount) async {
        await cancelAll(for: account)
        guard await isAuthorized() else { return }

        let center = UNUserNotificationCenter.current()
        for limit in account.limits {
            if account.remindBeforeReset, let resetsAt = limit.resetsAt, resetsAt > .now {
                try? await center.add(resetReminderRequest(account: account, limit: limit, resetsAt: resetsAt))
            }
            if account.alertNearLimit, limit.isNearLimit {
                try? await center.add(nearLimitRequest(account: account, limit: limit))
            }
        }
    }

    public func cancelAll(for account: AgentAccount) async {
        let center = UNUserNotificationCenter.current()
        let prefix = identifierPrefix(for: account.id)
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func resetReminderRequest(account: AgentAccount, limit: UsageLimit, resetsAt: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "\(account.nickname) resets now"
        content.body = "\(account.provider.displayName)'s \(limit.displayLabel.lowercased()) limit resets for \(account.email)."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: resetsAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "\(identifierPrefix(for: account.id)).\(limit.id.uuidString).reset"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func nearLimitRequest(account: AgentAccount, limit: UsageLimit) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "\(account.nickname) is nearing its limit"
        content.body = "\(limit.displayLabel) usage is at \(Int(limit.usedPercent.rounded()))% for \(account.email)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let identifier = "\(identifierPrefix(for: account.id)).\(limit.id.uuidString).nearlimit"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}

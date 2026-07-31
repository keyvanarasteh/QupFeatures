import DesignSystem
import EventKit
import SwiftUI

struct iCloudRemindersView: View {
    @ObservedObject var viewModel: iCloudFeatureViewModel
    @Environment(\.cupertinoColors) private var colors
    @State private var quickReminderTitle = ""
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    SectionHeader("Reminders", subtitle: "Active tasks in your reminders lists", systemImage: "checklist")
                        .padding(.horizontal, Theme.Spacing.lg)
                    
                    if viewModel.remindersAccessGranted {
                        // Quick Add Reminder Card
                        CardView {
                            HStack(spacing: Theme.Spacing.md) {
                                Image(systemName: "plus")
                                    .font(.system(.body, design: .default, weight: .regular))
                                    .foregroundStyle(colors.mutedFg)
                                    .accessibilityHidden(true)
                                TextField("Add a quick task...", text: $quickReminderTitle)
                                    .onSubmit {
                                        guard !quickReminderTitle.isEmpty else { return }
                                        Task {
                                            viewModel.newReminderTitle = quickReminderTitle
                                            await viewModel.addReminder()
                                            quickReminderTitle = ""
                                        }
                                    }
                                    .textFieldStyle(.plain)
                                
                                if !quickReminderTitle.isEmpty {
                                    Button("Add") {
                                        Task {
                                            viewModel.newReminderTitle = quickReminderTitle
                                            await viewModel.addReminder()
                                            quickReminderTitle = ""
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(Theme.Typography.button)
                                    .foregroundStyle(colors.primary)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        
                        if viewModel.reminders.isEmpty {
                            EmptyStateView(title: "All Caught Up!", message: "No active reminders found.", systemImage: "checkmark.circle.trianglebadge.exclamationmark")
                        } else {
                            VStack(spacing: Theme.Spacing.md) {
                                ForEach(viewModel.reminders) { reminder in
                                    CardView {
                                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                                            Button {
                                                Task {
                                                    await viewModel.toggleReminder(reminder)
                                                }
                                            } label: {
                                                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(.title3, design: .default, weight: .regular))
                                                    .foregroundStyle(reminder.isCompleted ? colors.success : colors.mutedFg)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(reminder.isCompleted ? "Mark incomplete" : "Mark complete")
                                            
                                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                                Text(reminder.title)
                                                    .font(Theme.Typography.bodyEmphasized)
                                                    .foregroundStyle(colors.fg)
                                                    .strikethrough(reminder.isCompleted)
                                                
                                                if let notes = reminder.notes, !notes.isEmpty {
                                                    Text(notes)
                                                        .font(Theme.Typography.caption)
                                                        .foregroundStyle(colors.mutedFg)
                                                }
                                                
                                                HStack(spacing: Theme.Spacing.sm) {
                                                    Circle()
                                                        .fill(Color(cgColor: reminder.calendarColor))
                                                        .frame(width: 6, height: 6)
                                                    Text(reminder.calendarTitle)
                                                        .font(Theme.Typography.caption)
                                                        .foregroundStyle(colors.mutedFg)
                                                    
                                                    if let dueDate = reminder.dueDate {
                                                        Text("• Due: \(formatDate(dueDate))")
                                                            .font(Theme.Typography.caption)
                                                            .foregroundStyle(isOverdue(dueDate) ? colors.danger : colors.mutedFg)
                                                    }
                                                }
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }
                    } else {
                        EmptyStateView(
                            title: "Reminders Access Required",
                            message: "Please allow reminders access to manage your tasks.",
                            systemImage: "checklist.checked",
                            actionTitle: "Request Access"
                        ) {
                            Task {
                                await viewModel.checkPermissionsAndLoad()
                            }
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
}

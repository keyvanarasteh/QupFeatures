import DesignSystem
import EventKit
import SwiftUI

struct iCloudCalendarView: View {
    @ObservedObject var viewModel: iCloudFeatureViewModel
    @Environment(\.cupertinoColors) private var colors
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                SectionHeader("Calendars", subtitle: "Active calendars in your account", systemImage: "calendar")
                    .padding(.horizontal, Theme.Spacing.lg)
                
                if viewModel.calendarAccessGranted {
                    if viewModel.calendars.isEmpty {
                        EmptyStateView(title: "No Calendars", message: "We couldn't find any calendars.", systemImage: "calendar")
                    } else {
                        // Horizontal list of calendars
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.Spacing.md) {
                                ForEach(viewModel.calendars) { calendar in
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Circle()
                                            .fill(Color(cgColor: calendar.color))
                                            .frame(width: 8, height: 8)
                                        Text(calendar.title)
                                            .font(Theme.Typography.caption)
                                    }
                                    .padding(.horizontal, Theme.Spacing.md)
                                    .padding(.vertical, Theme.Spacing.sm)
                                    .background(colors.card, in: RoundedRectangle(cornerRadius: Theme.Radius.sm))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                            .stroke(colors.border, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }
                        
                        SectionHeader("Upcoming Events", subtitle: "Events for the next 7 days", systemImage: "clock")
                            .padding(.horizontal, Theme.Spacing.lg)
                            .padding(.top, Theme.Spacing.md)
                        
                        if viewModel.events.isEmpty {
                            EmptyStateView(title: "No Upcoming Events", message: "Your schedule is clear for the next 7 days.", systemImage: "calendar.badge.clock")
                        } else {
                            VStack(spacing: Theme.Spacing.md) {
                                ForEach(viewModel.events) { event in
                                    CardView {
                                        HStack(alignment: .top, spacing: Theme.Spacing.md) {
                                            Capsule()
                                                .fill(Color(cgColor: event.calendarColor))
                                                .frame(width: 4)
                                                .frame(maxHeight: .infinity)
                                            
                                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                                Text(event.title)
                                                    .font(Theme.Typography.bodyEmphasized)
                                                    .foregroundStyle(colors.fg)
                                                
                                                HStack(spacing: Theme.Spacing.sm) {
                                                    Image(systemName: "clock")
                                                        .font(Theme.Typography.caption)
                                                        .foregroundStyle(colors.mutedFg)
                                                        .accessibilityHidden(true)
                                                    Text(formatEventTime(event))
                                                        .font(Theme.Typography.caption)
                                                        .foregroundStyle(colors.mutedFg)
                                                }
                                                
                                                if let location = event.location, !location.isEmpty {
                                                    HStack(spacing: Theme.Spacing.sm) {
                                                        Image(systemName: "mappin.and.ellipse")
                                                            .font(Theme.Typography.caption)
                                                            .foregroundStyle(colors.mutedFg)
                                                            .accessibilityHidden(true)
                                                        Text(location)
                                                            .font(Theme.Typography.caption)
                                                            .foregroundStyle(colors.mutedFg)
                                                    }
                                                    .padding(.top, 2)
                                                }
                                            }
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }
                    }
                } else {
                    EmptyStateView(
                        title: "Calendar Access Required",
                        message: "Please allow calendar access to view your events.",
                        systemImage: "calendar.badge.exclamationmark",
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
    
    private func formatEventTime(_ event: EventModel) -> String {
        let formatter = DateFormatter()
        if event.isAllDay {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "\(formatter.string(from: event.startDate)) (All Day)"
        } else {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let start = formatter.string(from: event.startDate)
            formatter.dateStyle = .none
            let end = formatter.string(from: event.endDate)
            return "\(start) - \(end)"
        }
    }
}

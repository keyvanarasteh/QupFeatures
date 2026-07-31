import Combine
import DesignSystem
import EventKit
import FeatureContracts
import SwiftUI

public enum iCloudSection: String, CaseIterable, Identifiable {
    case photos
    case calendars
    case reminders
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .photos: return "Photos"
        case .calendars: return "Calendars"
        case .reminders: return "Reminders"
        }
    }
    
    public var systemImage: String {
        switch self {
        case .photos: return "photo.stack"
        case .calendars: return "calendar"
        case .reminders: return "checklist"
        }
    }
}

@MainActor
public final class iCloudFeatureViewModel: ObservableObject {
    @Published public var calendars: [CalendarModel] = []
    @Published public var events: [EventModel] = []
    @Published public var reminders: [ReminderModel] = []
    @Published public var isLoading = false
    @Published public var calendarAccessGranted = false
    @Published public var remindersAccessGranted = false
    
    @Published public var newReminderTitle = ""
    @Published public var newReminderNotes = ""
    
    private let eventKitManager = EventKitManager.shared
    
    public init() {}
    
    public func checkPermissionsAndLoad() async {
        isLoading = true
        defer { isLoading = false }
        
        calendarAccessGranted = await eventKitManager.requestCalendarAccess()
        remindersAccessGranted = await eventKitManager.requestRemindersAccess()
        
        if calendarAccessGranted {
            await loadCalendarData()
        }
        if remindersAccessGranted {
            await loadReminderData()
        }
    }
    
    public func loadCalendarData() async {
        do {
            let (fetchedCalendars, fetchedEvents) = try await eventKitManager.loadCalendarsAndEvents()
            self.calendars = fetchedCalendars
            self.events = fetchedEvents
        } catch {
            print("Failed to load calendar data: \(error)")
        }
    }
    
    public func loadReminderData() async {
        do {
            self.reminders = try await eventKitManager.loadReminders()
        } catch {
            print("Failed to load reminder data: \(error)")
        }
    }
    
    public func toggleReminder(_ reminder: ReminderModel) async {
        do {
            try await eventKitManager.toggleReminder(identifier: reminder.identifier)
            await loadReminderData()
        } catch {
            print("Failed to toggle reminder: \(error)")
        }
    }
    
    public func addReminder() async {
        guard !newReminderTitle.isEmpty else { return }
        do {
            try await eventKitManager.addReminder(title: newReminderTitle, notes: newReminderNotes.isEmpty ? nil : newReminderNotes)
            newReminderTitle = ""
            newReminderNotes = ""
            await loadReminderData()
        } catch {
            print("Failed to add reminder: \(error)")
        }
    }
}

public struct iCloudFeatureView: View {
    @StateObject private var viewModel = iCloudFeatureViewModel()
    @State private var selectedSection: iCloudSection
    @Environment(\.cupertinoColors) private var colors
    
    public init() {
        self.init(initialSection: .photos)
    }

    init(initialSection: iCloudSection) {
        _selectedSection = State(initialValue: initialSection)
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            sectionStrip
            SoftDivider()
            
            detail
        }
        .background(colors.bg)
        .navigationTitle("iCloud Core")
        .task {
            await viewModel.checkPermissionsAndLoad()
        }
    }
    
    private var sectionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(iCloudSection.allCases) { section in
                    Button {
                        selectedSection = section
                    } label: {
                        Label {
                            Text(section.title)
                                .font(.system(.body, design: .default, weight: .regular))
                        } icon: {
                            Image(systemName: section.systemImage)
                                .font(.system(.body, design: .default, weight: .regular))
                                .symbolRenderingMode(.monochrome)
                                .frame(width: 18, alignment: .center)
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            selectedSection == section ? colors.primary.opacity(0.12) : colors.card,
                            in: Capsule(style: .continuous)
                        )
                        .foregroundStyle(selectedSection == section ? colors.primary : colors.fg)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .background(colors.bg)
    }
    
    @ViewBuilder
    private var detail: some View {
        switch selectedSection {
        case .photos:
            MediaSortView()
        case .calendars:
            iCloudCalendarView(viewModel: viewModel)
        case .reminders:
            iCloudRemindersView(viewModel: viewModel)
        }
    }
}

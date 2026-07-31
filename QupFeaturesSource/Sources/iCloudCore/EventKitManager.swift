import Foundation
import EventKit
import QupCore
import CoreGraphics

public struct CalendarModel: Identifiable, Sendable, Equatable {
    public var id: String { identifier }
    public let identifier: String
    public let title: String
    public let color: CGColor
}

public struct EventModel: Identifiable, Sendable, Equatable {
    public var id: String { identifier }
    public let identifier: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let location: String?
    public let calendarColor: CGColor
}

public struct ReminderModel: Identifiable, Sendable, Equatable {
    public var id: String { identifier }
    public let identifier: String
    public let title: String
    public let isCompleted: Bool
    public let notes: String?
    public let calendarTitle: String
    public let calendarColor: CGColor
    public let dueDate: Date?
}

public enum EventKitError: Error, Sendable {
    case reminderNotFound
}

/// Manager for EventKit (Calendars and Reminders) integration.
public actor EventKitManager {
    public static let shared = EventKitManager()
    
    nonisolated(unsafe) private let eventStore = EKEventStore()

    private init() {}

    /// Requests Calendar full access if not already determined.
    public func requestCalendarAccess() async -> Bool {
        return await CalendarAccess.requestPermission()
    }
    
    /// Requests Reminders full access if not already determined.
    public func requestRemindersAccess() async -> Bool {
        return await RemindersAccess.requestPermission()
    }
    
    /// Returns the shared EKEventStore instance.
    public nonisolated func store() -> EKEventStore {
        return eventStore
    }
    
    /// Loads calendars and events for the next 7 days in a background actor execution.
    public func loadCalendarsAndEvents() async throws -> ([CalendarModel], [EventModel]) {
        let fetchedCalendars = eventStore.calendars(for: .event)
        let calendarModels = fetchedCalendars.map { calendar in
            CalendarModel(
                identifier: calendar.calendarIdentifier,
                title: calendar.title,
                color: calendar.cgColor
            )
        }
        
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now
        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: fetchedCalendars)
        let fetchedEvents = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        let eventModels = fetchedEvents.map { event in
            EventModel(
                identifier: event.eventIdentifier,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                calendarColor: event.calendar.cgColor
            )
        }
        
        return (calendarModels, eventModels)
    }
    
    /// Loads incomplete reminders from active reminder lists in a background actor execution.
    public func loadReminders() async throws -> [ReminderModel] {
        let reminderCalendars = eventStore.calendars(for: .reminder)
        guard !reminderCalendars.isEmpty else { return [] }
        
        let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: reminderCalendars)
        
        return await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let models = (reminders ?? []).map { reminder in
                    ReminderModel(
                        identifier: reminder.calendarItemIdentifier,
                        title: reminder.title,
                        isCompleted: reminder.isCompleted,
                        notes: reminder.notes,
                        calendarTitle: reminder.calendar.title,
                        calendarColor: reminder.calendar.cgColor,
                        dueDate: reminder.dueDateComponents?.date
                    )
                }
                continuation.resume(returning: models)
            }
        }
    }
    
    /// Toggles the completion status of a reminder.
    public func toggleReminder(identifier: String) throws {
        guard let reminder = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
            throw EventKitError.reminderNotFound
        }
        reminder.isCompleted.toggle()
        try eventStore.save(reminder, commit: true)
    }
    
    /// Adds a new reminder to the default or first available reminders calendar.
    public func addReminder(title: String, notes: String?) throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes
        
        if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
            reminder.calendar = defaultCalendar
        } else {
            let reminderCalendars = eventStore.calendars(for: .reminder)
            reminder.calendar = reminderCalendars.first
        }
        
        try eventStore.save(reminder, commit: true)
    }
}


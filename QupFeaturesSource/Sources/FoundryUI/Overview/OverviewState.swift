import Combine
import Foundation
import FoundryAPI

@MainActor
public final class OverviewState: ObservableObject {
    @Published public private(set) var courseStats: FoundryCourseStats?
    @Published public private(set) var kbStats: FoundryKbStats?
    @Published public private(set) var moduleStats: FoundryModuleStats?
    @Published public private(set) var loading = false
    @Published public var error: String?

    private let api: FoundryAPI

    public init(api: FoundryAPI) { self.api = api }

    public func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let cs = api.courseStats()
            async let ks = api.kbStats()
            async let ms = api.moduleStats()
            (courseStats, kbStats, moduleStats) = try await (cs, ks, ms)
        } catch {
            self.error = "\(error)"
        }
    }
}

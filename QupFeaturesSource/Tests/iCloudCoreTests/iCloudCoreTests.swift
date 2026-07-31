import XCTest
@testable import iCloudCore

final class iCloudCoreTests: XCTestCase {
    func testExample() async throws {
        // A placeholder test to ensure the package builds and tests run.
        let manager = PhotoKitManager.shared
        XCTAssertNotNil(manager)
    }
}

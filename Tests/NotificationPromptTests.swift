import XCTest
@testable import StretchBreak

final class NotificationPromptTests: XCTestCase {

    func testPromptPoolsStayAligned() {
        XCTAssertEqual(NotificationScheduler.promptsEN.count, NotificationScheduler.promptsZH.count)
    }

    func testNoRepeatWithinADay() {
        let order = NotificationScheduler.promptOrder(forDay: 20_000, count: NotificationScheduler.promptsEN.count)
        XCTAssertEqual(Set(order).count, order.count)
    }

    func testOrderIsStableAcrossReschedules() {
        XCTAssertEqual(NotificationScheduler.promptOrder(forDay: 20_000, count: 44),
                       NotificationScheduler.promptOrder(forDay: 20_000, count: 44))
    }

    func testDifferentDaysGetDifferentOrders() {
        XCTAssertNotEqual(NotificationScheduler.promptOrder(forDay: 20_000, count: 44),
                          NotificationScheduler.promptOrder(forDay: 20_001, count: 44))
    }
}

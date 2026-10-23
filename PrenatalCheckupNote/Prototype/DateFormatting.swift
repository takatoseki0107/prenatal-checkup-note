import Foundation

extension Date {
    /// 健診の日時の表示。例：「11月5日(木) 10:30」（日本語の設定のとき）。
    var appointmentDateTimeText: String {
        formatted(.dateTime.month().day().weekday(.abbreviated).hour().minute())
    }
}

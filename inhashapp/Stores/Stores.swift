import Foundation
import SwiftUI
import Combine

final class ScheduleStore: ObservableObject {
    @Published var items: [ScheduleItem] = []
    
    init() {
        let now = Date()
        items = [
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "1주차 실습과제", due: Calendar.current.date(byAdding: .hour, value: 10, to: now)!),
            ScheduleItem(type: .lecture, course: "생명과학", title: "1주차 1교시 동영상", due: Calendar.current.date(byAdding: .day, value: 1, to: now)!),
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "2주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 3, to: now)!),
            ScheduleItem(type: .lecture, course: "컴퓨터네트워크", title: "Chap1-1 동영상", due: Calendar.current.date(byAdding: .day, value: 4, to: now)!),
            // 추가 예시 데이터: 3, 4, 5주차 실습과제
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "3주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 7, to: now)!),
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "4주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 14, to: now)!),
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "5주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 21, to: now)!),
            // 6 ~ 11주차 실습과제
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "6주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 28, to: now)!),
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "7주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 35, to: now)!),
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "8주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 42, to: now)!),
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "9주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 49, to: now)!),
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "10주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 56, to: now)!),
            ScheduleItem(type: .assignment, course: "객체지향프로그래밍", title: "11주차 실습과제", due: Calendar.current.date(byAdding: .day, value: 63, to: now)!)
        ]
    }
}



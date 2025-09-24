import SwiftUI

struct HomeView: View {
	@EnvironmentObject private var store: ScheduleStore
	@State private var selectedFilter: ScheduleFilter = .all

	private var filteredItems: [ScheduleItem] {
		let base = store.items.sorted { $0.due < $1.due }
		switch selectedFilter {
		case .all: return base
		case .assignment: return base.filter { $0.type == .assignment }
		case .lecture: return base.filter { $0.type == .lecture }
		}
	}

	var body: some View {
		ZStack {
			AppBackground()
			ScrollView(showsIndicators: false) {
				VStack(spacing: 16) {
					SectionHeader(title: "이번 주 일정")
					FilterBar(selected: $selectedFilter)
					LazyVStack(spacing: 12) {
						ForEach(filteredItems) { item in
							ScheduleCard(item: item)
						}
					}
				}
				.padding(.horizontal, 16)
				.padding(.vertical, 12)
			}
		}
	}
}

private enum ScheduleFilter: CaseIterable { case all, assignment, lecture }

private struct HomeHeader: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 10) {
				Text("안녕하세요! 👋")
					.font(.system(size: 22, weight: .heavy))
					.foregroundStyle(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
				Spacer(minLength: 0)
			}
			Text("다가오는 일정을 확인해보세요")
				.font(.callout)
				.foregroundColor(.secondary)
		}
	}
}

private struct FilterBar: View {
	@Binding var selected: ScheduleFilter
	
	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 8) {
				FilterChip(label: "전체", systemImage: "square.grid.2x2", isOn: selected == .all) { selected = .all }
				FilterChip(label: "과제", systemImage: ScheduleType.assignment.icon, isOn: selected == .assignment) { selected = .assignment }
				FilterChip(label: "수업", systemImage: ScheduleType.lecture.icon, isOn: selected == .lecture) { selected = .lecture }
			}
		}
	}
}

private struct FilterChip: View {
	let label: String
	let systemImage: String
	let isOn: Bool
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack(spacing: 6) {
				Image(systemName: systemImage).font(.footnote)
				Text(label).font(.subheadline)
			}
			.padding(.vertical, 6)
			.padding(.horizontal, 10)
			.background(isOn ? Color.accentColor.opacity(0.18) : Color.black.opacity(0.06))
			.foregroundColor(isOn ? .accentColor : .primary)
			.clipShape(Capsule())
		}
		.buttonStyle(.plain)
	}
}

private struct SectionHeader: View {
	let title: String
	
	var body: some View {
		HStack {
			Spacer(minLength: 0)
			Text(title)
				.font(.headline)
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 2)
	}
}

private struct ScheduleCard: View {
	let item: ScheduleItem
	
	private var remainingText: String {
		let now = Date(); let diff = item.due.timeIntervalSince(now)
		if diff <= 0 { return "마감" }
		let days = Int(ceil(diff / 86400))
		if days <= 1 { return "내일 마감" }
		return "\(days)일 남음"
	}
	
	private var remainingColor: Color {
		let now = Date(); let diff = item.due.timeIntervalSince(now)
		if diff <= 0 { return .red }
		let days = Int(ceil(diff / 86400))
		return days <= 2 ? .red : .secondary
	}
	
	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 16)
				.fill(Color.white)
				.shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
			HStack(alignment: .top, spacing: 12) {
				VStack(alignment: .leading, spacing: 8) {
					HStack(spacing: 8) {
						Tag(text: item.type.title)
						DeadlineTag(due: item.due)
						Spacer()
						Image(systemName: "arrow.up.right.square")
							.font(.callout)
							.foregroundColor(.secondary)
					}
					Text(item.title)
						.font(.subheadline.weight(.semibold))
					Text(item.course)
						.font(.footnote)
						.foregroundColor(.secondary)
					HStack {
						Image(systemName: "clock")
							.font(.footnote)
							.foregroundColor(.secondary)
						Text(item.due, formatter: Self.dateFormatter)
							.font(.footnote)
							.foregroundColor(.secondary)
						Spacer()
						Text(remainingText)
							.font(.footnote.weight(.semibold))
							.foregroundColor(remainingColor)
					}
				}
			}
			.padding(12)
		}
	}
	
	private static let dateFormatter: DateFormatter = {
		let f = DateFormatter()
		f.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return f
	}()
}

private struct Tag: View {
	let text: String
	var body: some View {
		Text(text)
			.font(.caption2.weight(.semibold))
			.padding(.vertical, 3)
			.padding(.horizontal, 8)
			.background(Color.black.opacity(0.06))
			.foregroundColor(.primary)
			.clipShape(Capsule())
	}
}

private struct DeadlineTag: View {
	let due: Date
	var body: some View {
		let now = Date(); let diff = due.timeIntervalSince(now)
		let text: String
		let color: Color
		if diff <= 0 { text = "D-0"; color = .red }
		else {
			let days = max(0, Int(ceil(diff / 86400)))
			text = days == 0 ? "D-0" : "D-\(days)"
			color = days <= 2 ? .orange : .blue
		}
		return Text(text)
			.font(.caption2.weight(.bold))
			.padding(.vertical, 3)
			.padding(.horizontal, 6)
			.background(color.opacity(0.15))
			.foregroundColor(color)
			.clipShape(Capsule())
	}
}

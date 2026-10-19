import SwiftUI

struct ScheduleListView: View {
    @State private var store = ScheduleStore()
    @State private var selectedDay = Date()
    @State private var editing: Schedule?
    @State private var pendingDelete: Schedule?
    private var visible: [Schedule] {
        store.schedules.filter { $0.overlaps(day: selectedDay) }.sorted { $0.start < $1.start }
    }
    var body: some View {
        NavigationStack {
            List {
                DatePicker("날짜", selection: $selectedDay, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Section("일정 \(visible.count)개") {
                    if visible.isEmpty { ContentUnavailableView("등록된 일정이 없어요", systemImage: "calendar", description: Text("오른쪽 위 + 버튼으로 일정을 추가하세요.")) }
                    ForEach(visible) { item in
                        HStack {
                            Button {
                                var changed = item; changed.isCompleted.toggle(); store.upsert(changed)
                            } label: { Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(item.isCompleted ? "완료 취소" : "완료 표시")
                            Button { editing = item } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).strikethrough(item.isCompleted).foregroundStyle(.primary)
                                    Text("\(item.start.formatted(date: .abbreviated, time: .shortened)) – \(item.end.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                                    if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                                }
                            }.buttonStyle(.plain)
                        }.swipeActions { Button("삭제", role: .destructive) { pendingDelete = item } }
                    }
                }
            }
            .navigationTitle("DayFlow")
            .toolbar { Button("일정 추가", systemImage: "plus") {
                let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDay) ?? selectedDay
                editing = Schedule(title: "", start: start, end: start.addingTimeInterval(3600))
            } }
            .sheet(item: $editing) { item in ScheduleEditor(item: item) { item in
                if store.upsert(item) { return nil }
                let message = store.error ?? "저장하지 못했습니다."
                store.error = nil
                return message
            } }
            .confirmationDialog("이 일정을 삭제할까요?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let item = pendingDelete { store.commit(store.schedules.filter { $0.id != item.id }) }
                    pendingDelete = nil
                }
            }
            .alert("확인해주세요", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("확인") { store.error = nil } } message: { Text(store.error ?? "") }
        }
    }
}

struct ScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: Schedule
    @State private var saveError: String?
    var onSave: (Schedule) -> String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("제목", text: $item.title)
                DatePicker("시작", selection: $item.start)
                DatePicker("종료", selection: $item.end)
                TextField("메모", text: $item.note, axis: .vertical)
                if let message = item.validationMessage { Text(message).foregroundStyle(.red) }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .navigationTitle("일정 편집")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { saveError = onSave(item); if saveError == nil { dismiss() } }.disabled(item.validationMessage != nil) }
            }
        }
    }
}

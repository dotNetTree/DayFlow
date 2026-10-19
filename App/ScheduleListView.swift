import SwiftUI

struct ScheduleListView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = ScheduleStore.makeAppStore()
    @State private var selectedDay = Date()
    @State private var query = ""
    @State private var editing: Schedule?
    @State private var pendingDelete: Schedule?
    private var visible: [Schedule] {
        ScheduleSearch.filter(store.schedules, day: selectedDay, query: query)
    }
    var body: some View {
        NavigationStack {
            List {
                DatePicker("날짜", selection: $selectedDay, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                if let message = store.notificationMessage {
                    Section("알림 상태") {
                        Text(message)
                        Button("알림 다시 동기화") { store.syncNotifications() }
                            .disabled(store.isSyncingNotifications)
                    }
                }
                Section("일정 \(visible.count)개") {
                    if visible.isEmpty {
                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            ContentUnavailableView("등록된 일정이 없어요", systemImage: "calendar", description: Text("오른쪽 위 + 버튼으로 일정을 추가하세요."))
                        } else {
                            ContentUnavailableView("검색 결과가 없어요", systemImage: "magnifyingglass", description: Text("검색어나 날짜를 바꿔보세요."))
                        }
                    }
                    ForEach(visible) { item in
                        HStack {
                            Button {
                                var changed = item; changed.isCompleted.toggle(); store.upsert(changed)
                            } label: { Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle") }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(item.isCompleted ? "완료 취소" : "완료 표시")
                            .accessibilityIdentifier("schedule.complete.\(item.id.uuidString)")
                            .accessibilityValue(item.isCompleted ? "completed" : "pending")
                            Button { editing = item } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.title).strikethrough(item.isCompleted).foregroundStyle(.primary)
                                    Text("\(item.start.formatted(date: .abbreviated, time: .shortened)) – \(item.end.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                                    if !item.note.isEmpty { Text(item.note).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                                }
                            }.buttonStyle(.plain)
                            .accessibilityIdentifier("schedule.edit.\(item.id.uuidString)")
                            .accessibilityLabel(item.title)
                        }.swipeActions { Button("삭제", role: .destructive) { pendingDelete = item }.accessibilityIdentifier("schedule.delete.\(item.id.uuidString)") }
                    }
                }
            }
            .accessibilityIdentifier("schedule.list")
            .navigationTitle("DayFlow")
            .searchable(text: $query, prompt: "제목 또는 메모 검색")
            .toolbar { Button("일정 추가", systemImage: "plus") {
                let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDay) ?? selectedDay
                editing = Schedule(title: "", start: start, end: start.addingTimeInterval(3600))
            }.accessibilityIdentifier("schedule.add") }
            .task { store.syncNotifications() }
            .onChange(of: scenePhase) { _, phase in if phase == .active { store.syncNotifications() } }
            .sheet(item: $editing) { item in ScheduleEditor(store: store, item: item) { item in
                if store.upsert(item) { return nil }
                let message = store.error ?? "저장하지 못했습니다."
                store.error = nil
                return message
            } }
            .confirmationDialog("이 일정을 삭제할까요?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("삭제", role: .destructive) {
                    if let item = pendingDelete { store.commit(store.schedules.filter { $0.id != item.id }) }
                    pendingDelete = nil
                }.accessibilityIdentifier("schedule.delete.confirm")
            }
            .alert("확인해주세요", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) { Button("확인") { store.error = nil } } message: { Text(store.error ?? "") }
        }
    }
}

struct ScheduleEditor: View {
    @Bindable var store: ScheduleStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State var item: Schedule
    @State private var saveError: String?
    var onSave: (Schedule) -> String?
    private var permissionDescription: String {
        switch store.authorization {
        case .notDetermined: "알림 토글을 켜면 권한을 요청합니다."
        case .authorized: "저장하면 시작 시간에 알림을 예약합니다."
        case .denied: "알림 권한이 꺼져 있어요. 일정은 저장할 수 있어요."
        case .provisional: "조용한 알림이 허용되어 있어요. 배너는 기기 설정에 따라 표시됩니다."
        case .ephemeral: "임시 알림 권한이 허용되어 있어요."
        case .unknown: "알림 권한 상태를 확인할 수 없어요."
        }
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("제목", text: $item.title).accessibilityIdentifier("editor.title")
                DatePicker("시작", selection: $item.start)
                DatePicker("종료", selection: $item.end)
                TextField("메모", text: $item.note, axis: .vertical).accessibilityIdentifier("editor.note")
                Section("알림") {
                    Toggle("시작 시간에 알림", isOn: $item.isNotificationEnabled)
                        .disabled(store.isRequestingPermission)
                        .onChange(of: item.isNotificationEnabled) { _, enabled in
                            if enabled { Task { await store.requestNotificationPermission() } }
                        }
                    if store.isRequestingPermission { ProgressView("알림 권한 확인 중") }
                    if item.isNotificationEnabled {
                        Text(permissionDescription).font(.caption)
                        if store.authorization == .denied {
                            Button("설정에서 알림 허용") {
                                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                            }
                        }
                        if item.start <= Date() { Text("과거 일정은 저장할 수 있지만 알림은 예약하지 않아요.").font(.caption) }
                        if let message = store.notificationMessage { Text(message).font(.caption) }
                    }
                }
                if let message = item.validationMessage { Text(message).foregroundStyle(.red) }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .navigationTitle("일정 편집")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() }.accessibilityIdentifier("editor.cancel") }
                ToolbarItem(placement: .confirmationAction) { Button("저장") { saveError = onSave(item); if saveError == nil { dismiss() } }.disabled(item.validationMessage != nil || store.isRequestingPermission).accessibilityIdentifier("editor.save") }
            }
        }
    }
}

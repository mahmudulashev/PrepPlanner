import SwiftUI
import SwiftData

struct HabitEditor: View {
    let habit: Habit?
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.order) private var habits: [Habit]
    @State private var name = ""
    @State private var emoji = "✅"

    private let suggestions = ["✍️", "🎙️", "😴", "📒", "📚", "🎧", "🧠", "📝", "🏃", "💧", "⏰", "🧘"]
    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        EditorScaffold(title: habit == nil ? "New habit" : "Edit habit", canSave: !trimmed.isEmpty, onSave: save) {
            Text(verbatim: emoji).font(.system(size: 34))
        } content: {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("e.g. Wrote Task 2"))
                    TextField("Emoji", text: $emoji)
                        .onChange(of: emoji) { _, new in
                            // Keep a single emoji.
                            if new.count > 1, let last = new.last { emoji = String(last) }
                        }
                }
                Section("Suggestions") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(suggestions, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(verbatim: e)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(emoji == e ? Theme.accentSoft : Theme.cardMuted))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(minWidth: 440, idealWidth: 450, maxWidth: 580, minHeight: 380)
        .onAppear {
            if let habit {
                name = habit.name
                emoji = habit.emoji
            }
        }
    }

    private func save() {
        if let habit {
            habit.name = trimmed
            habit.emoji = emoji.isEmpty ? "✅" : emoji
        } else {
            let h = Habit(name: trimmed, emoji: emoji.isEmpty ? "✅" : emoji, order: (habits.map(\.order).max() ?? -1) + 1)
            context.insert(h)
        }
        try? context.save()
    }
}

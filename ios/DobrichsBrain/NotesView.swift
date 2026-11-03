import SwiftData
import SwiftUI

struct NotesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Note.updated, order: .reverse) private var notes: [Note]
    @State private var draft = ""
    @State private var search = ""
    @State private var tag: String?
    @State private var editing: Note?

    private var allTags: [String] {
        Array(Set(notes.flatMap { Tags.of($0.text) })).sorted()
    }

    private var filtered: [Note] {
        let words = search.lowercased().split(separator: " ").map(String.init)
        return notes
            .filter { n in
                let text = n.text.lowercased()
                return (tag == nil || Tags.of(n.text).contains(tag!)) && words.allSatisfy { text.contains($0) }
            }
            .sorted { a, b in a.pinned != b.pinned ? a.pinned : a.updated > b.updated }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Co chcesz zapamiętać? Użyj #tagów", text: $draft, axis: .vertical)
                        .lineLimit(2...6)
                        .accessibilityIdentifier("noteDraft")
                    Button("Zapisz", action: add)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("noteSave")
                }

                if !allTags.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(allTags, id: \.self) { t in
                                    Button(t) { tag = tag == t ? nil : t }
                                        .buttonStyle(.bordered)
                                        .tint(tag == t ? Color.accentColor : Color.secondary)
                                }
                            }
                        }
                    }
                }

                Section {
                    if filtered.isEmpty {
                        ContentUnavailableView(notes.isEmpty ? "Tu będzie Twoja pamięć" : "Nic nie znaleziono",
                                               systemImage: "brain.head.profile",
                                               description: Text(notes.isEmpty ? "Zapisz pierwszą myśl." : ""))
                    }
                    ForEach(filtered) { note in
                        NoteRow(note: note)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = note }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { context.delete(note) } label: {
                                    Label("Usuń", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { note.pinned.toggle() } label: {
                                    Label(note.pinned ? "Odepnij" : "Przypnij", systemImage: "pin")
                                }
                                .tint(.orange)
                            }
                    }
                }
            }
            .searchable(text: $search, prompt: "Szukaj w pamięci")
            .navigationTitle("Notatki")
            .sheet(item: $editing) { NoteEditor(note: $0) }
        }
    }

    private func add() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        context.insert(Note(text: text))
        draft = ""
    }
}

private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                if note.pinned {
                    Image(systemName: "pin.fill").foregroundStyle(.orange).font(.caption)
                }
                Text(note.text)
            }
            Text(note.updated, format: .dateTime.day().month().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct NoteEditor: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TextEditor(text: $note.text)
                .padding()
                .navigationTitle("Notatka")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Gotowe") {
                            note.updated = .now
                            dismiss()
                        }
                    }
                }
        }
    }
}

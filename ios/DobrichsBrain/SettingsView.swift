import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("monthlyTarget") private var target: Double = 168
    @AppStorage("hourlyRate") private var rate: Double = 0
    @AppStorage("waterGoal") private var waterGoal: Int = 2000
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Praca") {
                    LabeledContent("Cel godzin / miesiąc") {
                        TextField("168", value: $target, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Stawka (zł/h)") {
                        TextField("0", value: $rate, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Nawyki") {
                    LabeledContent("Cel wody (ml / dzień)") {
                        TextField("2000", value: $waterGoal, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section {
                    Button("Importuj kopię z web-apki") { importing = true }
                } header: {
                    Text("Przenosiny")
                } footer: {
                    Text("W web-apce: Więcej → Eksportuj kopię, zapisz plik w Plikach, potem wybierz go tutaj.")
                }

                Section("O apce") {
                    LabeledContent("Wersja", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
            .navigationTitle("Więcej")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                message = importBackup(result)
            }
            .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK") {}
            }
        }
    }

    private func importBackup(_ result: Result<URL, Error>) -> String {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let backup = try JSONDecoder().decode(WebBackup.self, from: Data(contentsOf: url))
            let summary = backup.importInto(context)
            target = UserDefaults.standard.double(forKey: "monthlyTarget")
            rate = UserDefaults.standard.double(forKey: "hourlyRate")
            return summary
        } catch {
            return "To nie jest plik kopii Dobrich’s Brain."
        }
    }
}

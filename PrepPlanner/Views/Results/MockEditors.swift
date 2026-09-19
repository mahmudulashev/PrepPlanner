import SwiftUI
import SwiftData

/// Shared frame for add/edit sheets: title, content, Cancel/Save footer.
struct EditorScaffold<Content: View, Trailing: View>: View {
    let title: String
    var saveTitle = "Save"
    var canSave = true
    let onSave: () -> Void
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content
    // Not private so the synthesized memberwise init stays internal.
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.title2.bold())
                Spacer()
                trailing
            }
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .padding(.bottom, 6)

            content

            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(saveTitle) {
                    onSave()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
            .padding(16)
        }
    }
}

// MARK: - IELTS

struct IELTSEditor: View {
    let mock: IELTSMock?
    @Environment(\.modelContext) private var context

    @State private var date = Date()
    @State private var listeningRaw = 30
    @State private var readingRaw = 30
    @State private var writing = 6.0
    @State private var speaking = 6.0
    @State private var writingCriteria: [Double?] = [nil, nil, nil, nil]
    @State private var speakingCriteria: [Double?] = [nil, nil, nil, nil]
    @State private var showWritingCriteria = false
    @State private var showSpeakingCriteria = false
    @State private var note = ""

    private var listeningBand: Double { Band.listening(listeningRaw) }
    private var readingBand: Double { Band.reading(readingRaw) }
    private var overall: Double { Band.overall([listeningBand, readingBand, writing, speaking]) }

    var body: some View {
        EditorScaffold(title: mock == nil ? "New IELTS mock" : "Edit IELTS mock", onSave: save) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("OVERALL").font(.caption2.weight(.semibold)).opacity(0.85)
                Text(Band.format(overall))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
        } content: {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Listening & Reading (raw score out of 40)") {
                    rawRow("Listening", value: $listeningRaw, band: listeningBand, skill: .listening)
                    rawRow("Academic Reading", value: $readingRaw, band: readingBand, skill: .reading)
                }
                Section("Writing") {
                    bandPicker("Writing band", selection: $writing)
                    DisclosureGroup("Criteria (optional)", isExpanded: $showWritingCriteria) {
                        criteriaRows(labels: ["Task Response (TR)", "Coherence & Cohesion (CC)",
                                              "Lexical Resource (LR)", "Grammar (GRA)"],
                                     values: $writingCriteria, apply: { writing = $0 })
                    }
                }
                Section("Speaking") {
                    bandPicker("Speaking band", selection: $speaking)
                    DisclosureGroup("Criteria (optional)", isExpanded: $showSpeakingCriteria) {
                        criteriaRows(labels: ["Fluency & Coherence (FC)", "Lexical Resource (LR)",
                                              "Grammar (GRA)", "Pronunciation (P)"],
                                     values: $speakingCriteria, apply: { speaking = $0 })
                    }
                }
                Section("Note") {
                    TextField("e.g. Cambridge 18 Test 2, felt rushed in Reading P3", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 540, height: 680)
        .onAppear(perform: load)
    }

    private func rawRow(_ title: String, value: Binding<Int>, band: Double, skill: Skill) -> some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(title, value: Binding(get: { value.wrappedValue },
                                                set: { value.wrappedValue = min(max($0, 0), 40) }),
                          format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48)
                Stepper(title, value: value, in: 0...40)
                    .labelsHidden()
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                BandBadge(band: band)
                    .frame(width: 52)
            }
        } label: {
            Label(title, systemImage: skill.symbol)
        }
    }

    private func bandPicker(_ title: String, selection: Binding<Double>) -> some View {
        Picker(title, selection: selection) {
            ForEach(Band.halfSteps.reversed(), id: \.self) { b in
                Text(Band.format(b)).tag(b)
            }
        }
    }

    @ViewBuilder
    private func criteriaRows(labels: [String], values: Binding<[Double?]>, apply: @escaping (Double) -> Void) -> some View {
        ForEach(labels.indices, id: \.self) { i in
            Picker(labels[i], selection: values[i]) {
                Text("–").tag(Double?.none)
                ForEach(Band.halfSteps.reversed(), id: \.self) { b in
                    Text(Band.format(b)).tag(Optional(b))
                }
            }
        }
        if let result = Band.criteria(values.wrappedValue) {
            HStack {
                Text("Criteria average \(String(format: "%.2f", result.average))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Use \(Band.format(result.band))") { apply(result.band) }
                    .help("Sets the band to the criteria average, rounded down to the nearest half band")
            }
            .font(.callout)
        }
    }

    private func load() {
        guard let m = mock else { return }
        date = m.date
        listeningRaw = m.listeningRaw
        readingRaw = m.readingRaw
        writing = m.writingBand
        speaking = m.speakingBand
        writingCriteria = m.writingCriteria
        speakingCriteria = m.speakingCriteria
        showWritingCriteria = writingCriteria.contains { $0 != nil }
        showSpeakingCriteria = speakingCriteria.contains { $0 != nil }
        note = m.note
    }

    private func save() {
        let m: IELTSMock
        if let mock {
            m = mock
        } else {
            m = IELTSMock(date: date)
            context.insert(m)
        }
        m.date = date
        m.listeningRaw = listeningRaw
        m.readingRaw = readingRaw
        m.writingBand = writing
        m.speakingBand = speaking
        (m.writingTR, m.writingCC, m.writingLR, m.writingGRA) =
            (writingCriteria[0], writingCriteria[1], writingCriteria[2], writingCriteria[3])
        (m.speakingFC, m.speakingLR, m.speakingGRA, m.speakingP) =
            (speakingCriteria[0], speakingCriteria[1], speakingCriteria[2], speakingCriteria[3])
        m.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
    }
}

// MARK: - SAT

struct SATEditor: View {
    let mock: SATMock?
    @Environment(\.modelContext) private var context

    @State private var date = Date()
    @State private var readingWriting = 600
    @State private var math = 600
    @State private var note = ""

    private var total: Int { SATScore.clampSection(readingWriting) + SATScore.clampSection(math) }

    var body: some View {
        EditorScaffold(title: mock == nil ? "New SAT mock" : "Edit SAT mock", onSave: save) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("TOTAL").font(.caption2.weight(.semibold)).opacity(0.8)
                Text("\(total)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.onInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.ink))
        } content: {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                Section("Section scores (200–800)") {
                    scoreRow("Reading & Writing", value: $readingWriting, skill: .satRW)
                    scoreRow("Math", value: $math, skill: .satMath)
                }
                Section("Note") {
                    TextField("e.g. Bluebook Practice Test 4", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 480, height: 420)
        .onAppear {
            guard let m = mock else { return }
            date = m.date
            readingWriting = m.readingWriting
            math = m.math
            note = m.note
        }
    }

    private func scoreRow(_ title: String, value: Binding<Int>, skill: Skill) -> some View {
        LabeledContent {
            HStack(spacing: 8) {
                TextField(title, value: value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
                    .onSubmit { value.wrappedValue = SATScore.clampSection(value.wrappedValue) }
                Stepper(title, value: value, in: SATScore.sectionRange, step: 10)
                    .labelsHidden()
            }
        } label: {
            Label(title, systemImage: skill.symbol)
        }
    }

    private func save() {
        let m: SATMock
        if let mock {
            m = mock
        } else {
            m = SATMock(date: date)
            context.insert(m)
        }
        m.date = date
        m.readingWriting = SATScore.clampSection(readingWriting)
        m.math = SATScore.clampSection(math)
        m.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
    }
}

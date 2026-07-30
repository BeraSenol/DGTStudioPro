//
//  SmartTagEditorView.swift
//  DGTStudioPro
//
//  Created by Supreme Leader on 20/07/2026.
//

import SwiftUI

/// The editor's working copy: a pure value snapshot of a tag (or a fresh
/// one), carrying an optional reference to the model it came from.
/// Cancel discards the value; only OK touches a model — in
/// `ContentView.commit`, never here.
internal struct TagDraft: Identifiable {
    internal let id = UUID()
    internal let editing: SmartTag?
    internal var name: String
    internal var colorName: TagColor
    internal var matchAll: Bool
    internal var rules: [TagRule]
    
    /// A fresh draft: one blank string rule, which matches nothing until
    /// filled (the empty-text rule) — a new tag is inert, never
    /// select-all.
    internal init() {
        self.editing = nil
        self.name = "New Tag"
        self.colorName = .blue
        self.matchAll = false
        self.rules = [TagRule()]
    }
    
    internal init(editing tag: SmartTag) {
        self.editing = tag
        self.name = tag.name
        self.colorName = tag.colorName
        self.matchAll = tag.matchAll
        self.rules = tag.rules
    }
}

/// The Apple Music smart-playlist editor shape (D12′): name, color,
/// "Match ⟨any|all⟩ of the following rules", rule rows with − / +,
/// Cancel/OK. Deliberately absent from the reference: *Limit to* (a
/// filter isn't a playlist), *match only checked* (no checked state),
/// *Live updating* (computed at render — live by construction).
internal struct SmartTagEditorView: View {
    
    // MARK: Stored Properties
    
    @State internal var draft: TagDraft
    internal let onSave: (TagDraft) -> Void
    
    // MARK: Private Properties
    
    @Environment(\.dismiss) private var dismiss
    
    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // MARK: Body
    
    internal var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            matchModeRow
            rulesList
            Spacer(minLength: 0)
            footer
        }
        .padding(20)
        .frame(width: 620, height: 420)
        .accessibilityIdentifier(AccessibilityID.tagsEditor)
    }
    
    // MARK: Sections
    
    private var header: some View {
        HStack(spacing: 12) {
            TextField("Tag Name", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .font(.headline)
                .padding(.trailing)
                .accessibilityIdentifier(AccessibilityID.tagsEditorName)
            
            colorPicker
        }
    }
    
    private var colorPicker: some View {
        HStack(spacing: 6) {
            ForEach(TagColor.allCases) { option in
                Circle()
                    .fill(option.color)
                    .frame(width: 16, height: 16)
                    .overlay {
                        if option == draft.colorName {
                            Circle().strokeBorder(.primary, lineWidth: 2)
                        }
                    }
                    .contentShape(Circle())
                    .onTapGesture { draft.colorName = option }
            }
        }
    }
    
    private var matchModeRow: some View {
        HStack(spacing: 6) {
            Text("Match")
            Picker("Match Mode", selection: $draft.matchAll) {
                Text("any").tag(false)
                Text("all").tag(true)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            Text("of the following rules:")
        }
        .font(.callout)
    }
    
    private var rulesList: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach($draft.rules) { $rule in
                    TagRuleRow(
                        rule: $rule,
                        onRemove: { draft.rules.removeAll { $0.id == rule.id } },
                        onAdd: { insertRule(after: rule.id) }
                    )
                }
                if draft.rules.isEmpty {
                    HStack {
                        Text("No rules — this tag matches nothing.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            draft.rules.append(TagRule())
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier(AccessibilityID.tagsEditorCancel)
            Button("OK") {
                onSave(draft)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
            .accessibilityIdentifier(AccessibilityID.tagsEditorSave)
        }
    }
    
    // MARK: Instance Methods
    
    private func insertRule(after id: UUID) {
        guard let index = draft.rules.firstIndex(where: { $0.id == id }) else {
            draft.rules.append(TagRule())
            return
        }
        draft.rules.insert(TagRule(), at: index + 1)
    }
}

// MARK: Rule Row

private struct TagRuleRow: View {
    
    @Binding var rule: TagRule
    let onRemove: () -> Void
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Picker("Field", selection: $rule.field) {
                ForEach(TagRule.Field.allCases) { field in
                    Text(field.displayName).tag(field)
                }
            }
            .labelsHidden()
            .fixedSize()
            .frame(width: 140)
            
            Picker("Comparison", selection: $rule.comparison) {
                ForEach(rule.field.comparisons) { comparison in
                    Text(comparison.displayName).tag(comparison)
                }
            }
            .labelsHidden()
            .fixedSize()
            .frame(width: 140)
            
            valueControl
                .frame(maxWidth: .infinity)
            
            Button(action: onRemove) {
                Image(systemName: "minus")
                    .padding(.vertical, 6)
            }
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .padding(.vertical, 2)
            }
        }
        .onChange(of: rule.field) { _, newField in
            // Kind switch resets to the field's default comparison —
            // otherwise a stale ".contains" survives onto a boolean field.
            if !newField.comparisons.contains(rule.comparison) {
                rule.comparison = newField.comparisons[0]
            }
        }
    }
    
    @ViewBuilder
    private var valueControl: some View {
        switch rule.field.kind {
        case .string:
            TextField("Value", text: $rule.text)
                .textFieldStyle(.roundedBorder)
        case .number:
            TextField("Value", value: $rule.number, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
        case .date:
            DatePicker("Value", selection: $rule.date, displayedComponents: .date)
                .labelsHidden()
        case .result:
            // Three cases, not `allCases`: Decision #3 keeps `*` out of the
            // Library entirely, so a "result is *" rule could only ever match
            // nothing. Offering it would be offering a dead rule.
            Picker("Result", selection: $rule.gameResult) {
                Text(GameResult.whiteWins.rawValue).tag(GameResult.whiteWins)
                Text(GameResult.blackWins.rawValue).tag(GameResult.blackWins)
                Text(GameResult.draw.rawValue).tag(GameResult.draw)
            }
            .labelsHidden()
            .frame(width: 100)
        case .boolean:
            // The comparison IS the value ("is true"/"is false").
            Spacer()
        case .checkmatePattern:
            // `allCases` here, unlike `.result` above: every motif the
            // classifier can produce is a motif a game can carry, so none of
            // them is a dead rule.
            Picker("Mate Pattern", selection: $rule.specialCheckmate) {
                ForEach(SpecialCheckmate.allCases, id: \.self) { pattern in
                    Text(pattern.displayName).tag(pattern)
                }
            }
            .labelsHidden()
            .frame(width: 140)
        }
    }
}

// MARK: Previews

#Preview("New Tag") {
    SmartTagEditorView(draft: TagDraft(), onSave: { _ in })
        .frame(width: 520, height: 420)
}

#Preview("Populated — Match All") {
    var draft = TagDraft()
    draft.name = "Bera's Wins"
    draft.colorName = .green
    draft.matchAll = true
    draft.rules = [
        TagRule(field: .player, comparison: .contains, text: "Bera"),
        TagRule(field: .result, comparison: .equals, gameResult: .whiteWins)
    ]
    return SmartTagEditorView(draft: draft, onSave: { _ in })
        .frame(width: 520, height: 420)
}

/// Every rule *kind* at once (string / result / number / date / boolean /
/// checkmate-pattern) — the row-editor switch renders a different control per
/// kind, so this is the layout's real stress case. It grows a row whenever
/// `Field.Kind` grows a case; a kind missing here is a control nobody ever
/// looked at.
#Preview("All Rule Kinds") {
    var draft = TagDraft()
    draft.name = "Kitchen Sink"
    draft.colorName = .purple
    draft.matchAll = false
    draft.rules = [
        TagRule(field: .event, comparison: .beginsWith, text: "Club"),
        TagRule(field: .opening, comparison: .contains, text: "Sicilian"),
        TagRule(field: .result, comparison: .equals, gameResult: .draw),
        TagRule(field: .moves, comparison: .greaterThan, number: 40),
        TagRule(field: .date, comparison: .after, date: .now),
        TagRule(field: .checkmate, comparison: .isTrue),
        TagRule(field: .matePattern, comparison: .equals, specialCheckmate: .backRank)
    ]
    return SmartTagEditorView(draft: draft, onSave: { _ in })
        .frame(width: 520, height: 520)
}

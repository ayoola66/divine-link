import SwiftUI
import AppKit

// MARK: - Speech Corrections View

/// View for managing a pastor's speech corrections
struct SpeechCorrectionsView: View {
    let pastor: PastorProfile
    @StateObject private var sessionManager = ServiceSessionManager.shared
    @State private var showAddSheet = false
    @State private var showImportPicker = false
    @Environment(\.dismiss) private var dismiss
    
    private var corrections: [SpeechCorrection] {
        sessionManager.pastorProfiles.first { $0.id == pastor.id }?.speechCorrections ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            if corrections.isEmpty {
                emptyState
            } else {
                correctionsList
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 400, height: 400)
        .sheet(isPresented: $showAddSheet) {
            AddCorrectionSheet(pastorId: pastor.id)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Speech Corrections")
                    .font(.headline)
                
                Text(pastor.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Corrections Yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Add corrections when the app mishears this pastor")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Button {
                showAddSheet = true
            } label: {
                Label("Add Correction", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Corrections List
    
    private var correctionsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(corrections.sorted { $0.occurrences > $1.occurrences }, id: \.heard) { correction in
                    CorrectionRowView(correction: correction, pastorId: pastor.id)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Text("\(corrections.count) correction(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Menu {
                Button {
                    exportCorrections()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    importCorrections()
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            
            Button {
                showAddSheet = true
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func exportCorrections() {
        if let url = sessionManager.exportCorrections(for: pastor.id) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    private func importCorrections() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            let count = sessionManager.importCorrections(for: pastor.id, from: url)
            print("[SpeechCorrection] Imported \(count) corrections")
        }
    }
}

// MARK: - Correction Row View

struct CorrectionRowView: View {
    let correction: SpeechCorrection
    let pastorId: UUID
    @StateObject private var sessionManager = ServiceSessionManager.shared
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Correction visual
            HStack(spacing: 8) {
                Text(correction.heard)
                    .font(.body)
                    .foregroundStyle(.red)
                    .strikethrough()
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(correction.corrected)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(correction.occurrences)×")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(correction.lastUsed.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Delete button
            Button {
                showDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .alert("Delete Correction?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                sessionManager.removeCorrection(from: pastorId, heard: correction.heard)
            }
        } message: {
            Text("Remove '\(correction.heard)' → '\(correction.corrected)' correction?")
        }
    }
}

// MARK: - Add Correction Sheet

struct AddCorrectionSheet: View {
    let pastorId: UUID
    @StateObject private var sessionManager = ServiceSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var heard = ""
    @State private var corrected = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Correction")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Fields
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("What you heard")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("e.g., Some", text: $heard)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Correct word")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("e.g., Psalms", text: $corrected)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            // Preview
            if !heard.isEmpty && !corrected.isEmpty {
                HStack {
                    Image(systemName: "eye")
                        .foregroundStyle(.secondary)
                    
                    Text("When pastor says")
                    Text(heard)
                        .foregroundStyle(.red)
                        .strikethrough()
                    Text("→")
                    Text(corrected)
                        .foregroundStyle(.green)
                        .fontWeight(.medium)
                }
                .font(.caption)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    sessionManager.addCorrection(
                        to: pastorId,
                        heard: heard,
                        corrected: corrected
                    )
                    dismiss()
                } label: {
                    Text("Save Correction")
                }
                .buttonStyle(.borderedProminent)
                .disabled(heard.isEmpty || corrected.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 320)
    }
}

// MARK: - Preview

#Preview("Corrections View") {
    SpeechCorrectionsView(pastor: PastorProfile(name: "Pastor John"))
}

#Preview("Add Correction") {
    AddCorrectionSheet(pastorId: UUID())
}

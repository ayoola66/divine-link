import SwiftUI

// MARK: - Service History View

/// Displays a list of past service sessions grouped by month
struct ServiceHistoryView: View {
    @State private var sessions: [ServiceSession] = []
    @State private var selectedSession: ServiceSession?
    @State private var showDeleteConfirmation = false
    @State private var sessionToDelete: ServiceSession?
    
    // Group sessions by month
    private var groupedSessions: [(key: String, sessions: [ServiceSession])] {
        let grouped = Dictionary(grouping: sessions) { session in
            session.date.formatted(.dateTime.month(.wide).year())
        }
        
        // Sort by date (newest first)
        return grouped.map { (key: $0.key, sessions: $0.value) }
            .sorted { first, second in
                guard let firstDate = first.sessions.first?.date,
                      let secondDate = second.sessions.first?.date else {
                    return false
                }
                return firstDate > secondDate
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if sessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .onAppear {
            loadSessions()
        }
        .sheet(item: $selectedSession) { session in
            ServiceDetailView(session: session) {
                loadSessions()
            }
        }
        .alert("Delete Service?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let session = sessionToDelete {
                    deleteSession(session)
                }
            }
        } message: {
            if let session = sessionToDelete {
                Text("Delete \"\(session.name)\"? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Service History")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Completed services will appear here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Sessions List
    
    private var sessionsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedSessions, id: \.key) { group in
                    Section {
                        ForEach(group.sessions) { session in
                            ServiceRowView(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedSession = session
                                }
                                .contextMenu {
                                    Button {
                                        selectedSession = session
                                    } label: {
                                        Label("View Details", systemImage: "eye")
                                    }
                                    
                                    Button {
                                        exportSession(session, format: .json)
                                    } label: {
                                        Label("Export JSON", systemImage: "square.and.arrow.up")
                                    }
                                    
                                    Button {
                                        exportSession(session, format: .csv)
                                    } label: {
                                        Label("Export CSV", systemImage: "tablecells")
                                    }
                                    
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        sessionToDelete = session
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        Text(group.key)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 16)
                            .padding(.bottom, 4)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadSessions() {
        sessions = ServiceArchive.shared.loadAll()
    }
    
    private func deleteSession(_ session: ServiceSession) {
        // Note: ServiceArchive doesn't have delete yet, would need to add
        // For now, just remove from local list
        sessions.removeAll { $0.id == session.id }
    }
    
    private func exportSession(_ session: ServiceSession, format: ExportFormat) {
        let url: URL?
        switch format {
        case .json:
            url = ServiceArchive.shared.exportToJSON(session)
        case .csv:
            url = ServiceArchive.shared.exportToCSV(session)
        }
        
        guard let exportURL = url else { return }
        
        // Open share sheet
        NSWorkspace.shared.activateFileViewerSelecting([exportURL])
    }
}

// MARK: - Export Format

enum ExportFormat {
    case json
    case csv
}

// MARK: - Service Row View

struct ServiceRowView: View {
    let session: ServiceSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 2) {
                Text(session.date.formatted(.dateTime.day()))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(session.date.formatted(.dateTime.weekday(.abbreviated)))
                    .font(.caption2)
                    .textCase(.uppercase)
            }
            .frame(width: 44)
            .foregroundStyle(.blue)
            
            // Session info
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label("\(session.detectedScriptures.count)", systemImage: "book.closed")
                    
                    let pushedCount = session.detectedScriptures.filter(\.wasPushed).count
                    if pushedCount > 0 {
                        Label("\(pushedCount) pushed", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    
                    if let duration = session.duration {
                        let minutes = Int(duration / 60)
                        Label("\(minutes)m", systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
}

// MARK: - Service Detail View

struct ServiceDetailView: View {
    let session: ServiceSession
    var onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showExportOptions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Details section
                    detailsSection
                    
                    Divider()
                    
                    // Scriptures section
                    scripturesSection
                }
                .padding()
            }
        }
        .frame(width: 450, height: 500)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.headline)
                
                Text(session.date.formatted(date: .complete, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Export button
            Menu {
                Button {
                    exportSession(.json)
                } label: {
                    Label("Export as JSON", systemImage: "doc.text")
                }
                
                Button {
                    exportSession(.csv)
                } label: {
                    Label("Export as CSV", systemImage: "tablecells")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            
            Button {
                dismiss()
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session Details")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Type:")
                        .foregroundStyle(.secondary)
                    Text(session.serviceType)
                }
                
                GridRow {
                    Text("Duration:")
                        .foregroundStyle(.secondary)
                    Text(session.formattedDuration)
                }
                
                GridRow {
                    Text("Scriptures:")
                        .foregroundStyle(.secondary)
                    Text("\(session.detectedScriptures.count) detected")
                }
                
                let pushedCount = session.detectedScriptures.filter(\.wasPushed).count
                if pushedCount > 0 {
                    GridRow {
                        Text("Pushed:")
                            .foregroundStyle(.secondary)
                        Text("\(pushedCount) sent to ProPresenter")
                            .foregroundStyle(.green)
                    }
                }
            }
            .font(.callout)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Scriptures Section
    
    private var scripturesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected Scriptures")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if session.detectedScriptures.isEmpty {
                Text("No scriptures were detected in this session")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(session.detectedScriptures) { scripture in
                    ScriptureRowView(scripture: scripture)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func exportSession(_ format: ExportFormat) {
        let url: URL?
        switch format {
        case .json:
            url = ServiceArchive.shared.exportToJSON(session)
        case .csv:
            url = ServiceArchive.shared.exportToCSV(session)
        }
        
        guard let exportURL = url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([exportURL])
    }
}

// MARK: - Scripture Row View

struct ScriptureRowView: View {
    let scripture: DetectedScripture
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status icon
            Image(systemName: scripture.wasPushed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(scripture.wasPushed ? .green : .secondary)
                .font(.title3)
            
            // Scripture info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(scripture.reference)
                        .font(.headline)
                    
                    Text("(\(scripture.translation))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(scripture.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                if !scripture.verseText.isEmpty {
                    Text(scripture.verseText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                if !scripture.rawTranscript.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                        Text("Heard: \"\(scripture.rawTranscript)\"")
                            .font(.caption)
                            .italic()
                    }
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview("History List") {
    ServiceHistoryView()
        .frame(width: 400, height: 500)
}

#Preview("Empty History") {
    ServiceHistoryView()
        .frame(width: 400, height: 500)
}

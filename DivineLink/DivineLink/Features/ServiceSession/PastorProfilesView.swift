import SwiftUI

// MARK: - Pastor Profiles Settings Tab

/// Settings tab for managing pastor profiles
struct PastorProfilesTab: View {
    @StateObject private var sessionManager = ServiceSessionManager.shared
    @State private var showAddSheet = false
    @State private var editingPastor: PastorProfile?
    @State private var pastorToDelete: PastorProfile?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            if sessionManager.pastorProfiles.isEmpty {
                emptyState
            } else {
                profilesList
            }
            
            Divider()
            
            // Footer with add button
            HStack {
                Text("\(sessionManager.pastorProfiles.count) pastor(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    showAddSheet = true
                } label: {
                    Label("Add Pastor", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .sheet(isPresented: $showAddSheet) {
            AddPastorSheet { name in
                _ = sessionManager.addPastor(name: name)
            }
        }
        .sheet(item: $editingPastor) { pastor in
            EditPastorSheet(pastor: pastor) { updatedName in
                updatePastor(pastor.id, name: updatedName)
            }
        }
        .alert("Delete Pastor?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let pastor = pastorToDelete {
                    sessionManager.deletePastor(pastor.id)
                }
            }
        } message: {
            if let pastor = pastorToDelete {
                Text("Delete \"\(pastor.name)\"? Speech corrections will also be deleted.")
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Pastor Profiles")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Add pastor profiles to enable speech learning")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Button {
                showAddSheet = true
            } label: {
                Label("Add First Pastor", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Profiles List
    
    private var profilesList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(sessionManager.pastorProfiles) { pastor in
                    PastorRowView(pastor: pastor)
                        .contextMenu {
                            Button {
                                editingPastor = pastor
                            } label: {
                                Label("Edit Name", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                pastorToDelete = pastor
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Actions
    
    private func updatePastor(_ id: UUID, name: String) {
        if let index = sessionManager.pastorProfiles.firstIndex(where: { $0.id == id }) {
            sessionManager.pastorProfiles[index].name = name
            // Trigger save (need to expose this method)
        }
    }
}

// MARK: - Pastor Row View

struct PastorRowView: View {
    let pastor: PastorProfile
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(pastor.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(pastor.name)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(pastor.servicesCount) services", systemImage: "calendar")
                    Label("\(pastor.speechCorrections.count) corrections", systemImage: "waveform")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Learning indicator
            if !pastor.speechCorrections.isEmpty {
                Image(systemName: "brain")
                    .foregroundStyle(.green)
                    .help("This pastor has learned corrections")
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - Add Pastor Sheet

struct AddPastorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    
    var onAdd: (String) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Add Pastor")
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
            
            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Pastor Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("e.g., Pastor John Smith", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Info
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                
                Text("The app will learn this pastor's speech patterns over time, improving detection accuracy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    onAdd(name)
                    dismiss()
                } label: {
                    Text("Add Pastor")
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 280)
    }
}

// MARK: - Edit Pastor Sheet

struct EditPastorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let pastor: PastorProfile
    @State private var name: String
    
    var onSave: (String) -> Void
    
    init(pastor: PastorProfile, onSave: @escaping (String) -> Void) {
        self.pastor = pastor
        self._name = State(initialValue: pastor.name)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Edit Pastor")
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
            
            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Pastor Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Stats
            if !pastor.speechCorrections.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Learned Corrections")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pastor.speechCorrections.prefix(5), id: \.heard) { correction in
                                HStack(spacing: 4) {
                                    Text(correction.heard)
                                        .strikethrough()
                                        .foregroundStyle(.red)
                                    Image(systemName: "arrow.right")
                                        .font(.caption2)
                                    Text(correction.corrected)
                                        .foregroundStyle(.green)
                                }
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                }
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
                    onSave(name)
                    dismiss()
                } label: {
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 350, height: 320)
    }
}

// MARK: - Preview

#Preview("Pastors Tab") {
    PastorProfilesTab()
        .frame(width: 400, height: 400)
}

#Preview("Add Pastor") {
    AddPastorSheet { name in
        print("Added: \(name)")
    }
}

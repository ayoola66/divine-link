import SwiftUI

// MARK: - New Service Sheet

/// Sheet for creating a new service session
struct NewServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var sessionManager: ServiceSessionManager
    
    @State private var serviceType: String = ""
    @State private var customName: String = ""
    @State private var useCustomName: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var selectedPastorId: UUID?
    @State private var showSuggestions: Bool = false
    
    var onStart: (ServiceSession) -> Void
    
    // MARK: - Computed Properties
    
    private var generatedName: String {
        ServiceSession.defaultName(for: serviceType.isEmpty ? "Service" : serviceType, on: selectedDate)
    }
    
    private var sessionName: String {
        useCustomName ? customName : generatedName
    }
    
    private var canStart: Bool {
        !serviceType.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private var suggestions: [String] {
        sessionManager.serviceTypeSuggestions(for: serviceType)
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    serviceTypeSection
                    dateSection
                    pastorSection
                    nameSection
                }
                .padding()
            }
            
            Divider()
            
            // Actions
            actionButtons
        }
        .frame(width: 400, height: 420)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text("New Service")
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
        .padding()
    }
    
    // MARK: - Service Type Section
    
    private var serviceTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Service Type")
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextField("e.g., Sunday Service", text: $serviceType)
                .textFieldStyle(.roundedBorder)
                .onChange(of: serviceType) { _, newValue in
                    showSuggestions = !newValue.isEmpty && !suggestions.isEmpty
                }
            
            // Suggestions
            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(suggestions.prefix(5), id: \.self) { suggestion in
                        Button {
                            serviceType = suggestion
                            showSuggestions = false
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(suggestion)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.subheadline)
                .fontWeight(.medium)
            
            DatePicker(
                "Service Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }
    
    // MARK: - Pastor Section
    
    private var pastorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pastor (Optional)")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if sessionManager.pastorProfiles.isEmpty {
                HStack {
                    Image(systemName: "person.badge.plus")
                        .foregroundStyle(.secondary)
                    Text("No pastor profiles yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                Picker("Pastor", selection: $selectedPastorId) {
                    Text("None").tag(nil as UUID?)
                    ForEach(sessionManager.pastorProfiles) { pastor in
                        Text(pastor.name).tag(pastor.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Text("Pastor profiles help the app learn speech patterns")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
    
    // MARK: - Name Section
    
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session Name")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Toggle("Custom", isOn: $useCustomName)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            
            if useCustomName {
                TextField("Session name", text: $customName)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(generatedName)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            Button {
                startService()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Service")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func startService() {
        // Cache the service type for future suggestions
        ServiceTypeCache.shared.addType(serviceType)
        
        let session = sessionManager.startSession(
            name: sessionName,
            serviceType: serviceType,
            date: selectedDate,
            pastorId: selectedPastorId
        )
        onStart(session)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NewServiceSheet(sessionManager: ServiceSessionManager.shared) { session in
        print("Started: \(session.name)")
    }
}

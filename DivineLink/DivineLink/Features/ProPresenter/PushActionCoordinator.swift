import SwiftUI
import Combine
import os

// MARK: - Push Result

enum PushResult: Equatable {
    case success(String)
    case failure(String)
    
    static func == (lhs: PushResult, rhs: PushResult) -> Bool {
        switch (lhs, rhs) {
        case (.success(let a), .success(let b)): return a == b
        case (.failure(let a), .failure(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - Push Action Coordinator

/// Coordinates pushing verses to ProPresenter
@MainActor
class PushActionCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isPushing = false
    @Published var lastPushResult: PushResult?
    @Published var showingError = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let ppClient: ProPresenterClient
    private let bufferManager: BufferManager
    private let logger = Logger(subsystem: "com.divinelink", category: "Push")
    
    private var resultClearTask: Task<Void, Never>?
    
    // MARK: - Initialisation
    
    init(ppClient: ProPresenterClient, bufferManager: BufferManager) {
        self.ppClient = ppClient
        self.bufferManager = bufferManager
    }
    
    // MARK: - Push Actions
    
    /// Push a specific verse to ProPresenter
    func pushVerse(_ verse: PendingVerse) async {
        isPushing = true
        lastPushResult = nil
        resultClearTask?.cancel()
        
        do {
            // Format message
            let message = ppClient.formatStageMessage(from: verse)
            
            // Send to ProPresenter
            try await ppClient.sendStageMessage(message)
            
            // Success - mark as pushed in buffer
            bufferManager.markAsPushed(id: verse.id)
            
            logger.info("Successfully pushed: \(verse.displayReference)")
            lastPushResult = .success(verse.displayReference)
            
            // Clear success indicator after delay
            scheduleResultClear()
            
        } catch {
            logger.error("Push failed: \(error.localizedDescription)")
            lastPushResult = .failure(error.localizedDescription)
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isPushing = false
    }
    
    /// Push the current (first) pending verse
    func pushCurrentVerse() async {
        guard let verse = bufferManager.currentVerse else {
            logger.warning("No verse to push")
            return
        }
        
        await pushVerse(verse)
    }
    
    /// Clear the stage message
    func clearStage() async {
        do {
            try await ppClient.clearStageMessage()
            logger.info("Stage cleared")
        } catch {
            logger.error("Failed to clear stage: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Result Management
    
    private func scheduleResultClear() {
        resultClearTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            if !Task.isCancelled {
                lastPushResult = nil
            }
        }
    }
    
    func dismissError() {
        showingError = false
        errorMessage = nil
    }
    
    func retryLastPush() async {
        dismissError()
        await pushCurrentVerse()
    }
}

// MARK: - Push Success Indicator View

struct PushSuccessIndicator: View {
    let reference: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            
            Text("Pushed: \(reference)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .transition(.opacity.combined(with: .scale))
    }
}

// MARK: - Push Error Alert View

struct PushErrorAlert: View {
    @Binding var isPresented: Bool
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("Push Failed")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 12) {
                Button("Dismiss") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Retry") {
                    isPresented = false
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 10)
    }
}

# Story 3.7: Push to ProPresenter Action

**Epic:** 3 - Pending Buffer & ProPresenter Integration  
**Story ID:** 3.7  
**Status:** Not Started  
**Complexity:** Small  

---

## User Story

**As an** operator,  
**I want** approved verses to appear on the ProPresenter stage screen,  
**so that** the congregation can see the scripture.

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Pressing "Push" sends verse to ProPresenter | Verse appears on PP stage |
| 2 | Message format: "{Book} {Chapter}:{Verse}\n{Full Text}" | Format correct on PP |
| 3 | Multi-line text supported | Long verses display correctly |
| 4 | Success removes verse from pending buffer | Buffer updates after push |
| 5 | Failure shows error message in UI | Error toast/message visible |
| 6 | UI shows brief success indicator | Success feedback visible |
| 7 | Next pending verse (if any) becomes active | Queue advances |

---

## Technical Notes

### Push Action Coordinator

```swift
import SwiftUI
import Combine

class PushActionCoordinator: ObservableObject {
    @Published var isPushing = false
    @Published var lastPushResult: PushResult?
    @Published var showingError = false
    @Published var errorMessage: String?
    
    private let ppClient: ProPresenterClient
    private let bufferManager: BufferManager
    private let logger = Logger(subsystem: "com.divinelink", category: "Push")
    
    init(ppClient: ProPresenterClient, bufferManager: BufferManager) {
        self.ppClient = ppClient
        self.bufferManager = bufferManager
    }
    
    func pushCurrentVerse() async {
        guard let verse = bufferManager.currentVerse else {
            logger.warning("No verse to push")
            return
        }
        
        isPushing = true
        lastPushResult = nil
        
        do {
            // Format message
            let message = formatMessage(from: verse)
            
            // Send to ProPresenter
            try await ppClient.sendStageMessage(message)
            
            // Success - remove from buffer
            _ = bufferManager.approveCurrentVerse()
            
            logger.info("Successfully pushed: \(verse.displayReference)")
            lastPushResult = .success(verse.displayReference)
            
        } catch {
            logger.error("Push failed: \(error.localizedDescription)")
            lastPushResult = .failure(error.localizedDescription)
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isPushing = false
        
        // Clear success indicator after delay
        if case .success = lastPushResult {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.lastPushResult = nil
            }
        }
    }
    
    private func formatMessage(from verse: PendingVerse) -> String {
        """
        \(verse.displayReference)
        
        \(verse.fullText)
        """
    }
}

enum PushResult {
    case success(String)
    case failure(String)
}
```

### Success Indicator View

```swift
struct PushSuccessIndicator: View {
    let reference: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text("Pushed: \(reference)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
        .transition(.opacity.combined(with: .scale))
    }
}
```

### Error Alert

```swift
struct PushErrorAlert: View {
    @Binding var isPresented: Bool
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Push Failed")
                .font(.headline)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
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
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}
```

### Integration in Main View

```swift
struct ContentView: View {
    @StateObject private var pushCoordinator: PushActionCoordinator
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Zone 1, 2, 3...
                
                Zone3_ActionButtons(
                    onPush: {
                        Task {
                            await pushCoordinator.pushCurrentVerse()
                        }
                    },
                    onIgnore: handleIgnore
                )
            }
            
            // Success indicator overlay
            if case .success(let ref) = pushCoordinator.lastPushResult {
                VStack {
                    PushSuccessIndicator(reference: ref)
                        .padding(.top, 8)
                    Spacer()
                }
            }
            
            // Error overlay
            if pushCoordinator.showingError, let error = pushCoordinator.errorMessage {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                PushErrorAlert(
                    isPresented: $pushCoordinator.showingError,
                    message: error,
                    onRetry: {
                        Task {
                            await pushCoordinator.pushCurrentVerse()
                        }
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pushCoordinator.lastPushResult != nil)
    }
}
```

---

## Dependencies

- Story 3.1 (Pending Buffer Data Model)
- Story 3.6 (ProPresenter API Client)

---

## Definition of Done

- [ ] All acceptance criteria verified
- [ ] Push sends correct message format
- [ ] Buffer advances after success
- [ ] Success indicator appears briefly
- [ ] Error alert shows on failure
- [ ] Tested with real ProPresenter
- [ ] Committed to Git

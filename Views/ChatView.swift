import SwiftUI
import PhotosUI
import AVFoundation
import UIKit

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    // OPTIMIZATION: Access directly without observation (only method calls, no @Published properties)
    private let realtimeService = RealtimeService.shared
    @State private var text = ""
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingMediaPicker = false
    @State private var selectedMedia: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingMediaOptions = false
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if appState.activeOperationID == nil || appState.activeOperation == nil {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("No active operation")
                        .font(.headline)
                    
                    Text("Join an operation in the Ops tab to start chatting with your team.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            } else {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatMessageBubble(
                                    message: message,
                                    isCurrentUser: message.userID == appState.currentUserID?.uuidString
                                )
                                .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _, _ in
                        // Auto-scroll to bottom when new message arrives
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        // Scroll to bottom on initial load
                        if let lastMessage = messages.last {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                if let error {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
            }

            // Message input - only show when there's an active operation
            if appState.activeOperationID != nil {
                HStack(spacing: 12) {
                    // Media options button
                    Button {
                        print("📷 Camera available: \(CameraPermissionHelper.isCameraAvailable)")
                        showingMediaOptions = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                .confirmationDialog("Add Media", isPresented: $showingMediaOptions) {
                    Button("Take Photo or Video") {
                        print("📸 Opening camera")
                        showingCamera = true
                    }
                    
                    Button("Photo/Video Library") {
                        print("📚 Opening library")
                        showingMediaPicker = true
                    }
                    
                    Button("Cancel", role: .cancel) {}
                } message: {
                    if !CameraPermissionHelper.isCameraAvailable {
                        Text("Camera not available on this device")
                    }
                }
                
                TextField("Type a message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .lineLimit(1...5)
                    .focused($textFieldFocused)
                    .onSubmit {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendMessage()
                        }
                    }
                    .submitLabel(.send)

                Button {
                    sendMessage()
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
            await subscribeToRealtimeChat()
        }
        .onDisappear {
            Task {
                await realtimeService.unsubscribeFromChat()
            }
        }
        .photosPicker(isPresented: $showingMediaPicker, selection: $selectedMedia, maxSelectionCount: 5, matching: .any(of: [.images, .videos]))
        .onChange(of: selectedMedia) { _, newItems in
            if !newItems.isEmpty {
                handleMediaSelection(newItems)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(
                sourceType: .camera,
                mediaTypes: ["public.image", "public.movie"],
                onMediaCaptured: { data, type in
                    handleCameraCapture(data: data, mediaType: type)
                }
            )
            .ignoresSafeArea()
        }
    }
    
    private func sendMessage() {
        guard let operationID = appState.activeOperationID,
              let userID = appState.currentUserID,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ Cannot send message - missing operation ID or user ID")
            return
        }
        
        let messageText = text
        text = ""
        isLoading = true
        error = nil
        
        print("📤 Sending message: '\(messageText)' to operation \(operationID)")
        
        Task {
            do {
                // Save to database (which will trigger Postgres Changes subscription for realtime updates)
                try await DatabaseService.shared.sendMessage(messageText, operationID: operationID, userID: userID)
                print("✅ Message sent successfully")
                
                // Manually reload messages to see if it was saved
                await loadMessages()
            } catch {
                print("❌ Failed to send message: \(error)")
                await MainActor.run {
                    self.error = "Failed to send message: \(error.localizedDescription)"
                    self.text = messageText // Restore message on failure
                    isLoading = false
                }
                return
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadMessages() async {
        guard let operationID = appState.activeOperationID else { return }
        
        do {
            let newMessages = try await DatabaseService.shared.fetchMessages(for: operationID)
            await MainActor.run {
                self.messages = newMessages
                print("📬 Loaded \(newMessages.count) message(s)")
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to load messages: \(error.localizedDescription)"
                print("❌ Failed to load messages: \(error)")
            }
        }
    }
    
    private func subscribeToRealtimeChat() async {
        guard let operationID = appState.activeOperationID else { return }
        
        do {
            try await realtimeService.subscribeToChatMessages(operationId: operationID) { newMessage in
                Task { @MainActor in
                    // Check if message already exists (avoid duplicates)
                    if !messages.contains(where: { $0.id == newMessage.id }) {
                        messages.append(newMessage)
                        
                        // Sort messages by timestamp
                        messages.sort { $0.createdAt < $1.createdAt }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to subscribe to chat: \(error.localizedDescription)"
            }
        }
    }
    
    private func handleCameraCapture(data: Data, mediaType: String) {
        guard let operationID = appState.activeOperationID,
              let userID = appState.currentUserID else {
            print("⚠️ Cannot send media - missing operation ID or user ID")
            return
        }
        
        Task {
            isLoading = true
            
            do {
                print("📸 Processing captured \(mediaType): \(data.count) bytes")
                
                // Map media type to database enum values
                let dbMediaType = mediaType == "video" ? "video" : "photo"
                
                // Determine file extension
                let fileExtension = mediaType == "video" ? "mp4" : "jpg"
                
                // Generate unique filename
                let filename = "\(UUID().uuidString).\(fileExtension)"
                let storagePath = "chat-media/\(operationID.uuidString)/\(filename)"
                
                print("⬆️ Uploading captured \(mediaType) to: \(storagePath)")
                
                // Upload to Supabase Storage
                let uploadedPath = try await SupabaseStorageService.shared.uploadImage(
                    data: data,
                    bucket: "chat-media",
                    path: storagePath
                )
                
                print("✅ Upload successful: \(uploadedPath)")
                
                // Send message with media
                let messageText = dbMediaType == "video" ? "📹 Video" : "📷 Photo"
                try await DatabaseService.shared.sendMessage(
                    messageText,
                    operationID: operationID,
                    userID: userID,
                    mediaPath: uploadedPath,
                    mediaType: dbMediaType
                )
                
                print("✅ Camera media message sent successfully")
                
                // Reload messages
                await loadMessages()
            } catch {
                print("❌ Failed to send camera media: \(error)")
                await MainActor.run {
                    self.error = "Failed to send camera media: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func handleMediaSelection(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        guard let operationID = appState.activeOperationID,
              let userID = appState.currentUserID else {
            print("⚠️ Cannot send media - missing operation ID or user ID")
            return
        }
        
        Task {
            isLoading = true
            
            for item in items {
                do {
                    // Load the media data
                    if let data = try await item.loadTransferable(type: Data.self) {
                        print("📸 Loaded media item: \(data.count) bytes")
                        
                        // Determine media type
                        let mediaType: String
                        let fileExtension: String
                        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                            mediaType = "video"
                            fileExtension = "mp4"
                        } else {
                            mediaType = "photo"
                            fileExtension = "jpg"
                        }
                        
                        // Generate unique filename
                        let filename = "\(UUID().uuidString).\(fileExtension)"
                        let storagePath = "chat-media/\(operationID.uuidString)/\(filename)"
                        
                        print("⬆️ Uploading \(mediaType) to: \(storagePath)")
                        
                        // Upload to Supabase Storage
                        let uploadedPath = try await SupabaseStorageService.shared.uploadImage(
                            data: data,
                            bucket: "chat-media",
                            path: storagePath
                        )
                        
                        print("✅ Upload successful: \(uploadedPath)")
                        
                        // Send message with media
                        let messageText = mediaType == "video" ? "📹 Video" : "📷 Photo"
                        try await DatabaseService.shared.sendMessage(
                            messageText,
                            operationID: operationID,
                            userID: userID,
                            mediaPath: uploadedPath,
                            mediaType: mediaType
                        )
                        
                        print("✅ Media message sent successfully")
                        
                        // Reload messages
                        await loadMessages()
                    }
                } catch {
                    print("❌ Failed to send media: \(error)")
                    await MainActor.run {
                        self.error = "Failed to send media: \(error.localizedDescription)"
                    }
                }
            }
            
            await MainActor.run {
                selectedMedia = []
                isLoading = false
            }
        }
    }
}

// MARK: - Message Bubble

struct ChatMessageBubble: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    @State private var mediaImage: UIImage?
    @State private var isLoadingMedia = false
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Sender name (only for other users)
                if !isCurrentUser {
                    Text(message.userName ?? "Unknown User")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                
                // Message bubble
                VStack(alignment: .leading, spacing: 8) {
                    // Media content (photo or video)
                    if message.mediaType == "photo", let _ = message.mediaPath {
                        if let image = mediaImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: 250, maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if isLoadingMedia {
                            ProgressView()
                                .frame(width: 200, height: 200)
                        }
                    } else if message.mediaType == "video", message.mediaPath != nil {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title)
                            Text("Video message")
                                .font(.subheadline)
                        }
                        .padding(8)
                    }
                    
                    // Text content
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.body)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isCurrentUser ? Color.blue : Color(.systemGray5))
                .foregroundStyle(isCurrentUser ? .white : .primary)
                .cornerRadius(16)
                
                // Timestamp
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .task {
            if message.mediaType == "photo", let mediaPath = message.mediaPath {
                await loadMediaImage(path: mediaPath)
            }
        }
    }
    
    private func loadMediaImage(path: String) async {
        isLoadingMedia = true
        do {
            let image = try await SupabaseStorageService.shared.downloadImage(from: path, bucket: "chat-media")
            await MainActor.run {
                self.mediaImage = image
                self.isLoadingMedia = false
            }
        } catch {
            print("❌ Failed to load media image: \(error)")
            await MainActor.run {
                self.isLoadingMedia = false
            }
        }
    }
}

// MARK: - Camera Permission Helper

struct CameraPermissionHelper {
    static func checkCameraPermission() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    static func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
    
    static var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

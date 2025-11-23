//
//  SpeechRecognizer.swift
//  HealthRestart
//
//  Created by Marcos Barbero on 29/09/2025.
//
import Speech
import AVFoundation
import SwiftUI
import Combine

final class SpeechRecognizer: ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Published properties for SwiftUI to observe
    @Published var recognizedText: String = ""
    @Published var isRecording: Bool = false
    
    init() {
        // Speech recognizer will be created lazily when needed
    }
    
    /// Gets or creates the speech recognizer with the current language
    private func getSpeechRecognizer() -> SFSpeechRecognizer {
        // Always use the current language from LocaleManager
        let languageCode = LocaleManager.shared.currentLanguageCode
        let locale = Locale(identifier: languageCode)
        
        // Create speech recognizer with user's language, fallback to English if unavailable
        if let recognizer = SFSpeechRecognizer(locale: locale) {
            return recognizer
        } else {
            // Fallback to English if the user's language is not supported
            return SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
        }
    }
    
    // Check if the user has authorized the use of speech recognition
    var isAuthorized: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            // Must switch back to main queue to update any UI based on auth status
            Task { @MainActor in
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    print("Speech recognition not authorized: \(authStatus)")
                @unknown default:
                    print("Unknown authorization state")
                }
            }
        }
    }

    func startRecording() throws {
        // Get the speech recognizer with current language
        let recognizer = getSpeechRecognizer()
        
        guard !isRecording, recognizer.isAvailable else { return }
        
        // Store the recognizer for this session
        self.speechRecognizer = recognizer
        
        // 1. Cancel previous task and reset text
        recognitionTask?.cancel()
        self.recognitionTask = nil
        self.recognizedText = ""

        // 2. Setup Audio Session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // 3. Create Request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { throw SpeechRecognitionError.requestFailed }
        recognitionRequest.shouldReportPartialResults = true
        
        // 4. Start Recognition Task
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            var isFinal = false
            
            if let result = result {
                self.recognizedText = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopRecording()
            }
        }

        // 5. Setup Audio Engine Input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // 6. Update state
        isRecording = true
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        speechRecognizer = nil  // Clear the recognizer after use
        isRecording = false
        
        // Final text cleaning (optional)
        if !recognizedText.isEmpty {
            recognizedText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    enum SpeechRecognitionError: Error {
        case requestFailed
    }
}

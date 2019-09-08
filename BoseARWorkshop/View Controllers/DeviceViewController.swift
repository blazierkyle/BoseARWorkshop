//
//  DeviceViewController.swift
//  BoseARWorkshop
//
//  Created by Kyle Blazier on 9/8/19.
//  Copyright © 2019 Kyle Blazier. All rights reserved.
//

import UIKit
import BoseWearable
import AVFoundation

class DeviceViewController: UIViewController {
    
    // MARK: Custom Types
    
    private enum Constants {
        static let audioFileName = "scat-song"
        static let audioFileExtension = "m4a"
    }
    
    private enum FeatureFlags {
        static let changeVolumeWhenLookingRight = true
    }
    
    // MARK: Properties
    
    private let sensorDispatch = SensorDispatch(queue: .main)
    private var token: ListenerToken?
    private var yawOffset: Double?
    
    var session: WearableDeviceSession! {
        didSet {
            session?.delegate = self
        }
    }
    
    // MARK: Audio Session Properties
    
    private lazy var audioEngine = AVAudioEngine()
    private lazy var audioEnvironment = AVAudioEnvironmentNode()
    private lazy var audioPlayer = AVAudioPlayerNode()
    
    // MARK: View Properties
    
    @IBOutlet var playPauseButton: UIButton!
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sensorDispatch.handler = self
        setupAudioEnvironment()
        setupPlayPauseButton()
        setupNotifications()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureSensors()
        listenForWearableEvents()
    }
    
    // MARK: Setup
    
    private func setupPlayPauseButton() {
        playPauseButton.setTitle("START PLAYING", for: .normal)
        playPauseButton.setTitle("STOP PLAYING", for: .selected)
    }
    
    private func configureSensors() {
        session.device?.configureSensors { config in
            config.disableAll()
            config.enable(sensor: .gameRotation, at: ._20ms)
        }
    }
    
    private func listenForWearableEvents() {
        token = session.device?.addEventListener(queue: .main) { [weak self] event in
            self?.receivedWearableDevice(event: event)
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: AVAudioSession.interruptionNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleRouteChange),
                                               name: AVAudioSession.routeChangeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleMediaServicesReset),
                                               name: AVAudioSession.mediaServicesWereResetNotification,
                                               object: nil)
    }
    
    // MARK: Audio Session / Environment
    
    private func setupAudioEnvironment() {
        setupAudioSession()
        
        audioEnvironment.listenerPosition  = AVAudioMake3DPoint(0, 0, -5)
        audioEnvironment.listenerAngularOrientation = AVAudioMake3DAngularOrientation(0.0, 0.0, 0.0)
        audioEngine.attach(audioEnvironment)
        
        let hardwareSampleRate = audioEngine.outputNode.outputFormat(forBus: 0).sampleRate
        guard let audioFormat = AVAudioFormat(standardFormatWithSampleRate: hardwareSampleRate, channels: 2) else { return }
        audioEngine.connect(audioEnvironment, to: audioEngine.outputNode, format: audioFormat)
        audioEnvironment.renderingAlgorithm = .HRTFHQ
        
        // Play sound
        playSound()
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, options: .mixWithOthers)
        } catch {
            print("Error setting audio session category \(error.localizedDescription)")
        }
        
        // Set buffer duration
        try? audioSession.setPreferredIOBufferDuration(0.005)
        
        // Set channels
        let preferredNumberOfChannels = 2
        if audioSession.maximumOutputNumberOfChannels >= preferredNumberOfChannels {
            do {
                try audioSession.setPreferredOutputNumberOfChannels(preferredNumberOfChannels)
            } catch {
                print("Error setting audio session preferred number of channels: \(error.localizedDescription)")
            }
        }
        
        // Activate
        do {
            try audioSession.setActive(true)
        } catch {
            print("Error activating audio session: \(error.localizedDescription)")
        }
    }
    
    private func playSound() {
        audioEngine.attach(audioPlayer)
        audioPlayer.position = AVAudio3DPoint(x: 0.0, y: 0.0, z: -5.0)
        
        guard let audioFileURL = Bundle.main.url(forResource: Constants.audioFileName,
                                                 withExtension: Constants.audioFileExtension) else {
                                                    assertionFailure("Cannot load audio file")
                                                    return
        }
        
        do {
            let audioFile = try AVAudioFile(forReading: audioFileURL,
                                            commonFormat: .pcmFormatFloat32,
                                            interleaved: false)
            audioEngine.connect(audioPlayer,
                                to: audioEnvironment,
                                format: audioFile.processingFormat)
            audioPlayer.scheduleAndLoop(file: audioFile)
        } catch {
            print("PlaySound - error: \(error.localizedDescription)")
        }
    }
    
    // MARK: Event Handling
    
    private func receivedWearableDevice(event: WearableDeviceEvent) {
        switch event {
        case .didResumeWearableSensorService:
            print("did resume sensor service")
        case .didFailToWriteSensorConfiguration(let error):
            print("did fail to write sensor config", error)
        case .didReceiveSensorData(let data):
            print("did receive sensor data", data )
        default:
            break
        }
    }
    
    // MARK: Playback State Management
    
    private func stopPlaying() {
        guard audioEngine.isRunning || audioPlayer.isPlaying else { return }
        // Reset the current head direction
        yawOffset = nil
        audioEngine.stop()
        audioPlayer.stop()
    }
    
    private func startPlaying() {
        do {
            try audioEngine.start()
            audioPlayer.play()
        } catch {
            print("StopPlaying error \(error.localizedDescription)")
        }
    }
    
    // MARK: Actions
    
    @IBAction func startStopPlayerButtonPressed(_ sender: UIButton) {
        sender.isSelected ? stopPlaying() : startPlaying()
        sender.isSelected.toggle()
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }
        
        switch type {
        case .began:
            stopPlaying()
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                startPlaying()
            } else {
                stopPlaying()
            }
        @unknown default:
            fatalError()
        }
    }
    
    @objc private func handleRouteChange(notification: Notification) {
        
    }

    @objc private func handleMediaServicesReset(notification: Notification) {
        stopPlaying()
    }
}

// MARK: - WearableDeviceSessionDelegate

extension DeviceViewController: WearableDeviceSessionDelegate {
    func sessionDidOpen(_ session: WearableDeviceSession) {

    }
    
    func session(_ session: WearableDeviceSession, didFailToOpenWithError error: Error?) {
        print("WearableDeviceSession failed to open with error: \(error?.localizedDescription)")
    }
    
    func session(_ session: WearableDeviceSession, didCloseWithError error: Error?) {
        print("WearableDeviceSession closed with error: \(error?.localizedDescription)")
    }
}

// MARK: - SensorDispatchHandler

extension DeviceViewController: SensorDispatchHandler {
    func receivedGameRotation(quaternion: Quaternion, timestamp: SensorTimestamp) {

        // If needed, use the current yaw as the offset so the sound direction is directly in front
        if yawOffset == nil {
            yawOffset = quaternion.zRotation.degreesFromRadians
        }
        
        var yaw = Float(quaternion.zRotation.degreesFromRadians - yawOffset!)

        // Wrap around whatever the offset could have done, to bring the angle back in range.
        while yaw < -180.0 {
            yaw += 360.0
        }
        
        while yaw > 180 {
            yaw -= 360
        }
        
        let pitch = quaternion.xRotation.floatDegreesFromRadians
        let roll = quaternion.yRotation.floatDegreesFromRadians

        // Update the listener position
        audioEnvironment.listenerAngularOrientation = AVAudioMake3DAngularOrientation(yaw, pitch, roll)
        
        if FeatureFlags.changeVolumeWhenLookingRight {
            audioPlayer.volume = (quaternion.zRotation.degreesFromRadians < 0) ? 0.5 : 1.0
        }
    }
    
    func receivedGesture(type: GestureType, timestamp: SensorTimestamp) {
        print("Receieved gesture \(type.rawValue)!")
    }
}

// MARK: - AVAudioPlayerNode

extension AVAudioPlayerNode {
    func scheduleAndLoop(file: AVAudioFile) {
        // Loop the same file
        func loopCompletionHandler() {
            scheduleFile(file,
                         at: nil,
                         completionHandler: loopCompletionHandler)
        }
        
        // Schedule the original playing of the file with the looping completion handler
        scheduleFile(file,
                     at: nil,
                     completionHandler: loopCompletionHandler)
    }
}

// MARK: - Double

extension Double {
    var degreesFromRadians: Double {
        return self * 180.0 / .pi
    }
    
    var floatDegreesFromRadians: Float {
        return Float(degreesFromRadians)
    }
}

//
//  DeviceViewController.swift
//  BoseARWorkshop
//
//  Created by Kyle Blazier on 9/8/19.
//  Copyright © 2019 Kyle Blazier. All rights reserved.
//

import UIKit
import BoseWearable

class DeviceViewController: UIViewController {
    
    // MARK: Properties
    
    private var token: ListenerToken?
    private let sensorDispatch = SensorDispatch(queue: .main)
    
    var session: WearableDeviceSession! {
        didSet {
            session?.delegate = self
        }
    }
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sensorDispatch.handler = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureSensors()
        listenForWearableEvents()
    }
    
    // MARK: Setup
    
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
        print("in rotation: \(quaternion.zRotation)")
    }
}

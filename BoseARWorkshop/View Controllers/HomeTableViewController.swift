//
//  HomeTableViewController.swift
//  BoseARWorkshop
//
//  Created by Kyle Blazier on 9/8/19.
//  Copyright © 2019 Kyle Blazier. All rights reserved.
//

import UIKit
import BoseWearable

class HomeTableViewController: UITableViewController {
    
    // MARK: Properties
    
    private var mode: ConnectUIMode {
        return connectToLastSwitch.isOn
            ? .connectToLast(timeout: 5)
            : .alwaysShow
    }
    
    // MARK: View Properties
    
    @IBOutlet var connectToLastSwitch: UISwitch!
    
    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    // MARK: Actions
    
    @IBAction func switchToggled(_ sender: UISwitch) {
        
    }
    
    @IBAction func connectButtonTapped(_ sender: UIButton) {
        // Setup intents
        let sensorIntent = SensorIntent(sensors: [.gameRotation, .accelerometer], samplePeriods: [._20ms])
        let gestureIntent = GestureIntent(gestures: [.input])
        
        // Start connection
        BoseWearable.shared.startConnection(mode: mode,
                                            sensorIntent: sensorIntent,
                                            gestureIntent: gestureIntent) { [weak self] result in
                                                guard let self = self else { return }
                                                switch result {
                                                case .success(let session):
                                                    self.showDeviceVC(with: session)
                                                case .failure(let error):
                                                    print("** Error Starting Connection - \(error.localizedDescription) **")
                                                case .cancelled:
                                                    print("** Start Connection Request Cancelled **")
                                                }
            
        }
    }
    
    // MARK: DeviceViewController Management
    
    private func showDeviceVC(with session: WearableDeviceSession) {
        guard let vc = storyboard?.instantiateViewController(withIdentifier: "DeviceViewController") as? DeviceViewController else {
            fatalError("Unable to create 'DeviceViewController' from the Storyboard")
        }
        
        vc.session = session
        navigationController?.pushViewController(vc, animated: true)
    }
}

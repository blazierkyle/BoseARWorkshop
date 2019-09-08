//
//  AppDelegate.swift
//  BoseARWorkshop
//
//  Created by Kyle Blazier on 9/8/19.
//  Copyright © 2019 Kyle Blazier. All rights reserved.
//

import UIKit
import BoseWearable

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupBoseSDK()
        return true
    }
    
    private func setupBoseSDK() {
        #if DEBUG
        BoseWearable.enableCommonLogging()
        #else
        BoseWearable.disableAllLogging()
        #endif
        BoseWearable.configure()
    }
}


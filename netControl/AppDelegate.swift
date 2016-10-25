//
//  AppDelegate.swift
//  netControl
//
//  Created by Ani Sinanaj on 03/10/16.
//  Copyright © 2016 Ani Sinanaj. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var menu: NSMenu!
    @IBOutlet weak var menuitem: NSMenuItem!
    
    let statusItem = NSStatusBar.system().statusItem(withLength: -1)
    
    

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        statusItem.title = "Network";
        statusItem.menu = menu;
        menuitem.title = "Monitor";
        
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    
    @IBAction func buttonAction(_ sender: NSMenuItem) {
        print("Starting monitoring");
        
        let net: NetStats = NetStats();
        net.start();
        
    }

}


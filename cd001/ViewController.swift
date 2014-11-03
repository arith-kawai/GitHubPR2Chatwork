//
//  ViewController.swift
//  cd001
//
//  Created by arith11 on 2014/11/03.
//  Copyright (c) 2014年 arith11. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    var appDelegate: AppDelegate = {
        return NSApplication.sharedApplication().delegate as AppDelegate!
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel? = {
        let appDelegate: AppDelegate = NSApplication.sharedApplication().delegate as AppDelegate!
        return appDelegate.managedObjectModel
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext? = {
        let appDelegate: AppDelegate = NSApplication.sharedApplication().delegate as AppDelegate!
        return appDelegate.managedObjectContext
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


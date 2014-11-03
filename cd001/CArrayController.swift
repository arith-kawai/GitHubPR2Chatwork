//
//  ArrayController.swift
//  cd001
//
//  Created by arith11 on 2014/11/03.
//  Copyright (c) 2014年 arith11. All rights reserved.
//

import Foundation
import Cocoa

class CArrayController : NSArrayController {
    
    @IBAction func startPolling(sender: AnyObject) {
        if let mobj: NSManagedObject = self.selectedObjects[0] as? NSManagedObject {
            //PollingManager
            //println(mobj)
            PollingManager.sharedInstance.startPolling(mobj)
        }
    }
    
    @IBAction func stopPolling(sender: AnyObject) {
        if let mobj: NSManagedObject = self.selectedObjects[0] as? NSManagedObject {
            //PollingManager
            //println(mobj)
            PollingManager.sharedInstance.stopPolling(mobj)
        }
    }
}

class PollingManager : NSObject {
    //シングルトン！
    class var sharedInstance :PollingManager {
        struct Static {
            static let instance = PollingManager()
        }
        return Static.instance
    }
    
    var polls: NSMutableDictionary = NSMutableDictionary()
    func startPolling(managedObject: NSManagedObject){
        //println(managedObject)
        if let poller: GitHubPoller = polls.objectForKey(managedObject.objectID) as? GitHubPoller {
            if poller.timer == nil {
               poller.start()
            }
        } else {
            polls.setObject(GitHubPoller(managedObject: managedObject).start(), forKey: managedObject.objectID)
        }
    }
    
    func stopPolling(managedObject: NSManagedObject){
        if let poller: GitHubPoller = polls.objectForKey(managedObject.objectID) as? GitHubPoller {
            if poller.timer != nil {
                poller.stop()
            }
        }
    }
}

class GitHubPoller : NSObject, NSURLConnectionDelegate {
    let managedObject: NSManagedObject
    var timer: NSTimer?
    
    init(managedObject: NSManagedObject){
        self.managedObject = managedObject
        super.init()
    }
    
    func start() -> GitHubPoller {
        
//        var timer: NSTimer = NSTimer(
//            timeInterval: 5.0,
//            target: <#AnyObject#>,
//            selector: <#Selector#>,
//            userInfo: <#AnyObject?#>,
//            repeats: true
//        )
        timer = NSTimer.scheduledTimerWithTimeInterval(
            4.0,
            target: self,
            selector: "pollGithubApi",
            userInfo: nil,
            repeats: true
        )
        
        return self
    }
    
    func stop() -> GitHubPoller {
        timer?.invalidate()
        timer = nil
        return self
    }
    
    func pollGithubApi() {
        let reposOwner: String = managedObject.valueForKey("reposOwner") as String
        let reposName: String = managedObject.valueForKey("reposName") as String
        let githubUserName: String = managedObject.valueForKey("githubUserName") as String
        let githubUserToken: String = managedObject.valueForKey("githubUserToken") as String
        
        let url = NSURL(string: "https://api.github.com/repos/\(reposOwner)/\(reposName)")
        
        let request: NSMutableURLRequest = NSMutableURLRequest(
            URL: url!,
            cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy,
            timeoutInterval: 30.0
        )
        
        //base64encode for auth header
        let headerValue = githubUserToken + ":" + githubUserToken
        let plainData = (headerValue as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        let encodedData = plainData?.base64EncodedDataWithOptions(NSDataBase64EncodingOptions.EncodingEndLineWithLineFeed)
        let decodedString = NSString(data: encodedData!, encoding: NSUTF8StringEncoding)
        println(decodedString)
        request.addValue("Basic " + decodedString! , forHTTPHeaderField: "Authorization")
        
        NSURLConnection.sendAsynchronousRequest(
            request,
            queue: NSOperationQueue.mainQueue(),//処理が途中で消えないようにメインスレッドに委譲
            completionHandler: self.fetchResponse)
    }
    
    func fetchResponse(res: NSURLResponse!, data: NSData!, error: NSError!) {
        if error != nil {
            println(error)
            println(res)
            return
        }
        
        // responseをjsonに変換
        var jError: NSErrorPointer = nil
        var json: NSDictionary = NSJSONSerialization.JSONObjectWithData(
            data,
            options: nil,
            error: jError
        ) as NSDictionary
        
        if jError != nil {
            println(jError)
            println(res)
            return
        }
        
        println(json.valueForKey("clone_url"))
    }
}
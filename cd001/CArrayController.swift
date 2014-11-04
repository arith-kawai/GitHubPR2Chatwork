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
    var pullRequests: NSMutableDictionary = NSMutableDictionary()
    
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
            10.0,
            target: self,
            selector: "requestGithubPullRequests",
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
    
    var githubPullRequestListAPIURL: NSURL {
        let reposOwner: String = managedObject.valueForKey("reposOwner") as String
        let reposName: String = managedObject.valueForKey("reposName") as String
        return NSURL(string: "https://api.github.com/repos/\(reposOwner)/\(reposName)/pulls")!
    }
    
    var githubAuthHeaderValue: String {
        let githubUserName: String = managedObject.valueForKey("githubUserName") as String
        let githubUserToken: String = managedObject.valueForKey("githubUserToken") as String
        //base64encode for auth header
        let headerValue = githubUserToken + ":" + githubUserToken
        let plainData = (headerValue as NSString).dataUsingEncoding(NSUTF8StringEncoding)
        let encodedData = plainData?.base64EncodedDataWithOptions(NSDataBase64EncodingOptions.EncodingEndLineWithLineFeed)
        let decodedString = NSString(data: encodedData!, encoding: NSUTF8StringEncoding)
        return "Basic " + decodedString!
    }
    
    func requestGithubPullRequests() {
        let request: NSMutableURLRequest = NSMutableURLRequest(
            URL: githubPullRequestListAPIURL,
            cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy,
            timeoutInterval: 30.0
        )
        //Authヘッダ追加
        request.addValue(githubAuthHeaderValue , forHTTPHeaderField: "Authorization")
        
        NSURLConnection.sendAsynchronousRequest(
            request,
            queue: NSOperationQueue.mainQueue(),//処理が途中で消えないようにメインスレッドに委譲
            completionHandler: self.fetchPullRequests)
    }
    
    func fetchPullRequests(res: NSURLResponse!, data: NSData!, error: NSError!) {
        if error != nil {
            println(error)
            println(res)
            return
        }
        
        // responseをjsonに変換
        var jError: NSErrorPointer = nil
        var json: NSArray = NSJSONSerialization.JSONObjectWithData(
            data,
            options: nil,
            error: jError
        ) as NSArray
        
        if jError != nil {
            println(jError)
            println(res)
            return
        }
        
        //Get Unix Epoch Time
        let timestamp: NSTimeInterval = NSDate().timeIntervalSince1970
        
        println(timestamp)
        
        for data in json {
            if let prNumber = data.valueForKey("number") as? NSNumber {
                
                if var pullRequest: NSMutableDictionary = pullRequests.objectForKey(prNumber) as? NSMutableDictionary {
                    //println("exist:\(prNumber)")
                    pullRequest["timestamp"] = timestamp
                    pullRequest["data"] = data
                    
                    var cnt:Int = (pullRequest["pollingCount"] as Int) + 1
                    pullRequest["pollingCount"] = cnt
                    
                    //polling5回ごとに
                    if cnt % 6 == 0 {
                        postMessage2ChatworkAPI(pullRequest)
                    }
                    
                } else {
                    //println("new:\(prNumber)")
                    println(pullRequests.objectForKey(prNumber))
                    var pullRequest: NSMutableDictionary = [
                        "pullRequstNumber" : prNumber,
                        "pollingCount" : 0,
                        "timestamp" : timestamp,
                        "data" : data
                    ]
                    pullRequests.setObject(pullRequest, forKey: prNumber)
                    postMessage2ChatworkAPI(pullRequest)
                }
                
            }
        }
    }
    
    var chatworkPostMessage2APIURL: NSURL {
        if let chatWorkRoomId: String = managedObject.valueForKey("chatWorkRoomId") as? String {
            return NSURL(string: "https://api.chatwork.com/v1/rooms/\(chatWorkRoomId)/messages")!
        }
        return NSURL(string: "https://api.chatwork.com/v1/rooms/invalid/messages")!
    }
    
    func postMessage2ChatworkAPI(data:NSMutableDictionary!){
        //see http://developer.chatwork.com/ja/endpoint_rooms.html#GET-rooms-room_id-messages-message_id

        let d = data.objectForKey("data") as NSMutableDictionary
        let dTitle = d.objectForKey("title") as String
        let dHtmlUrl = d.objectForKey("html_url") as String
        
        let rawData = "body=" + "[info][title]\(dTitle)[/title]\(dHtmlUrl)\r\n[/info]".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
        println(rawData)
        
        let request: NSMutableURLRequest = NSMutableURLRequest(
            URL: chatworkPostMessage2APIURL,
            cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy,
            timeoutInterval: 30.0
        )
        request.HTTPMethod = "POST"
        request.HTTPBody = rawData.dataUsingEncoding(NSUTF8StringEncoding)
        
        //X-ChatWorkTokenヘッダ追加
        request.addValue(managedObject.valueForKey("chatWorkToken") as? String , forHTTPHeaderField: "X-ChatWorkToken")
        
        NSURLConnection.sendAsynchronousRequest(
            request,
            queue: NSOperationQueue.mainQueue(),//処理が途中で消えないようにメインスレッドに委譲
            completionHandler: self.fetchChatworkMessagePostResult)
    }
    
    func fetchChatworkMessagePostResult(res: NSURLResponse!, data: NSData!, error: NSError!) {
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
        
        println(json.objectForKey("message_id"))
    }
}
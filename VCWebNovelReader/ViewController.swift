//
//  ViewController.swift
//  VCWebNovelReader
//
//  Created by victor on 2022/8/29.
//

import UIKit
import WebKit
import Kanna

//let bookContentURLString = "https://m.hetubook.com/book/9/5872.html"
let bookContentURLString = "https://t.hjwzw.com/Read/8704_3121898"

class VCReaderContentViewController: UIViewController,WKNavigationDelegate {
    @IBOutlet weak var readerWebView: WKWebView!
    @IBOutlet weak var readerTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        readerWebView.navigationDelegate = self
        
        let bookContentURL = URL(string: bookContentURLString)
        print("before request")
        let request = URLRequest(url: bookContentURL!)
        print("after request")
        readerWebView.load(request)
        print("after load")

    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        print("didCommit")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish")
        getHTML()
    }
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation")
    }
    
    func getHTML() {
        readerWebView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
            
            let htmlString:String = html as! String
            
//            print(htmlString)
            
            
            if let doc = try? HTML(html: htmlString, encoding: .utf8) {
                print(doc.title)
                
                // get content
                var contentString = ""
                for p in doc.xpath("//div[@id='Lab_Contents']") {
                    contentString += p.text!
                }
                print(contentString)
            }
        })
    }

}


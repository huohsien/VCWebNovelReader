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
let bookContentURLString = "https://t.hjwzw.com/Read/8704_3156957"

class VCReaderContentViewController: UIViewController,WKNavigationDelegate {
    
//    @IBOutlet weak var readerWebView: WKWebView!
    @IBOutlet weak var readerTextView: UITextView!

    var _textLineSpacing:CGFloat = 5.0
    var _charactersSpacing:CGFloat = 2.5
    var _chapterContentFontSize:CGFloat = 26.0
    
    
    let readerWebView = WKWebView.init(frame: .zero)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        readerWebView.navigationDelegate = self
        readerTextView.text = "Loading..."
        
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
                for p in doc.xpath("//div[@id='Lab_Contents']/p") {
                    let pp = p.text!.trimmingCharacters(in: .whitespaces)
                    print("str= \(pp)")
                    contentString += pp
                }
                
                
                self.readerTextView.attributedText = self.createAttributiedChapterContentStringFrom(string: contentString)
//                self.readerTextView.attributedText = self.createAttributiedChapterContentStringFrom(string: "你好\n你老母\n")

            }
        })
    }
    
    func createAttributiedChapterContentStringFrom(string:String)->NSAttributedString {
        
        let workingAttributedString = NSMutableAttributedString.init(string: string)
        let paragraphStyle = NSMutableParagraphStyle.init()
        paragraphStyle.lineSpacing = _textLineSpacing;
        paragraphStyle.firstLineHeadIndent = _chapterContentFontSize * 2.0 + _charactersSpacing * 3.0;
        paragraphStyle.alignment = .justified;
        let font = UIFont.systemFont(ofSize: _chapterContentFontSize)

        
        let backgroundColor = UIColor.clear
        let foregroundColor = UIColor.init(red: 102 / 255.0, green: 102 / 255.0, blue: 102 / 255.0, alpha: 1.0)
        
        let attributionDict = [NSAttributedString.Key.paragraphStyle: paragraphStyle, NSAttributedString.Key.font: font, NSAttributedString.Key.backgroundColor: backgroundColor, NSAttributedString.Key.foregroundColor: foregroundColor]
        
        workingAttributedString.addAttributes(attributionDict, range: NSMakeRange(0, string.count))
        workingAttributedString.addAttribute(NSAttributedString.Key.kern, value: _charactersSpacing, range: NSMakeRange(0,string.count))
        
        let attributedString = NSAttributedString.init(attributedString: workingAttributedString)
        return attributedString;
    }

}


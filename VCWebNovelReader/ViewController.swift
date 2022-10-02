//
//  ViewController.swift
//  VCWebNovelReader
//
//  Created by victor on 2022/8/29.
//

import UIKit
import WebKit
import Kanna

let CURRENT_URL_KEY = "CURRENT_URL_KEY"
let CURRENT_TEXTVIEW_OFFSET_KEY = "CURRENT_TEXTVIEW_OFFSET_KEY"

//var bookContentURLString = "https://m.hetubook.com/book/9/5946.html"
//var bookContentURLString = "https://t.hjwzw.com/Read/24632_3184978"
//var bookContentURLString = "https://t.hjwzw.com/Read/8704_3701921"
//var bookContentURLString = "https://t.hjwzw.com/Read/35619_11196308"

var bookContentURLString = "https://t.hjwzw.com/Read/36219_13922908"

var readerTextViewOffset:CGFloat = 0.0
var didJustLaunch = true
let defaults = UserDefaults.standard

class VCReaderContentViewController: UIViewController,WKNavigationDelegate, UITextViewDelegate {
    
    @IBOutlet weak var readerTextView: UITextView!
    
    let _textLineSpacing:CGFloat = 8.0
    let _charactersSpacing:CGFloat = 2.5
    let _chapterContentFontSize:CGFloat = 26.0
    var isLoadingNewPage = false
    
    let _backgroundColor = UIColor.init(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 28.0 / 255.0, alpha: 1.0)
    let _foregroundColor = UIColor.init(red: 180.0 / 255.0, green: 180.0 / 255.0, blue: 180.0 / 255.0, alpha: 1.0)
    
    let readerWebView = WKWebView.init(frame: .zero)

    func uniqueBookOf(urlString: String)->String {
        // 黃金屋
        
        print("urlString=\(urlString)")
        
        let strs = urlString.components(separatedBy: "_")
        let uniqueBookUrlString = strs[0]
        
        print("uniqueBookUrlString=\(uniqueBookUrlString)")
        return uniqueBookUrlString
    }
    
    func syncState() {
        print("sync state")
        
        var storedCurrentUrl = defaults.string(forKey: CURRENT_URL_KEY + uniqueBookOf(urlString: bookContentURLString))
        if storedCurrentUrl == nil {
            print("storing url:\(bookContentURLString)")
            defaults.set(bookContentURLString, forKey: CURRENT_URL_KEY + uniqueBookOf(urlString: bookContentURLString))
            storedCurrentUrl = bookContentURLString
            print("init url \(bookContentURLString)")
        } else {
            print("loaded url:\(storedCurrentUrl!)")
            if didJustLaunch {
                bookContentURLString = storedCurrentUrl!
            }
        }
        
        if storedCurrentUrl != bookContentURLString {
            print("storing url:\(bookContentURLString)")
            defaults.set(bookContentURLString, forKey: CURRENT_URL_KEY + uniqueBookOf(urlString: bookContentURLString))
        }
        didJustLaunch = false
    }
    
    func loadTextViewOffset() {
        
//        let storedTextViewOffset = defaults.float(forKey: CURRENT_TEXTVIEW_OFFSET_KEY)
//        if storedTextViewOffset != 0 {
//            print("storedTextViewOffset:\(storedTextViewOffset)")
//            readerTextViewOffset = CGFloat(storedTextViewOffset)
//        }
    }
    func storeTextViewOffset() {

//        print("scrolling offset was stored")
//        defaults.set(Float(readerTextView.contentOffset.y), forKey: CURRENT_TEXTVIEW_OFFSET_KEY)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        self.view.backgroundColor = _backgroundColor
        self.readerTextView.backgroundColor = _backgroundColor
        syncState()
        loadTextViewOffset()
        
        readerWebView.navigationDelegate = self
        readerTextView.text = "Loading..."
        readerTextView.delegate = self
        readerWebView.frame = .zero
        
        isLoadingNewPage = true
        let bookContentURL = URL(string: bookContentURLString)
        let request = URLRequest(url: bookContentURL!)
        readerWebView.load(request)

    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
//        print("didCommit")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish")
        bookContentURLString = readerWebView.url!.absoluteString
        syncState()
        
        isLoadingNewPage = false
        getHTML()
    }

    
    func getHTML() {
        readerWebView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
            
            let htmlString:String = html as! String
            
//            print(htmlString)
            
            
            if let doc = try? HTML(html: htmlString, encoding: .utf8) {
                // get content
                var contentString = ""
                let chapterTitle:String = doc.title!
                    contentString = chapterTitle + "\n\n"
                
                // 黃金屋
                
                for p in doc.xpath("//div[@id='Lab_Contents']/p") {
                    let pp = p.text!.trimmingCharacters(in: .whitespaces)
//                    print("str= \(pp)")
                    contentString += pp
                }
                
                
                // 和圖書
                /*
                for div in doc.xpath("//dd[@id='content']/div") {
                    let pDiv = div.text!.trimmingCharacters(in: .whitespaces)
                    print("str= \(pDiv)")
                    contentString += pDiv
                    contentString += "\n"
                }
                */
                
                for i in 1...20 {
                    contentString += "\n"
                }
                self.readerTextView.attributedText = self.createAttributiedChapterContentStringFrom(string: contentString)
                self.loadTextViewOffset()
                self.readerTextView.setContentOffset(CGPoint(x:0, y: readerTextViewOffset), animated: false)

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
        
        let attributionDict = [NSAttributedString.Key.paragraphStyle: paragraphStyle, NSAttributedString.Key.font: font, NSAttributedString.Key.backgroundColor: _backgroundColor, NSAttributedString.Key.foregroundColor: _foregroundColor]
        
        workingAttributedString.addAttributes(attributionDict, range: NSMakeRange(0, string.count))
        workingAttributedString.addAttribute(NSAttributedString.Key.kern, value: _charactersSpacing, range: NSMakeRange(0,string.count))
        
        let attributedString = NSAttributedString.init(attributedString: workingAttributedString)
        return attributedString;
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        storeTextViewOffset()
        
        if (scrollView.contentOffset.y >= scrollView.contentSize.height - scrollView.frame.size.height && isLoadingNewPage == false) {
            isLoadingNewPage = true
            print( "View scrolled to the bottom. Load the next chapter" )
            
            readerTextViewOffset = 0.0
            // 黃金屋
            
            readerWebView.evaluateJavaScript("JumpNext();", completionHandler: nil)
            
            
            // 和圖書
            
            
            readerTextView.text = ""
            self.readerTextView.setContentOffset(.zero, animated: false)
        }
    }
    
}


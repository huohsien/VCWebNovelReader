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

var bookContentURLString = "https://t.hjwzw.com/Read/35500_8947147"

var didJustLaunch = true
let defaults = UserDefaults.standard
var fullScreenSize:CGSize = .zero

class VCReaderContentViewController: UIViewController,WKNavigationDelegate,UITextViewDelegate {
    
    @IBOutlet weak var pageContentView: UIView!
    @IBOutlet weak var bookPageScrollContentView: UIView!
    @IBOutlet weak var bookPageScrollView: UIScrollView!
    
    // touch
    var _lastTouchedPointX:CGFloat = 0.0
    var _lastTouchedPointY:CGFloat = 0.0
    var _startTime:CFTimeInterval = 0.0
    var _elapsedTime:CFTimeInterval = 0.0
    var _previousOffset:CGFloat = 0.0
    var _deltaOffset:CGFloat = 0.0
    
    
    var pageTextViews = [VCTextView]()
    
    let _textLineSpacing:CGFloat = 10.0
    let _charactersSpacing:CGFloat = 0.5
    let _chapterContentFontSize:CGFloat = 27.0
    var isLoadingNewPage = false
    
    let _backgroundColor = UIColor.init(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 26.0 / 255.0, alpha: 1.0)
    let _foregroundColor = UIColor.init(red: 178.0 / 255.0, green: 178.0 / 255.0, blue: 178.0 / 255.0, alpha: 1.0)
    
    let readerWebView = WKWebView.init(frame: .zero)

    var pageNumber = 0
    var chapterNumber = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        fullScreenSize = UIScreen.main.bounds.size
        
        bookPageScrollView.delegate = self
        
        self.view.backgroundColor = _backgroundColor
        self.bookPageScrollView.backgroundColor = _backgroundColor
        self.bookPageScrollContentView.backgroundColor = _backgroundColor
        self.pageContentView.backgroundColor = .clear
    
        syncState()
        
        readerWebView.navigationDelegate = self

        readerWebView.frame = .zero
        
        isLoadingNewPage = true
        let bookContentURL = URL(string: bookContentURLString)
        let request = URLRequest(url: bookContentURL!)
        readerWebView.load(request)

    }

// MARK: - wkwebview delegates
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
//        print("didCommit")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish")
        bookContentURLString = readerWebView.url!.absoluteString
        syncState()
        
        isLoadingNewPage = false
        generateTextViewsFromWebResponse()
    }

// MARK: - Flows of Navigation on Reading
    
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
    
    func loadNextChapter() {
        
        // 黃金屋
        readerWebView.evaluateJavaScript("JumpNext();", completionHandler: nil)
        
        // 和圖書
        
    }
    
// MARK: - Functions for Content Creation

    func generateTextViewsFromWebResponse() {
        
        readerWebView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
            
            let htmlString:String = html as! String
                        
            if let doc = try? HTML(html: htmlString, encoding: .utf8) {
                // get content
                var contentString = ""
                let chapterTitle:String = doc.title!
                    contentString = chapterTitle + "\n\n"
                
                // 黃金屋
                
                for p in doc.xpath("//div[@id='Lab_Contents']/p") {
                    let pp = p.text!.trimmingCharacters(in: .whitespaces)
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
                
                let attributedText = self.createAttributiedChapterContentStringFrom(string: contentString)
                self.renderTextPagesFrom(contenAttributedString:attributedText)
                
                for i in 0..<self.pageTextViews.count {
                    self.pageTextViews[i].frame = CGRect(x: self.horizontalMargin(), y: CGFloat(i) * fullScreenSize.height + self.verticalMargin(), width: self.pageContentWidth(), height: self.pageContentHeight())
                    self.bookPageScrollContentView.addSubview(self.pageTextViews[i])
                }
            }
        })
    }
    

    func renderTextPagesFrom(contenAttributedString: NSAttributedString) {
        let textStorage = NSTextStorage(attributedString: contenAttributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let rect = self.pageContentView.frame
        var range:NSRange = NSRange(location: 0, length: 0)
        var numberOfPages:Int = 0
        
        while(NSMaxRange(range) < layoutManager.numberOfGlyphs) {
            let textContainer = NSTextContainer(size: rect.size)
            layoutManager.addTextContainer(textContainer)
            range = layoutManager.glyphRange(for: textContainer)
            
            let pageTextView = VCTextView(frame: rect, textContainer: textContainer, responder: self)
            pageTextView.backgroundColor = _backgroundColor
            pageTextView.isEditable = false
            pageTextView.isScrollEnabled = false
            pageTextViews.append(pageTextView)
            numberOfPages += 1
        }
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
    
// MARK: - Functions for Navigation on Reading
    
    func removeAllPageTextViews() {
        for view in bookPageScrollContentView.subviews {
            if let temp = view as? VCTextView {
                temp.removeFromSuperview()
            }
        }
    }
    
    func showPageWithScrollOffsetByUserTouch() {
        
        for i in 0..<pageTextViews.count {
            let pageTextView = pageTextViews[i]
            pageTextView.frame = CGRectMake(pageTextView.frame.origin.x, pageTextView.frame.origin.y + _deltaOffset, pageTextView.frame.size.width, pageTextView.frame.size.height)
        }

    }
    
    func swipeUp() {
        
        pageNumber += 1
        if pageNumber >= pageTextViews.count {
            pageNumber = 0
            
            removeAllPageTextViews()
            pageTextViews = [VCTextView]()
            loadNextChapter()
            return
        }
        
        let animationOptions: UIView.AnimationOptions = .curveEaseIn
        UIView.animate(withDuration: 0.15, delay: 0.0, options: animationOptions, animations: {
            self.showTheCurrentPage()
            
        }, completion: { (finished: Bool) in
            print("current Page Number: \(self.pageNumber+1) Total number of Page: \(self.pageTextViews.count)")
        })
    }
    
    func swipeDown() {
        
        pageNumber -= 1
        if pageNumber < 0 {
            pageNumber = 0
        }
        
        let animationOptions: UIView.AnimationOptions = .curveEaseIn
        UIView.animate(withDuration: 0.15, delay: 0.0, options: animationOptions, animations: {
            self.showTheCurrentPage()
            
        }, completion: { (finished: Bool) in
            print("current Page Number: \(self.pageNumber+1) Total number of Page: \(self.pageTextViews.count)")
        })
    }
    
    func showTheCurrentPage() {
        for i in 0..<pageTextViews.count {
            var index = i - pageNumber
            
            let fullPageHeight = pageContentHeight() + 2 * verticalMargin()
            let pageTextView = pageTextViews[i]
            pageTextView.frame = CGRectMake(pageTextView.frame.origin.x, CGFloat(index) * fullPageHeight + verticalMargin(), pageContentWidth(), pageContentHeight())
        
        }
    }
// MARK: - Functions for Touch Interactions

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
//        print("touchesBegan")
        
        if let touch = touches.first {
            let point = touch.location(in: self.view)
            _previousOffset = 0;
            _deltaOffset = 0;
            _lastTouchedPointX = point.x;
            _lastTouchedPointY = point.y;
            _startTime = CACurrentMediaTime();
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
//        print("touchesMoved")

        if let touch = touches.first {
            let point = touch.location(in: self.view)
            
            _elapsedTime = CACurrentMediaTime() - _startTime;
            

            let pointY:CGFloat = point.y;
            let yDisplacement:CGFloat = (pointY - _lastTouchedPointY);

            _deltaOffset = yDisplacement - _previousOffset;
            
            showPageWithScrollOffsetByUserTouch()

            _previousOffset = yDisplacement;
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
//        print("touchesEnded")

        if let touch = touches.first {
            let point = touch.location(in: self.view)

            let pointX:CGFloat = point.x;
            let pointY:CGFloat = point.y;
            let xDisplacement:CGFloat = (pointX - _lastTouchedPointX);
            let yDisplacement:CGFloat = (pointY - _lastTouchedPointY);
            
            
            if (yDisplacement < -10 && xDisplacement < 300) {
                swipeUp()
            }
            if (yDisplacement > 10 && xDisplacement < 300) {
                swipeDown()
            }
        }
    }

// MARK: - Tools for Convenience
        
    func pageContentWidth()->CGFloat {
        return self.pageContentView.frame.width
    }

    func pageContentHeight()->CGFloat {
        return self.pageContentView.frame.height
    }
    
    func horizontalMargin()->CGFloat {
        let pageContentWidth = self.pageContentView.frame.width

        return (fullScreenSize.width - pageContentWidth) / 2.0
    }
    
    func verticalMargin()->CGFloat {
        let pageContentHeight = self.pageContentView.frame.height

        return (fullScreenSize.height - pageContentHeight) / 2.0
    }
    
// MARK: - Tools for Generalization
    
    func uniqueBookOf(urlString: String)->String {
        // 黃金屋
        
        print("urlString=\(urlString)")
        
        let strs = urlString.components(separatedBy: "_")
        let uniqueBookUrlString = strs[0]
        
        print("uniqueBookUrlString=\(uniqueBookUrlString)")
        return uniqueBookUrlString
    }
}


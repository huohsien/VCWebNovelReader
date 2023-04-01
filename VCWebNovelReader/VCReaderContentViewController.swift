//
//  ViewController.swift
//  VCWebNovelReader
//
//  Created by victor on 2022/8/29.
//

import UIKit
import WebKit
import Kanna
import CloudKit

let CURRENT_CHAPTER_URL_KEY = "CURRENT_CHAPTER_URL_KEY"
let CURRENT_PAGE_NUMBER_KEY = "CURRENT_PAGE_NUMBER_KEY"
let PREVIOUS_NUMBER_PAGES_KEY = "PREVIOUS_NUMBER_PAGES_KEY"


var defaultBookContentURLString = "https://sj.uukanshu.com/read.aspx?tid=197450&sid=188110"
let isInitialRun = false

var cloudStore = NSUbiquitousKeyValueStore.default

var fullScreenSize:CGSize = .zero


    

extension String {

   func removePTag() -> String {

       let workingString = self.replacingOccurrences(of: "<p[^>]+>", with: "", options: String.CompareOptions.regularExpression, range: nil)
       return workingString.replacingOccurrences(of: "</p>", with: "", options: String.CompareOptions.regularExpression, range: nil)

    }
    func removeRemarkTag() -> String {
        
        return self.replacingOccurrences(of: "<![^>]+>", with: "", options: String.CompareOptions.regularExpression, range: nil)
        
    }

}

class VCReaderContentViewController: UIViewController,WKNavigationDelegate,UITextViewDelegate {
    enum WebNovelSource {
        case 黃金屋
        case uu看書
    }
    
    private let database = CKContainer(identifier: "iCloud.com.VHHC.VCWebNovelReader").publicCloudDatabase
    
    @IBOutlet weak var pageContentView: UIView!
    @IBOutlet weak var bookPageScrollContentView: UIView!
    @IBOutlet weak var bookPageScrollView: UIScrollView!
    @IBOutlet weak var webLoadingActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var pageNumberLabel: UILabel!
    
    let webNovelSource:WebNovelSource = .uu看書
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
    let _chapterContentFontSize:CGFloat = 30.0
    var _firstLineHeadIndent:CGFloat = -1.0 // to handle the text formatting that does not need indentation
    
    let _backgroundColor = UIColor.init(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 26.0 / 255.0, alpha: 1.0)
    let _foregroundColor = UIColor.init(red: 178.0 / 255.0, green: 178.0 / 255.0, blue: 178.0 / 255.0, alpha: 1.0)
    
//    let readerWebView = WKWebView.init(frame: .zero)
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
        self.pageNumberLabel.textColor = _foregroundColor
        self.pageContentView.backgroundColor = .clear
        
        readerWebView.navigationDelegate = self
        readerWebView.frame = .zero
        
        if isInitialRun {
            cloudStore.removeObject(forKey: CURRENT_CHAPTER_URL_KEY)
            cloudStore.removeObject(forKey: CURRENT_PAGE_NUMBER_KEY)
            cloudStore.removeObject(forKey: PREVIOUS_NUMBER_PAGES_KEY)

            saveToCloud(pageNumber: 0)
        }
        loadFromCloud()
    }

// MARK: - wkwebview delegates
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
//        print("didCommit")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("didFinish")
        
        self.webLoadingActivityIndicator.stopAnimating()

        let urlString = readerWebView.url!.absoluteString
        saveToCloud(urlString: urlString)
        saveToCloud(pageNumber: pageNumber)

        
        generateTextViewsFromWebResponse()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.webLoadingActivityIndicator.stopAnimating()
    }

// MARK: - Flows of Navigation on Reading
    
    
    func loadNextChapter() {
        
        if (webNovelSource == .黃金屋) {
            readerWebView.evaluateJavaScript("JumpNext();", completionHandler: nil)
        }
        
        
        // 和圖書
        /*
         */
        
        if (webNovelSource == .uu看書) {
            readerWebView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
                
                let htmlString:String = html as! String
                
                if let doc = try? HTML(html: htmlString, encoding: .utf8) {
                    // get next page url
                    for link in doc.xpath("//a[@id='read_next']") {
                        guard let nextPageURLComponentString:String = link["href"] else {continue}
                        
                        // replace the query items
                        var url = URL.init(string: defaultBookContentURLString)
                        url = url?.deletingLastPathComponent()
                        let urlString = url?.absoluteString
                        guard let urlComponents = urlString?.split(separator: "?") else {return}
                        url = URL.init(string: urlComponents[0]+nextPageURLComponentString)
                        print("load the next page. url= \(url!)")

                        let request = URLRequest(url: url!)
                        self.readerWebView.load(request)
                        self.webLoadingActivityIndicator.startAnimating()
                    }
                }
            })
        }
        
        
        // 飄天文學
        /*
        readerWebView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
            
            let htmlString:String = html as! String
            
            if let doc = try? HTML(html: htmlString, encoding: .utf8) {
                // get next page url
                for a in doc.xpath("//div[@class='bottomlink']/a") {
//                    print("a.text= \(a.text!)")
                    if a.text == "下一章（快捷键  →）" {    // "（快捷键  ←）上一章"
                        
//                        print("a[href]= \(a["href"])")
                        guard let nextPageURLComponentString:String = a["href"] else {continue}

                        // replace the query items
                        var url = URL.init(string: defaultBookContentURLString)
                        url = url?.deletingLastPathComponent()
                        let urlString = url?.absoluteString
                        guard let urlComponents = urlString?.split(separator: "?") else {return}
                        url = URL.init(string: urlComponents[0]+nextPageURLComponentString)
                        print("load the next page. url= \(url!)")

                        let request = URLRequest(url: url!)
                        self.readerWebView.load(request)
                        self.webLoadingActivityIndicator.startAnimating()
                    }
                }
            }
        })
        */
        
        self.webLoadingActivityIndicator.startAnimating()

    }
    
    func loadPreviousChapter() {
        
        if (webNovelSource == .黃金屋) {
            readerWebView.evaluateJavaScript("JumpPrev();", completionHandler: nil)
        }
        
        
        // 和圖書
        /*
         */
        
        if (webNovelSource == .uu看書) {
            readerWebView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
                
                let htmlString:String = html as! String
                
                if let doc = try? HTML(html: htmlString, encoding: .utf8) {
                    // get next page url
                    for link in doc.xpath("//a[@id='read_pre']") {
                        guard let nextPageURLComponentString:String = link["href"] else {continue}
                        
                        // replace the query items
                        var url = URL.init(string: defaultBookContentURLString)
                        url = url?.deletingLastPathComponent()
                        let urlString = url?.absoluteString
                        guard let urlComponents = urlString?.split(separator: "?") else {return}
                        url = URL.init(string: urlComponents[0]+nextPageURLComponentString)
                        print("load the previous page. url= \(url!)")

                        let request = URLRequest(url: url!)
                        self.readerWebView.load(request)
                        self.webLoadingActivityIndicator.startAnimating()
                    }
                }
            })

        }
                
        // 飄天文學
        /*
        readerWebView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
            
            let htmlString:String = html as! String
            
            if let doc = try? HTML(html: htmlString, encoding: .utf8) {
                // get next page url
                for a in doc.xpath("//div[@class='bottomlink']/a") {
//                    print("a.text= \(a.text!)")
                    if a.text == "（快捷键  ←）上一章" {
                
//                        print("a[href]= \(a["href"])")
                        guard let nextPageURLComponentString:String = a["href"] else {continue}

                        // replace the query items
                        var url = URL.init(string: defaultBookContentURLString)
                        url = url?.deletingLastPathComponent()
                        let urlString = url?.absoluteString
                        guard let urlComponents = urlString?.split(separator: "?") else {return}
                        url = URL.init(string: urlComponents[0]+nextPageURLComponentString)
                        print("load the next page. url= \(url!)")

                        let request = URLRequest(url: url!)
                        self.readerWebView.load(request)
                        self.webLoadingActivityIndicator.startAnimating()
                    }
                }
            }
        })
         */
         
        self.webLoadingActivityIndicator.startAnimating()

    }
    
// MARK: - iCloud functions
        
    func saveToCloud(urlString: String) {
        print("save url string to cloud storage: \(urlString)")
        cloudStore.set(urlString, forKey: CURRENT_CHAPTER_URL_KEY)
    }
    
    func saveToCloud(pageNumber: Int) {
        print("save page number to cloud storage: \(pageNumber)")
        cloudStore.set(pageNumber, forKey: CURRENT_PAGE_NUMBER_KEY)
    }
    
    func saveToCloud(previousChapterNumberOfPages: Int) {
        print("save the number of pages of the previous chapter to cloud storage: \(previousChapterNumberOfPages)")
        cloudStore.set(previousChapterNumberOfPages, forKey: PREVIOUS_NUMBER_PAGES_KEY)
    }
    
    func loadFromCloudPreviousChapterNumberOfPages()->Int {
        let pageNumberInt64 = cloudStore.longLong(forKey: PREVIOUS_NUMBER_PAGES_KEY)
        let previousChapterNumberOfPages = Int(pageNumberInt64)
        print("load the number of pages of the previous chapter to cloud storage: \(previousChapterNumberOfPages)")
        return previousChapterNumberOfPages
    }
    
    func loadFromCloud() {
        
        let pageNumberInt64 = cloudStore.longLong(forKey: CURRENT_PAGE_NUMBER_KEY)
        pageNumber = Int(pageNumberInt64)
        print("page number loaded from cloud storage: \(pageNumber)")
        
        var urlString = cloudStore.string(forKey: CURRENT_CHAPTER_URL_KEY) ?? ""
        if urlString == "" {
            print("init url from hard-coded string:\(defaultBookContentURLString)")
            urlString = defaultBookContentURLString
        }
        
        let bookContentURL = URL(string: urlString)
        let request = URLRequest(url: bookContentURL!)
            print("request url=\(urlString)")
            self.readerWebView.load(request)
            self.webLoadingActivityIndicator.startAnimating()

    }
    
// MARK: - Functions for Content Creation
    func showPageNumber() {
        self.pageNumberLabel.text = "\(pageNumber+1) / \(self.pageTextViews.count)"
    }
    
    func generateTextViewsFromWebResponse() {
        
        readerWebView.evaluateJavaScript("document.documentElement.outerHTML.toString()", completionHandler: { (html: Any?, error: Error?) in
            
            let htmlString:String = html as! String
                        
            if let doc = try? HTML(html: htmlString, encoding: .utf8) {
                // get content
                var contentString = ""
                var chapterTitle:String = doc.title!
                if chapterTitle.starts(with: "\n") {
                    chapterTitle = String(chapterTitle.dropFirst())
                }
                if chapterTitle.hasSuffix("\n") {
                    chapterTitle = String(chapterTitle.dropLast())
                }
                    contentString = chapterTitle + "\n\n"

                if (self.webNovelSource == .黃金屋) {
                    for p in doc.xpath("//div[@id='Lab_Contents']/p") {
                        let pp = p.text!.trimmingCharacters(in: .whitespaces)
                        contentString += pp
                    }
                }

                
                
                if (self.webNovelSource == .uu看書) {
                    // use default format
                    self._firstLineHeadIndent = -1.0
                    if let contentRootElement:XMLElement = doc.xpath("//div[@id='bookContent']").first {
    //                    let ps = doc.xpath("//div[@id='bookContent']/p")
    //                    var pCount = 0
                        
                        // remove div tags
                        let divs = doc.xpath("//div[@id='bookContent']/div")
                        for div in divs {
                            contentRootElement.removeChild(div)
                        }
                        
                        
    //                    // remove leading <br>
    //                    if let html = contentRootElement.innerHTML {
    //                        if let targetRange = html.range(of:"<br>") {
    //                            let range = html.startIndex..<targetRange.upperBound
    //                            workingString += html.replacingCharacters(in: range, with:"").trimmingCharacters(in: .whitespacesAndNewlines)
    //                        }
    //                    }
                        
                        guard let htmlString = contentRootElement.innerHTML else {
                            print("Error: HTML text conversion failed")
                            return
                        }
                        var workingString1 = ""
                        var workingString2 = ""

                        workingString1 = htmlString.removePTag()
                        workingString1 = workingString1.removeRemarkTag()
                        
                        for line in workingString1.components(separatedBy: "<br>") {
                            if line.isEmpty {
                                continue
                            }
                            workingString2 += line.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    //                                print("line= \(line)")
                        }
                        for line in workingString2.components(separatedBy: "\n") {
                            if line.isEmpty {
                                continue
                            }
                            contentString += line.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    //                                print("line= \(line)")
                        }
                        

    //                    for p in ps {
    //                        if let pString = p.text {
    //                            if pString.count > 1000 {
    //                                 one p tag contains the whole chapter string
    //                                workingString += pString
    //                            }
    //                            pCount += 1
    //                        }
    //                    }
    //
    //                    if workingString.count > 1000 {
    //                         one p tag contains the whole chapter string
    //
    //                        remove extra leading newline
    //                        if let range = workingString.range(of:"\n") {
    //                            workingString = workingString.replacingCharacters(in: range, with:"")
    //                        }
    //
    //                        remove extra newlines
    //                        workingString = workingString.replacingOccurrences(of: "\n\n", with: "\n")
    //
    //                        contentString += workingString
    //
    //                    } else {
    //
    //                        if pCount > 30 {
    //
    //                             one p tag represents one line of text
    //
    //                             use default format
    //                            self._firstLineHeadIndent = -1.0
    //
    //                            for p in ps {
    //                                if let pString = p.text {
    //                                    if pString.count > 1000 {
    //                                        print ("Parsing Error: too many large p tags")
    //                                        return
    //                                    }
    //                                    contentString += pString.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    //                                }
    //                            }
    //
    //                        } else {
    //
    //                             p tags are garbage. text is in the inner html
    //
    //                             use default format
    //                            self._firstLineHeadIndent = -1.0
    //
    //                             remove p tags
    //                            for p in ps {
    //                                if let pString = p.text {
    //                                    if pString.count < 1000 {
    //                                         remove garbage p tags
    //                                        contentRootElement.removeChild(p)
    //                                    }
    //                                }
    //                            }
    //                             remove div tags
    //                            let divs = doc.xpath("div[@id='bookContent']/div")
    //                            for div in divs {
    //                                contentRootElement.removeChild(div)
    //                            }
    //
    //                             remove leading <br>
    //                            if let html = contentRootElement.innerHTML {
    //                                if let targetRange = html.range(of:"<br>") {
    //                                    let range = html.startIndex..<targetRange.upperBound
    //                                    workingString += html.replacingCharacters(in: range, with:"").trimmingCharacters(in: .whitespacesAndNewlines)
    //                                }
    //                            }
    //
    //                            for line in workingString.components(separatedBy: "<br>") {
    //                                if line.isEmpty {
    //                                    continue
    //                                }
    //                                contentString += line.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    //                                print("line= \(line)")
    //                            }
    //
    //                        }
    //                    }
                         
                        print("contentString= \(contentString)")
                    }

                    contentString = contentString.replacingOccurrences(of: "<br><br>", with: "<br>")
                    contentString = contentString.replacingOccurrences(of: "<br>", with: "\n")
                    // get rid of <div> </div> pair
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
                // 飄天文學
                /*
                self._firstLineHeadIndent = self._chapterContentFontSize + self._charactersSpacing
                if let contentOuterElement:XMLElement = doc.xpath("//div[@id='content']").first {
                    for h1 in doc.xpath("//div[@id='content']/h1") {
                        contentOuterElement.removeChild(h1)
                    }
                    for div in doc.xpath("//div[@id='content']/div") {
                        contentOuterElement.removeChild(div)
                    }
                    for t in doc.xpath("//div[@id='content']/table") {
                        contentOuterElement.removeChild(t)
                    }
                    if let html = contentOuterElement.innerHTML {
                        if let range = html.range(of:"<br>") {
                            contentString += html.replacingCharacters(in: range, with:"").trimmingCharacters(in: .whitespacesAndNewlines)
                            contentString = contentString.replacingOccurrences(of: "<br><br>", with: "<br>")
                            contentString = contentString.replacingOccurrences(of: "<br>", with: "\n")
//                            print("contentString= \(contentString)")
                        }
                    }
                }

                */
                
                let attributedText = self.createAttributiedChapterContentStringFrom(string: contentString)
                self.renderTextPagesFrom(contenAttributedString:attributedText)
                
                self.showPageNumber()
                                
                for i in 0..<self.pageTextViews.count {
                    let index = i - self.pageNumber

                    self.pageTextViews[i].frame = CGRect(x: self.horizontalMargin(), y: CGFloat(index) * fullScreenSize.height + self.verticalMargin(), width: self.pageContentWidth(), height: self.pageContentHeight())
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
        paragraphStyle.lineSpacing = _textLineSpacing
        paragraphStyle.firstLineHeadIndent = _firstLineHeadIndent < 0 ? (_chapterContentFontSize * 2.0 + _charactersSpacing * 3.0) : _firstLineHeadIndent
        paragraphStyle.alignment = .justified
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
//            pageTextView.frame = CGRectMake(pageTextView.frame.origin.x, pageTextView.frame.origin.y + _deltaOffset, pageTextView.frame.size.width, pageTextView.frame.size.height)
            pageTextView.frame = CGRect(x: pageTextView.frame.origin.x, y: pageTextView.frame.origin.y + _deltaOffset, width: pageTextView.frame.size.width, height: pageTextView.frame.size.height)

        }

    }
    
    func swipeUp() {
        
        pageNumber += 1
        if pageNumber >= pageTextViews.count {
            
            saveToCloud(previousChapterNumberOfPages: pageTextViews.count - 1)
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
//            print("current Page Number: \(self.pageNumber+1) Total number of Page: \(self.pageTextViews.count)")
        })
        showPageNumber()
        saveToCloud(pageNumber: pageNumber)
    }
    
    func swipeDown() {
        
        pageNumber -= 1
        if pageNumber < 0 {
            pageNumber = loadFromCloudPreviousChapterNumberOfPages()
            
            removeAllPageTextViews()
            pageTextViews = [VCTextView]()
            loadPreviousChapter()
        }
        
        let animationOptions: UIView.AnimationOptions = .curveEaseIn
        UIView.animate(withDuration: 0.15, delay: 0.0, options: animationOptions, animations: {
            self.showTheCurrentPage()
            
        }, completion: { (finished: Bool) in
//            print("current Page Number: \(self.pageNumber+1) Total number of Page: \(self.pageTextViews.count)")
        })
        showPageNumber()
        saveToCloud(pageNumber: pageNumber)
    }
    
    func showTheCurrentPage() {
        for i in 0..<pageTextViews.count {
            let index = i - pageNumber
            
            let fullPageHeight = pageContentHeight() + 2 * verticalMargin()
            let pageTextView = pageTextViews[i]
//            pageTextView.frame = CGRectMake(pageTextView.frame.origin.x, CGFloat(index) * fullPageHeight + verticalMargin(), pageContentWidth(), pageContentHeight())
            pageTextView.frame = CGRect(x: pageTextView.frame.origin.x, y: CGFloat(index) * fullPageHeight + verticalMargin(), width: pageContentWidth(), height: pageContentHeight())

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


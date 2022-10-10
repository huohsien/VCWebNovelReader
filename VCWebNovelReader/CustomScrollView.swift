//
//  CustomScrollView.swift
//  VCWebNovelReader
//
//  Created by victor on 2022/10/10.
//

import UIKit

protocol CustomScrollViewDelegate {
    func scrollViewTouchBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    func scrollViewTouchMoved(_ touches: Set<UITouch>, with event: UIEvent?)
    func scrollViewTouchEnded(_ touches: Set<UITouch>, with event: UIEvent?)
}

class CustomScrollView: UIScrollView {
    
    var customDelegate: CustomScrollViewDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        for gesture in self.gestureRecognizers ?? [] {
            gesture.cancelsTouchesInView = false
            gesture.delaysTouchesBegan = false
            gesture.delaysTouchesEnded = false
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        customDelegate?.scrollViewTouchBegan(touches, with: event)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        customDelegate?.scrollViewTouchMoved(touches, with: event)
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        customDelegate?.scrollViewTouchEnded(touches, with: event)
        super.touchesEnded(touches, with: event)
    }
}

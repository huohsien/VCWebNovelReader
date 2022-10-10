//
//  VCTextView.swift
//  VCWebNovelReader
//
//  Created by victor on 2022/10/10.
//

import UIKit

class VCTextView: UITextView {

    var responder:UIResponder
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    init(frame: CGRect, textContainer: NSTextContainer?, responder: UIResponder) {
        self.responder = responder
        super.init(frame: frame, textContainer: textContainer)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (!self.isDragging) {
            responder.touchesBegan(touches, with: event)
        } else {
            super.touchesBegan(touches, with: event)
        }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (!self.isDragging) {
            responder.touchesMoved(touches, with: event)
        } else {
            super.touchesMoved(touches, with: event)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if (!self.isDragging) {
            responder.touchesEnded(touches, with: event)
        } else {
            super.touchesEnded(touches, with: event)
        }
    }
}

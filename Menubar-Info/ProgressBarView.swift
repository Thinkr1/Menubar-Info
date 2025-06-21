//
//  ProgressBarView.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 21/06/2025.
//

import Cocoa

class ProgressBarView: NSView {
    var value: Double = 0 {
        didSet {
            needsDisplay = true
        }
    }
    var maxValue: Double = 100
    var backgroundColor: NSColor = NSColor.controlBackgroundColor
    var fillColor: NSColor = NSColor.systemBlue
    var cornerRadius: CGFloat = 4
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let backgroundPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        backgroundColor.setFill()
        backgroundPath.fill()
        
        let progressWidth = bounds.width * CGFloat(value / maxValue)
        let progressRect = NSRect(x: 0, y: 0, width: progressWidth, height: bounds.height)
        let progressPath = NSBezierPath(roundedRect: progressRect, xRadius: cornerRadius, yRadius: cornerRadius)
        fillColor.setFill()
        progressPath.fill()
    }
}

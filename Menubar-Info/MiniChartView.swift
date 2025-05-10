//
//  MiniChartView.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 07/05/2025.
//

import SwiftUI
import Cocoa

class MiniChartView: NSView {
    var values: [Double] = []
    var color: NSColor = .controlAccentColor
    var transparent: Bool = true
    var is800PercentMode: Bool = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        self.wantsLayer = true
        self.layer?.masksToBounds = true
        self.layer?.cornerRadius = 6
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        let roundedRect = NSBezierPath(roundedRect: bounds, xRadius: -1, yRadius: -1)
        NSColor.black.setFill()
        roundedRect.fill()

        guard !values.isEmpty else { return }

        let padding: CGFloat = 2
        let drawRect = bounds.insetBy(dx: padding, dy: padding)
        let height = drawRect.height
        let width = drawRect.width

        let minValue: Double = 0
        let maxValue: Double = is800PercentMode ? 100 : 800
        let range = maxValue - minValue

        let path = NSBezierPath()
        let fillPath = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        for (index, value) in values.enumerated() {
            let x = padding + CGFloat(index) * width / CGFloat(max(values.count - 1, 1))
            let normalizedValue = min(value, maxValue)
            let normalized = (normalizedValue - minValue) / (range == 0 ? 1 : range)
            let y = padding + CGFloat(normalized) * height
            let point = NSPoint(x: x, y: y)

            if index == 0 {
                path.move(to: point)
                fillPath.move(to: NSPoint(x: x, y: padding))
                fillPath.line(to: point)
            } else {
                path.line(to: point)
                fillPath.line(to: point)
            }

            if index == values.count - 1 {
                fillPath.line(to: NSPoint(x: x, y: padding))
                fillPath.line(to: NSPoint(x: padding, y: padding))
                fillPath.close()
            }

        }

        context.saveGState()
        fillPath.addClip()

        let gradient = NSGradient(colors: [
            color.withAlphaComponent(0.6),
            color.withAlphaComponent(0.0)
        ])!
        gradient.draw(in: drawRect, angle: 90)
        context.restoreGState()

        context.saveGState()
        color.setStroke()
        path.stroke()
        context.restoreGState()
    }


    func setValues(_ newValues: [Double], is800PercentMode: Bool = false) {
        self.is800PercentMode = is800PercentMode
        self.values = Array(newValues.suffix(120))
        needsDisplay = true
    }
}

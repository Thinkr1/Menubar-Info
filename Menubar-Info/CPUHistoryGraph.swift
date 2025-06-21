//
//  CPUHistoryGraph.swift
//  Menubar-Info
//
//  Created by Pierre-Louis ML on 04/05/2025.
//

import SwiftUI
import Charts

struct CPUHistoryGraph: View {
    @State private var selectedElement: CPUDataPoint?
    let history: [CPUDataPoint]
    let maxValue: Double
    
    var body: some View {
        VStack {
            Chart {
                ForEach(Array(history.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Usage", min(point.value, 100))
                    )
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        yStart: .value("Min", 0),
                        yEnd: .value("Usage", min(point.value, 100))
                    )
                    .foregroundStyle(LinearGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.3), .blue.opacity(0.1)]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                }
                if let selected = selectedElement {
                    PointMark(
                        x: .value("Time", selected.timestamp),
                        y: .value("Usage", min(selected.value, maxValue))
                    )
                    .annotation(position: .top) {
                        Text("\(selected.timestamp.formatted(date: .omitted, time: .shortened)) - \(selected.value, specifier: "%.1f")%")
                            .font(.caption)
                            .padding(5)
                            .background(Color(.systemGray).opacity(0.8))
                            .cornerRadius(5)
                            .shadow(radius: 3)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let doubleValue = value.as(Double.self) {
                            Text("\(Int(doubleValue))%")
                        }
                    }
                }
            }
            .frame(height: 100)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(Color.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let location = value.location
                                    if let date: Date = proxy.value(atX: location.x) {
                                        let closest = history.min(by: { abs($0.timestamp.timeIntervalSince1970 - date.timeIntervalSince1970) < abs($1.timestamp.timeIntervalSince1970 - date.timeIntervalSince1970) })
                                        selectedElement = closest
                                    }
                                }
                                .onEnded { _ in
                                    selectedElement = nil
                                }
                        )
                }
            }
            HStack {
                Text("Max: \(history.map { $0.value }.max() ?? 0, specifier: "%.1f")%")
                    .font(.callout).bold()
                Text("Avg: \(history.map { $0.value }.reduce(0, +) / Double(max(1, history.count)), specifier: "%.1f")%")
                    .font(.callout).bold()
            }
            .padding(.horizontal, 10)
        }
        .frame(width: 300)
        .padding(20)
    }
}

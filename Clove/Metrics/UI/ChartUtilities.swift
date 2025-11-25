//
//  ChartUtilities.swift
//  Clove
//
//  Created by Colby Brown on 11/25/25.
//

import SwiftUI

extension ChartBuilder {
    func getColorForValue(_ value: Double, metric: any MetricProvider) -> Color {
        let range = metric.valueRange ?? 1...5
        let count = Int(range.upperBound) - Int(range.lowerBound) + 1

        // Calculate the index based on value - range.lowerBound
        let index = Int(value - range.lowerBound)

        // Bowel movements get special color scheme
        if metric.id == "bowelMovements" && count == 7 {
            let bowelColors = [
                Color(hex: "361C0E"), // Type 1
                Color(hex: "E18E13"), // Type 2
                Color(hex: "B9D490"), // Type 3
                Color(hex: "22C42D"), // Type 4
                Color(hex: "2A737A"), // Type 5
                Color(hex: "6F039D"), // Type 6
                Color(hex: "960101")  // Type 7
            ]
            return bowelColors[safe: index] ?? .gray
        }

        // Default diverse palette for all other categorical metrics
        let diversePalette: [Color] = [
            Color(hex: "FF6B6B"), // Red
            Color(hex: "4ECDC4"), // Teal
            Color(hex: "FFE66D"), // Yellow
            Color(hex: "95E1D3"), // Mint
            Color(hex: "F38181"), // Pink
            Color(hex: "AA96DA"), // Purple
            Color(hex: "FCBAD3"), // Light Pink
            Color(hex: "A8D8EA"), // Sky Blue
            Color(hex: "FFD93D"), // Bright Yellow
            Color(hex: "6BCB77")  // Green
        ]

        return diversePalette[safe: index] ?? .gray
    }
}

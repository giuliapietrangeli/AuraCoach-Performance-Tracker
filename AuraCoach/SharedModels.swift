import Foundation

struct SessionSnapshot: Codable, Hashable {
    let timeElapsed: TimeInterval
    let bpm: Double
    let movement: Double
    let wpm: Double
    let anxietyScore: Double
}

struct SessionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let duration: TimeInterval
    let maxBPM: Double
    let maxMovementRaw: Double
    let averageWPM: Double
    let maxWPM: Double
    let calories: Double
    let steps: Double
    let timeline: [SessionSnapshot]
    let aiReport: String
}

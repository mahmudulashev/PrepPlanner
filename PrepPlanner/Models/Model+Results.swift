import Foundation

extension IELTSMock {
    var listeningBand: Double { Band.listening(listeningRaw) }
    var readingBand: Double { Band.reading(readingRaw) }
    var overallBand: Double { Band.overall([listeningBand, readingBand, writingBand, speakingBand]) }

    var writingCriteria: [Double?] { [writingTR, writingCC, writingLR, writingGRA] }
    var speakingCriteria: [Double?] { [speakingFC, speakingLR, speakingGRA, speakingP] }

    func band(for skill: Skill) -> Double? {
        switch skill {
        case .listening: listeningBand
        case .reading: readingBand
        case .writing: writingBand
        case .speaking: speakingBand
        case .satRW, .satMath: nil
        }
    }

    var shortLabel: String {
        "IELTS · \(date.formatted(.dateTime.day().month(.abbreviated))) · \(Band.format(overallBand))"
    }
}

extension SATMock {
    var shortLabel: String {
        "SAT · \(date.formatted(.dateTime.day().month(.abbreviated))) · \(total)"
    }
}

extension ErrorEntry {
    var mockLabel: String? {
        ieltsMock?.shortLabel ?? satMock?.shortLabel
    }
}

extension AppSettings {
    func target(for skill: Skill) -> Double? {
        switch skill {
        case .listening: targetListening
        case .reading: targetReading
        case .writing: targetWriting
        case .speaking: targetSpeaking
        case .satRW, .satMath: nil
        }
    }

    var targetOverall: Double {
        Band.overall([targetListening, targetReading, targetWriting, targetSpeaking])
    }
}

// Renders the nap alarm (29 s, under the 30 s notification-sound limit). Run: swift scripts/make_alarm_sound.swift
import Foundation

let rate = 22_050
let seconds = 29.0
let notes = [1046.5, 1318.5, 1568.0, 2093.0]
let noteGap = 0.16, phrase = 1.5

var samples = [Double](repeating: 0, count: Int(seconds * Double(rate)))
var start = 0.0
while start < seconds - 1 {
    let loudness = min(1, 0.35 + start / 12 * 0.65)
    for (i, freq) in notes.enumerated() {
        let onset = start + Double(i) * noteGap
        for n in Int(onset * Double(rate))..<min(samples.count, Int((onset + 0.9) * Double(rate))) {
            let t = Double(n) / Double(rate) - onset
            let tone = sin(2 * .pi * freq * t) + 0.25 * sin(2 * .pi * freq * 4 * t) * exp(-t * 20)
            samples[n] += loudness * 0.3 * tone * exp(-t * 5) * min(1, t * 400)
        }
    }
    start += phrase
}

var data = Data()
func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + samples.count * 2))
data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(1))
append(UInt32(rate)); append(UInt32(rate * 2)); append(UInt16(2)); append(UInt16(16))
data.append(contentsOf: Array("data".utf8)); append(UInt32(samples.count * 2))
for s in samples { append(Int16(max(-1, min(1, s)) * 32_000)) }
try! data.write(to: URL(fileURLWithPath: "EveryTime/Features/Sleep/Nap/nap-alarm.wav"))

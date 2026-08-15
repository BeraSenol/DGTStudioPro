#!/usr/bin/env swift

//  make-cues.swift
// Regenerates the board cues as 16-bit mono WAVs — three sets × four cues.
//
//      swift Tools/make-cues.swift        → DGTStudioPro/Features/Board/Sounds/
//
//  Foundation only, no package. AVFoundation would also write these, and a
//  synthesis package (AudioKit and friends) certainly would — both were declined:
//  the project has zero third-party dependencies, and a RIFF header is fifteen
//  lines. Reaching for a package to make twelve short clicks would be the largest
//  dependency decision in the repo, taken for its smallest asset.
//
//  Deliberately outside `DGTStudioPro/`, which is a synchronized folder group —
//  target membership there IS folder contents, so a file dropped beside the
//  samples ships inside the app bundle.
//
//  These are a placeholder that works, not a decision about taste. The intended
//  set is lichess's — `lichess-org/files`, CC0 1.0. Swapping is renaming files to
//  `<set>-<cue>.wav` in that folder with no code change: `BoardSoundSet` and
//  `BoardCue` raw values are the only things that name them.

import Foundation

// MARK: - Format

let sampleRate = 44_100.0

// MARK: - Deterministic noise

/// A 64-bit linear congruential generator (Knuth's MMIX constants), written out
/// rather than reached for. `SystemRandomNumberGenerator` would give a different
/// file on every run, and a generator that cannot reproduce its own output is not
/// a generator — it is a one-off with a script attached.
struct SeededGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    /// Uniform in `[0, 1)`. Taken from the **top** 53 bits: an LCG's low bits are
    /// its weak ones, and a noise burst is exactly where that would be audible.
    mutating func nextUnit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }

    mutating func nextSigned() -> Double {
        nextUnit() * 2.0 - 1.0
    }
}

// MARK: - Signal helpers

/// Sample times for a duration, in seconds.
func times(_ duration: Double) -> [Double] {
    let count = Int(sampleRate * duration)
    var out = [Double](repeating: 0, count: count)
    for i in 0..<count {
        out[i] = Double(i) / sampleRate
    }
    return out
}

func lowPassed(_ x: [Double], cutoff: Double) -> [Double] {
    let a = 1.0 - exp(-2.0 * Double.pi * cutoff / sampleRate)
    var out = [Double](repeating: 0, count: x.count)
    var accumulator = 0.0
    for i in x.indices {
        accumulator += a * (x[i] - accumulator)
        out[i] = accumulator
    }
    return out
}

func highPassed(_ x: [Double], cutoff: Double) -> [Double] {
    let low = lowPassed(x, cutoff: cutoff)
    var out = [Double](repeating: 0, count: x.count)
    for i in x.indices {
        out[i] = x[i] - low[i]
    }
    return out
}

/// One damped sinusoidal resonance.
func mode(duration: Double, frequency: Double, decay: Double, amplitude: Double) -> [Double] {
    times(duration).map { t in
        amplitude * sin(2.0 * Double.pi * frequency * t) * exp(-t / decay)
    }
}

// MARK: - The instrument

/// A struck body: a fundamental plus **inharmonic** partials, and a short filtered
/// noise transient for the contact itself. Inharmonic on purpose — exact harmonics
/// read as a musical note, and a piece hitting a board is not a note.
///
/// The two axes that separate the sets are `fundamental` and `decay`, not
/// `brightness`, which is worth stating because the first attempt got it backwards:
/// marble was given a *longer* decay to sound like ringing stone and came out
/// duller than wood, because a long low ring dominates the spectrum and drags the
/// centroid down under the transient. Harder material = higher and **shorter**.
struct Knock {
    var duration: Double
    var fundamental: Double
    var decay: Double
    /// `(ratio, amplitude, decayScale)` against the fundamental.
    var partials: [(ratio: Double, amplitude: Double, decayScale: Double)]
    var noiseAmplitude: Double
    var noiseDecay: Double
    var noiseHighPass: Double
    /// Final lowpass — how much of the contact survives.
    var brightness: Double
}

/// A bell-ish blip: fundamental plus a quiet octave, with a soft attack. The 2.5 ms
/// rise is not decoration — a sine starting at full amplitude is itself a click,
/// which would put a second transient inside a cue that already has one.
struct Chime {
    var frequency: Double
    var duration: Double
    var decay: Double
    var amplitude: Double
    var delay: Double
}

/// One material: everything the four cues need.
///
/// The musical *gesture* is deliberately constant across sets — check is one blip,
/// checkmate is a falling fifth — while pitch and timbre vary. Felt takes the same
/// interval an octave down so it stays muted without losing the shape. What a cue
/// means should not depend on which set you picked.
struct Timbre {
    var name: String
    var light: Knock
    var heavy: Knock
    var checkChime: Chime
    var checkKnockGain: Double
    var mateKnockGain: Double
    var mateHigh: Chime
    var mateLow: Chime
    var movePeak: Double
    var capturePeak: Double
    var checkPeak: Double
    var matePeak: Double
    var mateTail: Double
}

func render(_ knock: Knock, gain: Double = 1.0) -> [Double] {
    let t = times(knock.duration)

    var layers = [mode(
        duration: knock.duration,
        frequency: knock.fundamental,
        decay: knock.decay,
        amplitude: 1.0
    )]
    for partial in knock.partials {
        layers.append(mode(
            duration: knock.duration,
            frequency: knock.fundamental * partial.ratio,
            decay: knock.decay * partial.decayScale,
            amplitude: partial.amplitude
        ))
    }

    var generator = SeededGenerator(seed: 0xC4E5)
    var noise = [Double](repeating: 0, count: t.count)
    for i in noise.indices {
        noise[i] = generator.nextSigned()
    }
    noise = highPassed(noise, cutoff: knock.noiseHighPass)

    var out = [Double](repeating: 0, count: t.count)
    for i in out.indices {
        var value = 0.0
        for layer in layers {
            value += layer[i]
        }
        out[i] = value + noise[i] * exp(-t[i] / knock.noiseDecay) * knock.noiseAmplitude
    }

    out = lowPassed(out, cutoff: knock.brightness)
    for i in out.indices {
        out[i] *= gain
    }
    return out
}

func render(_ chime: Chime) -> [Double] {
    var out = [Double](repeating: 0, count: Int(sampleRate * chime.delay))
    for t in times(chime.duration) {
        var value = sin(2.0 * Double.pi * chime.frequency * t)
            + 0.25 * sin(2.0 * Double.pi * chime.frequency * 2.0 * t)
        value *= exp(-t / chime.decay)
        value *= 1.0 - exp(-t / 0.0025)
        out.append(value * chime.amplitude)
    }
    return out
}

func mix(_ layers: [[Double]]) -> [Double] {
    let count = layers.map(\.count).max() ?? 0
    var out = [Double](repeating: 0, count: count)
    for layer in layers {
        for i in layer.indices {
            out[i] += layer[i]
        }
    }
    return out
}

/// Peak-normalises, then fades the last `tail` seconds to true zero. The fade is
/// not cosmetic: a waveform cut mid-cycle is a click, so without it every cue would
/// end on an unintended transient.
func finish(_ input: [Double], peak: Double, tail: Double = 0.010) -> [Double] {
    var out = input
    var maximum = 0.0
    for value in out {
        maximum = max(maximum, abs(value))
    }
    let scale = peak / (maximum + 1e-12)
    for i in out.indices {
        out[i] *= scale
    }

    let fade = Int(sampleRate * tail)
    if fade > 0, fade < out.count {
        for k in 0..<fade {
            let factor = 1.0 - Double(k) / Double(fade)
            out[out.count - fade + k] *= factor * factor
        }
    }
    return out
}

// MARK: - RIFF

extension Data {

    mutating func appendASCII(_ text: String) {
        append(contentsOf: Array(text.utf8))
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { raw in
            append(contentsOf: Array(raw))
        }
    }
}

/// Canonical 44-byte RIFF header plus 16-bit mono PCM.
func wav(_ samples: [Double]) -> Data {
    let payloadBytes = samples.count * 2
    let rate = UInt32(sampleRate)

    var out = Data()
    out.appendASCII("RIFF")
    out.appendLittleEndian(UInt32(36 + payloadBytes))
    out.appendASCII("WAVE")

    out.appendASCII("fmt ")
    out.appendLittleEndian(UInt32(16))      // subchunk size for PCM
    out.appendLittleEndian(UInt16(1))       // format: uncompressed PCM
    out.appendLittleEndian(UInt16(1))       // channels: mono
    out.appendLittleEndian(rate)
    out.appendLittleEndian(rate * 2)        // byte rate = rate × channels × 2
    out.appendLittleEndian(UInt16(2))       // block align
    out.appendLittleEndian(UInt16(16))      // bits per sample

    out.appendASCII("data")
    out.appendLittleEndian(UInt32(payloadBytes))
    for sample in samples {
        let clamped = min(max(sample, -1.0), 1.0)
        out.appendLittleEndian(Int16(clamped * 32_767.0))
    }
    return out
}

// MARK: - The three materials

// Partial ratios are the material's fingerprint: how far from harmonic, and how
// much energy sits above the fundamental. Felt is nearly harmonic and quiet up
// top (it barely rings); marble is far from harmonic and loud up top.

let woodPartials   = [(ratio: 2.47, amplitude: 0.42, decayScale: 0.55),
                      (ratio: 6.10, amplitude: 0.20, decayScale: 0.28)]
let feltPartials   = [(ratio: 2.10, amplitude: 0.25, decayScale: 0.45),
                      (ratio: 4.20, amplitude: 0.08, decayScale: 0.25)]
let marblePartials = [(ratio: 2.76, amplitude: 0.55, decayScale: 0.50),
                      (ratio: 5.40, amplitude: 0.35, decayScale: 0.30)]

// Measured on the committed samples — spectral centroid and peak partial of the
// move cue: felt 270 Hz / 157 Hz, wood 2236 Hz / 182 Hz, marble 2386 Hz / 467 Hz,
// at 70, 55 and 45 ms. Pitch and length carry the difference; the centroids of
// wood and marble are close because both are dominated by the contact transient.

let timbres: [Timbre] = [
    Timbre(
        name: "felt",
        light: Knock(duration: 0.070, fundamental: 150.0, decay: 0.016,
                     partials: feltPartials, noiseAmplitude: 0.20,
                     noiseDecay: 0.0025, noiseHighPass: 600.0, brightness: 1_800.0),
        heavy: Knock(duration: 0.100, fundamental: 118.0, decay: 0.024,
                     partials: feltPartials, noiseAmplitude: 0.35,
                     noiseDecay: 0.0050, noiseHighPass: 500.0, brightness: 1_600.0),
        // D5 → G4: the same falling fifth as the others, an octave down, so muting
        // the set does not change what the gesture means.
        checkChime: Chime(frequency: 587.33, duration: 0.24, decay: 0.070,
                          amplitude: 0.50, delay: 0.014),
        checkKnockGain: 0.80,
        mateKnockGain: 0.75,
        mateHigh: Chime(frequency: 587.33, duration: 0.30, decay: 0.090,
                        amplitude: 0.50, delay: 0.018),
        mateLow: Chime(frequency: 392.00, duration: 0.46, decay: 0.180,
                       amplitude: 0.55, delay: 0.165),
        movePeak: 0.40, capturePeak: 0.62, checkPeak: 0.62, matePeak: 0.78,
        mateTail: 0.035
    ),

    Timbre(
        name: "wood",
        light: Knock(duration: 0.055, fundamental: 190.0, decay: 0.011,
                     partials: woodPartials, noiseAmplitude: 0.55,
                     noiseDecay: 0.0035, noiseHighPass: 1_200.0, brightness: 5_200.0),
        heavy: Knock(duration: 0.085, fundamental: 142.0, decay: 0.018,
                     partials: woodPartials, noiseAmplitude: 0.85,
                     noiseDecay: 0.0060, noiseHighPass: 900.0, brightness: 5_200.0),
        // D6 → G5.
        checkChime: Chime(frequency: 1_174.7, duration: 0.20, decay: 0.055,
                          amplitude: 0.55, delay: 0.012),
        checkKnockGain: 0.75,
        mateKnockGain: 0.70,
        mateHigh: Chime(frequency: 1_174.7, duration: 0.26, decay: 0.075,
                        amplitude: 0.55, delay: 0.015),
        mateLow: Chime(frequency: 783.99, duration: 0.40, decay: 0.150,
                       amplitude: 0.60, delay: 0.150),
        movePeak: 0.55, capturePeak: 0.80, checkPeak: 0.78, matePeak: 0.92,
        mateTail: 0.030
    ),

    Timbre(
        name: "marble",
        light: Knock(duration: 0.045, fundamental: 460.0, decay: 0.008,
                     partials: marblePartials, noiseAmplitude: 0.70,
                     noiseDecay: 0.0020, noiseHighPass: 2_800.0, brightness: 12_000.0),
        heavy: Knock(duration: 0.070, fundamental: 320.0, decay: 0.014,
                     partials: marblePartials, noiseAmplitude: 0.90,
                     noiseDecay: 0.0038, noiseHighPass: 2_200.0, brightness: 12_000.0),
        checkChime: Chime(frequency: 1_174.7, duration: 0.22, decay: 0.070,
                          amplitude: 0.50, delay: 0.010),
        checkKnockGain: 0.75,
        mateKnockGain: 0.70,
        mateHigh: Chime(frequency: 1_174.7, duration: 0.28, decay: 0.090,
                        amplitude: 0.52, delay: 0.013),
        mateLow: Chime(frequency: 783.99, duration: 0.44, decay: 0.170,
                       amplitude: 0.58, delay: 0.140),
        movePeak: 0.55, capturePeak: 0.80, checkPeak: 0.78, matePeak: 0.92,
        mateTail: 0.032
    ),
]

// MARK: - Write

/// Cue names must match `BoardCue`'s raw values; set names must match
/// `BoardSoundSet`'s. Both are pinned on literals in `BoardCueTests`, which is what
/// stops this script and the app drifting into different filenames.
func cues(for timbre: Timbre) -> [(cue: String, samples: [Double])] {
    [
        ("move", finish(render(timbre.light), peak: timbre.movePeak)),
        ("capture", finish(render(timbre.heavy), peak: timbre.capturePeak)),
        ("check", finish(
            mix([
                render(timbre.light, gain: timbre.checkKnockGain),
                render(timbre.checkChime),
            ]),
            peak: timbre.checkPeak
        )),
        ("checkmate", finish(
            mix([
                render(timbre.heavy, gain: timbre.mateKnockGain),
                render(timbre.mateHigh),
                render(timbre.mateLow),
            ]),
            peak: timbre.matePeak,
            tail: timbre.mateTail
        )),
    ]
}

// Resolved from the script's own location, so it works from any working directory.
let outputDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("DGTStudioPro/Features/Board/Sounds", isDirectory: true)

do {
    try FileManager.default.createDirectory(
        at: outputDirectory,
        withIntermediateDirectories: true
    )

    var total = 0
    for timbre in timbres {
        for entry in cues(for: timbre) {
            let name = "\(timbre.name)-\(entry.cue).wav"
            let data = wav(entry.samples)
            try data.write(to: outputDirectory.appendingPathComponent(name))
            total += data.count
            let milliseconds = Double(entry.samples.count) / sampleRate * 1_000.0
            print("\(name)  \(Int(milliseconds.rounded())) ms  \(data.count) bytes")
        }
    }
    print("\n\(timbres.count * 4) files, \(total / 1_024) KB → \(outputDirectory.path)")
} catch {
    FileHandle.standardError.write(Data("make-cues: \(error.localizedDescription)\n".utf8))
    exit(1)
}

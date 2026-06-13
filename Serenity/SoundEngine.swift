import AVFoundation
import Combine

/// Generates calming ambient textures on the fly with AVAudioEngine — noise
/// colors plus nature-like soundscapes (rain, ocean, forest). No bundled audio
/// files, no licensing, works offline.
@MainActor
final class SoundEngine: ObservableObject {
    enum Sound: String, CaseIterable, Identifiable {
        case off, brown, pink, white, rain, ocean, forest
        var id: String { rawValue }
    }

    @Published private(set) var current: Sound = .off

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    // Generator state (touched only on the audio render thread).
    private var rngState: UInt32 = 0x9E3779B9
    private var brownLast: Float = 0
    private var pink = [Float](repeating: 0, count: 7)
    private var lpf: Float = 0
    private var lfoPhase: Float = 0
    private var sampleRate: Float = 44_100

    func toggle(_ sound: Sound) {
        if current == sound || sound == .off { stop() } else { play(sound) }
    }

    private func play(_ sound: Sound) {
        stop()
        configureSession(active: true)

        let format = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = Float(format.sampleRate > 0 ? format.sampleRate : 44_100)
        lfoPhase = 0

        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0 ..< Int(frameCount) {
                let value = self.nextSample(sound)
                for buffer in buffers {
                    let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                    ptr[frame] = value
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        sourceNode = node
        do {
            try engine.start()
            current = sound
        } catch {
            stop()
        }
    }

    func stop() {
        if let node = sourceNode {
            engine.detach(node)
            sourceNode = nil
        }
        if engine.isRunning { engine.stop() }
        configureSession(active: false)
        current = .off
    }

    // MARK: - Synthesis

    private func whiteSample() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 17
        rngState ^= rngState << 5
        return (Float(rngState) / Float(UInt32.max)) * 2 - 1
    }

    private func pinkSample(_ white: Float) -> Float {
        pink[0] = 0.99886 * pink[0] + white * 0.0555179
        pink[1] = 0.99332 * pink[1] + white * 0.0750759
        pink[2] = 0.96900 * pink[2] + white * 0.1538520
        pink[3] = 0.86650 * pink[3] + white * 0.3104856
        pink[4] = 0.55000 * pink[4] + white * 0.5329522
        pink[5] = -0.7616 * pink[5] - white * 0.0168980
        let out = pink[0] + pink[1] + pink[2] + pink[3] + pink[4] + pink[5] + pink[6] + white * 0.5362
        pink[6] = white * 0.115926
        return out * 0.11
    }

    private func brownSample(_ white: Float) -> Float {
        brownLast = max(-1, min(1, brownLast + white * 0.02))
        return brownLast * 3.2
    }

    /// Slow oscillator for wave/gust envelopes, at `hz`.
    private func lfo(_ hz: Float) -> Float {
        lfoPhase += 2 * .pi * hz / sampleRate
        if lfoPhase > 2 * .pi { lfoPhase -= 2 * .pi }
        return sin(lfoPhase)
    }

    private func nextSample(_ sound: Sound) -> Float {
        let white = whiteSample()
        switch sound {
        case .white:
            return white * 0.22
        case .pink:
            return pinkSample(white) * 0.9
        case .brown:
            return brownSample(white) * 0.22
        case .rain:
            // Softened white = a steady hiss, with a little crackle on top.
            lpf += (white - lpf) * 0.35
            return (lpf * 1.1 + white * 0.12) * 0.5
        case .ocean:
            // Pink noise swelling in and out like waves (~12s period).
            let env = 0.45 + 0.45 * (lfo(0.08) * 0.5 + 0.5)
            return pinkSample(white) * env * 1.3
        case .forest:
            // Brown rustle under slow wind gusts, with airy leaves on top.
            let gust = 0.5 + 0.5 * (lfo(0.05) * 0.5 + 0.5)
            lpf += (white - lpf) * 0.5
            return (brownSample(white) * 0.18 * gust + lpf * 0.08) * 0.9
        case .off:
            return 0
        }
    }

    private func configureSession(active: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if active {
                try session.setCategory(.playback, options: [.mixWithOthers])
            }
            try session.setActive(active, options: active ? [] : [.notifyOthersOnDeactivation])
        } catch {
            // Best-effort: audio just won't start; not user-facing.
        }
    }
}

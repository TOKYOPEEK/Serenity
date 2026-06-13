import AVFoundation
import Combine

/// Generates calming ambient noise (brown / pink / white) on the fly with
/// AVAudioEngine — no bundled audio files, no licensing, works offline.
@MainActor
final class SoundEngine: ObservableObject {
    enum Sound: String, CaseIterable, Identifiable {
        case off, brown, pink, white
        var id: String { rawValue }
    }

    @Published private(set) var current: Sound = .off

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    // Noise generator state (touched only on the audio render thread).
    private var rngState: UInt32 = 0x12345678
    private var brownLast: Float = 0
    private var pink = [Float](repeating: 0, count: 7)

    func toggle(_ sound: Sound) {
        if current == sound || sound == .off { stop() } else { play(sound) }
    }

    private func play(_ sound: Sound) {
        stop()
        configureSession(active: true)

        let format = engine.outputNode.inputFormat(forBus: 0)
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0 ..< Int(frameCount) {
                let value = self.nextSample(sound) * 0.22   // headroom, gentle level
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

    // MARK: - Noise math

    /// Fast white-noise sample in [-1, 1] via xorshift (no allocation/locks).
    private func whiteSample() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 17
        rngState ^= rngState << 5
        return (Float(rngState) / Float(UInt32.max)) * 2 - 1
    }

    private func nextSample(_ sound: Sound) -> Float {
        let white = whiteSample()
        switch sound {
        case .white:
            return white
        case .brown:
            // Integrate white noise, leak to avoid drift; scale back up.
            brownLast = (brownLast + white * 0.02)
            brownLast = max(-1, min(1, brownLast))
            return brownLast * 3.2
        case .pink:
            // Paul Kellet's economical pink-noise filter.
            pink[0] = 0.99886 * pink[0] + white * 0.0555179
            pink[1] = 0.99332 * pink[1] + white * 0.0750759
            pink[2] = 0.96900 * pink[2] + white * 0.1538520
            pink[3] = 0.86650 * pink[3] + white * 0.3104856
            pink[4] = 0.55000 * pink[4] + white * 0.5329522
            pink[5] = -0.7616 * pink[5] - white * 0.0168980
            let out = pink[0] + pink[1] + pink[2] + pink[3] + pink[4] + pink[5] + pink[6] + white * 0.5362
            pink[6] = white * 0.115926
            return out * 0.11
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

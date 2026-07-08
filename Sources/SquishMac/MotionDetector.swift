import Combine
import Foundation

#if canImport(CoreMotion) && !os(macOS)
import CoreMotion
#endif

#if os(macOS)
import Darwin
#endif

struct MotionImpact {
    let strength: Double
    let timestamp: Date
}

struct AccelerationVector {
    let x: Double
    let y: Double
    let z: Double

    func distance(to other: AccelerationVector) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        let dz = z - other.z
        return sqrt(dx * dx + dy * dy + dz * dz)
    }

    func mixed(with other: AccelerationVector, factor: Double) -> AccelerationVector {
        let inverse = 1.0 - factor
        return AccelerationVector(
            x: x * inverse + other.x * factor,
            y: y * inverse + other.y * factor,
            z: z * inverse + other.z * factor
        )
    }
}

protocol AccelerometerSource: AnyObject {
    var name: String { get }
    var isAvailable: Bool { get }
    func start(updateInterval: TimeInterval, handler: @escaping (AccelerationVector) -> Void)
    func stop()
}

final class MotionDetector: ObservableObject {
    enum DetectorState: String {
        case stopped = "Stopped"
        case running = "Running"
        case unavailable = "Unavailable"
    }

    @Published private(set) var state: DetectorState = .stopped
    @Published private(set) var activeSourceName: String = "None"
    @Published private(set) var lastStrength: Double = 0

    var onImpact: ((MotionImpact) -> Void)?

    private let settings: SettingsStore
    private var source: AccelerometerSource?
    private var baseline: AccelerationVector?
    private var lastSample: AccelerationVector?
    private var lastTriggerDate = Date.distantPast
    private let updateInterval: TimeInterval = 1.0 / 80.0

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        guard source == nil else {
            return
        }

        guard let selectedSource = Self.makeBestSource() else {
            DispatchQueue.main.async {
                self.state = .unavailable
                self.activeSourceName = "No accelerometer"
            }
            return
        }

        resetCalibration()
        source = selectedSource

        DispatchQueue.main.async {
            self.state = .running
            self.activeSourceName = selectedSource.name
        }

        selectedSource.start(updateInterval: updateInterval) { [weak self] sample in
            self?.process(sample)
        }
    }

    func stop() {
        source?.stop()
        source = nil
        resetCalibration()

        DispatchQueue.main.async {
            self.state = .stopped
            self.activeSourceName = "None"
        }
    }

    func resetCalibration() {
        baseline = nil
        lastSample = nil
    }

    private func process(_ sample: AccelerationVector) {
        guard settings.isEnabled else {
            return
        }

        if baseline == nil {
            baseline = sample
            lastSample = sample
            return
        }

        let currentBaseline = baseline ?? sample
        let highPassStrength = sample.distance(to: currentBaseline)
        let jerkStrength = lastSample.map { sample.distance(to: $0) } ?? 0
        let strength = max(highPassStrength, jerkStrength)

        baseline = currentBaseline.mixed(with: sample, factor: 0.06)
        lastSample = sample

        let threshold = max(settings.sensitivity, 0.01)
        guard strength >= threshold else {
            return
        }

        let now = Date()
        guard now.timeIntervalSince(lastTriggerDate) >= settings.cooldown else {
            return
        }

        lastTriggerDate = now

        DispatchQueue.main.async {
            self.lastStrength = strength
            self.onImpact?(MotionImpact(strength: strength, timestamp: now))
        }
    }

    private static func makeBestSource() -> AccelerometerSource? {
        #if canImport(CoreMotion) && !os(macOS)
        let coreMotionSource = CoreMotionAccelerometerSource()
        if coreMotionSource.isAvailable {
            return coreMotionSource
        }
        #endif

        let hidSource = IOHIDEventAccelerometerSource()
        if hidSource.isAvailable {
            return hidSource
        }

        return nil
    }
}

#if canImport(CoreMotion) && !os(macOS)
private final class CoreMotionAccelerometerSource: AccelerometerSource {
    let name = "CoreMotion"

    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()

    var isAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }

    init() {
        queue.name = "SquishMac.CoreMotion"
        queue.qualityOfService = .userInteractive
    }

    func start(updateInterval: TimeInterval, handler: @escaping (AccelerationVector) -> Void) {
        guard motionManager.isAccelerometerAvailable else {
            return
        }

        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.startAccelerometerUpdates(to: queue) { data, _ in
            guard let acceleration = data?.acceleration else {
                return
            }

            handler(AccelerationVector(
                x: acceleration.x,
                y: acceleration.y,
                z: acceleration.z
            ))
        }
    }

    func stop() {
        motionManager.stopAccelerometerUpdates()
    }
}
#endif

#if os(macOS)
private final class IOHIDEventAccelerometerSource: AccelerometerSource {
    let name = "IOHIDEventSystem"

    private typealias CreateClient = @convention(c) (CFAllocator?) -> UnsafeMutableRawPointer?
    private typealias CopyServices = @convention(c) (UnsafeMutableRawPointer?) -> Unmanaged<CFArray>?
    private typealias CopyEvent = @convention(c) (UnsafeRawPointer?, Int64, CFDictionary?, UInt32) -> Unmanaged<AnyObject>?
    private typealias GetFloatValue = @convention(c) (UnsafeRawPointer?, Int32) -> Double

    private let copyServices: CopyServices?
    private let copyEvent: CopyEvent?
    private let getFloatValue: GetFloatValue?
    private let client: UnsafeMutableRawPointer?
    private let queue = DispatchQueue(label: "SquishMac.IOHIDEventSystem")
    private var timer: DispatchSourceTimer?

    private let accelerometerEventType: Int64 = 12

    var isAvailable: Bool {
        readAcceleration() != nil
    }

    init() {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else {
            copyServices = nil
            copyEvent = nil
            getFloatValue = nil
            client = nil
            return
        }

        let createClient: CreateClient? = Self.load("IOHIDEventSystemClientCreate", from: handle)
        copyServices = Self.load("IOHIDEventSystemClientCopyServices", from: handle)
        copyEvent = Self.load("IOHIDServiceClientCopyEvent", from: handle)
        getFloatValue = Self.load("IOHIDEventGetFloatValue", from: handle)
        client = createClient?(nil)
    }

    func start(updateInterval: TimeInterval, handler: @escaping (AccelerationVector) -> Void) {
        stop()

        let intervalMs = max(8, Int(updateInterval * 1000.0))
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(intervalMs), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in
            guard let sample = self?.readAcceleration() else {
                return
            }

            handler(sample)
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func readAcceleration() -> AccelerationVector? {
        guard
            let client,
            let copyServices,
            let copyEvent,
            let getFloatValue,
            let servicesRef = copyServices(client)
        else {
            return nil
        }

        let services = servicesRef.takeRetainedValue() as NSArray
        for service in services {
            let serviceObject = service as AnyObject
            let servicePointer = UnsafeRawPointer(Unmanaged.passUnretained(serviceObject).toOpaque())

            guard let eventRef = copyEvent(servicePointer, accelerometerEventType, nil, 0) else {
                continue
            }

            let event = eventRef.takeRetainedValue()
            let eventPointer = UnsafeRawPointer(Unmanaged.passUnretained(event).toOpaque())
            let fieldBase = Int32(accelerometerEventType << 16)
            let x = getFloatValue(eventPointer, fieldBase)
            let y = getFloatValue(eventPointer, fieldBase + 1)
            let z = getFloatValue(eventPointer, fieldBase + 2)

            guard x.isFinite, y.isFinite, z.isFinite else {
                continue
            }

            guard abs(x) + abs(y) + abs(z) > 0.0001 else {
                continue
            }

            return AccelerationVector(x: x, y: y, z: z)
        }

        return nil
    }

    private static func load<T>(_ symbol: String, from handle: UnsafeMutableRawPointer) -> T? {
        guard let pointer = dlsym(handle, symbol) else {
            return nil
        }

        return unsafeBitCast(pointer, to: T.self)
    }
}
#else
private final class IOHIDEventAccelerometerSource: AccelerometerSource {
    let name = "Unavailable"
    var isAvailable: Bool { false }
    func start(updateInterval: TimeInterval, handler: @escaping (AccelerationVector) -> Void) {}
    func stop() {}
}
#endif

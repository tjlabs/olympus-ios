import Foundation

public struct SensorData {
    public var time: Double = 0
    public var acc = [Double](repeating: 0, count: 3)
    public var userAcc = [Double](repeating: 0, count: 3)
    public var gyro = [Double](repeating: 0, count: 3)
    public var mag = [Double](repeating: 0, count: 3)
    public var grav = [Double](repeating: 0, count: 3)
    public var att = [Double](repeating: 0, count: 3)
    public var quaternion: [Double] = [0,0,0,0]
    public var rotationMatrix = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
    
    public var gameVector: [Float] = [0,0,0,0]
    public var rotVector: [Float] = [0,0,0,0,0]
    public var pressure: [Double] = [0]
    
    public func toString() -> String {
        return "acc=\(self.acc), gyro=\(self.gyro), mag=\(self.mag), grav=\(self.grav)"
    }
}

struct ReceivedForce: Codable {
    var rssi: Double = 0
    var wardID: String = ""
}


public struct OnSpotAuthorizationResult: Codable {
    public var spots: [Spot]
    
    public init() {
        self.spots = []
    }
}

public struct Spot: Codable {
    public var ccs: Double
    public var spotID: String
    
    public init() {
        self.ccs = 0
        self.spotID = ""
    }
}

public func decodeOSA(json: String) -> OnSpotAuthorizationResult {
    let result = OnSpotAuthorizationResult.init()
    let decoder = JSONDecoder()

    let jsonString = json

    if let data = jsonString.data(using: .utf8), let decoded = try? decoder.decode(OnSpotAuthorizationResult.self, from: data) {

        return decoded
    }

    return result
}

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

// ---------- Received Force Data ---------- //
public struct ReceivedForce: Codable {
    public var rf: rf
}


public struct rf: Codable {
    public var bles: [ble]
    
    public init() {
        self.bles = []
    }
}

public struct ble: Codable {
    public var rssi: Double
    public var wardID: String
    
    public init() {
        self.rssi = 0
        self.wardID = ""
    }
}
// ------------------------------------------ //


public struct NeptuneResults: Codable {
    public var results: [result]
    
    public init() {
        self.results = []
    }
}

public struct result: Codable {
    public var spotID: String
    public var ccs: Double
    
    public init() {
        self.spotID = ""
        self.ccs = 0
    }
}


//public func decodeOSA(json: String) -> OnSpotAuthorizationResult {
//    let result = OnSpotAuthorizationResult.init()
//    let decoder = JSONDecoder()
//
//    let jsonString = json
//
//    if let data = jsonString.data(using: .utf8), let decoded = try? decoder.decode(OnSpotAuthorizationResult.self, from: data) {
//
//        return decoded
//    }
//
//    return result
//}

import Foundation
import UIKit
import CoreMotion

public class ServiceManager {
    
    let G: Double = 9.81
    
    var deviceModel: String = ""
    var os: String = ""
    var osVersion: Int = 0
    
    // ----- Sensor & BLE ----- //
    var sensorData = SensorData()
    let motionManager = CMMotionManager()
    let motionAltimeter = CMAltimeter()
    var bleManager = BLECentralManager()
    // ------------------------ //
    
    // ----- Timer ----- //
    var receivedForceTimer: Timer?
    var RF_INTERVAL: TimeInterval = 1/2 // second
    // ------------------------ //
    
    var isActiveService: Bool = true
    
    
    // --------- RFD --------- //
    var timeSleepRF: Double = 0
    let SLEEP_THRESHOLD: Double = 600
    
    var currentRfd = [String: Double]()
    var currentSpotRfd = [String: Double]()
    // ------------------------ //
    
    public var bleAvg = [String: Double]()
    
    public init() {
        deviceModel = UIDevice.modelName
        os = UIDevice.current.systemVersion
        let arr = os.components(separatedBy: ".")
        print("Device Model : \(deviceModel)")
        osVersion = Int(arr[0]) ?? 0
        print("OS : \(osVersion)")
    }
    
    func initService() {
        
    }
    
    public func startService() {
        setRegion(regionName: "global")
        startBle()
        startTimer()
    }
    
    public func stopService() {
        stopBle()
        stopTimer()
        clearServiceVaraibles()
    }
    
    func startBle() {
        bleManager.setValidTime(mode: "pdr")
        bleManager.startScan(option: .Foreground)
    }
    
    func stopBle() {
        bleManager.stopScan()
    }
    
    func startTimer() {
        if (receivedForceTimer == nil) {
            receivedForceTimer = Timer.scheduledTimer(timeInterval: RF_INTERVAL, target: self, selector: #selector(self.receivedForceTimerUpdate), userInfo: nil, repeats: true)
        }
    }
    
    func stopTimer() {
        if (receivedForceTimer != nil) {
            receivedForceTimer!.invalidate()
            receivedForceTimer = nil
        }
    }
    
    @objc func receivedForceTimerUpdate() {
        bleManager.trimBleData()
        bleManager.trimSpotBleData()
        
        var bleDictionary = bleManager.bleAvg
        var bleSpotDictionary = bleManager.bleSpotAvg
        if (deviceModel == "iPhone 13 Mini" || deviceModel == "iPhone 12 Mini" || deviceModel == "iPhone X") {
            bleDictionary.keys.forEach { bleDictionary[$0] = bleDictionary[$0]! + 7 }
        }
        
        if (!bleDictionary.isEmpty) {
            self.timeSleepRF = 0
            self.isActiveService = true
            
            if (self.isActiveService) {
                self.currentRfd = bleDictionary
            }
        } else {
            self.timeSleepRF += RF_INTERVAL
            if (self.timeSleepRF >= SLEEP_THRESHOLD) {
                print("(Jupiter) Enter Sleep Mode")
                self.isActiveService = false
            }
        }
        
        if (!bleSpotDictionary.isEmpty) {
            self.currentSpotRfd = bleSpotDictionary
        }
    }
    
    public func getSpotResult(completion: @escaping (Int, String) -> Void) {
        let bleDictionray = bleManager.bleAvg
        if (!bleDictionray.isEmpty) {
            let input = createNeptuneInput(bleDictionray: bleDictionray)
            print("(Olympus) Get Spot URL : \(NEPTUNE_URL)")
            print("(Olympus) Get Spot Input : \(input)")
            NetworkManager.shared.calcSpots(url: NEPTUNE_URL, input: input, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    completion(statusCode, returnedString)
                } else {
                    completion(statusCode, "invalid request")
                }
            })
        } else {
            completion(500, "invalid request")
        }
    }
    
    func createNeptuneInput(bleDictionray: Dictionary<String, Double>) -> ReceivedForce {
        var rfd: rf = rf()
        var inputReceivedForce: [ble] = [ble()]
        
        print("(Olympus) Create Input : \(bleDictionray.keys.count)")
        for key in bleDictionray.keys {
            let id = key
            let rssi: Double = bleDictionray[key] ?? -100.0

            var wardData: ble = ble()
            wardData.wardID = id
            wardData.rssi = rssi

            inputReceivedForce.append(wardData)
            print("(Olympus) Create Input : \(wardData.wardID) = \(wardData.rssi)")
        }

        inputReceivedForce.remove(at: 0)
        rfd.bles = inputReceivedForce

        let receivedForce: ReceivedForce = ReceivedForce(rf: rfd)
        
        return receivedForce
    }
    
    public func changeSpot(spotID: String, completion: @escaping (Int, String) -> Void) {
        let bleDictionary = bleManager.bleSpotAvg
        if (!bleDictionary.isEmpty) {
            let input = createNeptuneInput(bleDictionray: bleDictionary)
            let url = CHANGE_SPOT_URL + spotID + "/rf"
            
            print("(Olympus) Change Spot URL : \(url)")
            print("(Olympus) Change Spot Input : \(input)")
            NetworkManager.shared.changeSpot(url: url, input: input, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    completion(statusCode, returnedString)
                } else {
                    completion(statusCode, "invalid request")
                }
            })
        } else {
            completion(500, "RFD for Spot is empty")
        }
    }
    
    func getCurrentTimeInMilliseconds() -> Int
    {
        return Int(Date().timeIntervalSince1970 * 1000)
    }
    
    func getLocalTimeString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        dateFormatter.locale = Locale(identifier:"ko_KR")
        let nowDate = Date()
        let convertNowStr = dateFormatter.string(from: nowDate)
        
        return convertNowStr
    }
    
    func clearServiceVaraibles() {
        self.currentRfd = [String: Double]()
        self.currentSpotRfd = [String: Double]()
    }
    
    public func setRegion(regionName: String) {
        if (regionName.isEmpty) {
            REGION = "global"
        } else {
            REGION = regionName
        }
        print("(Olympus) Region : \(REGION)")
    }
}

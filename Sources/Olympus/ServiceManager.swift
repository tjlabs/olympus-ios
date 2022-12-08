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
    var timeSleepRF: Double = 0
    let SLEEP_THRESHOLD: Double = 600
    
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
        startBle()
        startTimer()
    }
    
    public func stopService() {
        stopBle()
        stopTimer()
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
        
        var bleDictionary = bleManager.bleAvg
        if (deviceModel == "iPhone 13 Mini" || deviceModel == "iPhone 12 Mini" || deviceModel == "iPhone X") {
            bleDictionary.keys.forEach { bleDictionary[$0] = bleDictionary[$0]! + 7 }
        }
        
        if (!bleDictionary.isEmpty) {
            self.timeSleepRF = 0
            self.isActiveService = true
            
            if (self.isActiveService) {
                self.bleAvg = bleDictionary
                print(self.bleAvg)
            }
        } else {
            self.timeSleepRF += RF_INTERVAL
            if (self.timeSleepRF >= SLEEP_THRESHOLD) {
                print("(Jupiter) Enter Sleep Mode")
                self.isActiveService = false
                self.timeSleepRF = 0
            }
        }
    }
    
    func getSpotResult() {
        
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
}

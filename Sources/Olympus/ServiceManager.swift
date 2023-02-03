import Foundation
import UIKit

public class ServiceManager {
    
    let G: Double = 9.81
    
    var deviceModel: String = ""
    var os: String = ""
    var osVersion: Int = 0
    
    // ----- Sensor & BLE ----- //
    var bleManager = BLECentralManager()
    // ------------------------ //
    
    // ----- Timer ----- //
    var receivedForceTimer: Timer?
    var RF_INTERVAL: TimeInterval = 1/2 // second
    // ------------------------ //
    
    var isActiveService: Bool = false
    
    // --------- RFD --------- //
    var timeSleepRF: Double = 0
    let SLEEP_THRESHOLD: Double = 600
    
    var currentRfd = [String: Double]()
    var currentSpotRfd = [String: Double]()
    // ------------------------ //
    
    public init() {
        let localTime = getLocalTimeString()
        
        deviceModel = UIDevice.modelName
        os = UIDevice.current.systemVersion
        let arr = os.components(separatedBy: ".")
        osVersion = Int(arr[0]) ?? 0
        
        print(localTime + " , (Olympus) Device Model : \(deviceModel)")
        print(localTime + " , (Olympus) OS : \(osVersion)")
    }
    
    func initService() {
        
    }
    
    public func startService() -> (Bool, String) {
        let localTime = getLocalTimeString()
        let log: String = localTime + " , (Olympus) Success : Service Initalization"
        
        var isSuccess: Bool = true
        var message: String = log
        
        setRegion(regionName: "global")
        startBle()
        startTimer()
        
        isActiveService = true
        
        return (isSuccess, message)
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
        let localTime = getLocalTimeString()
        
        bleManager.trimBleData()
        bleManager.trimSpotBleData()
        
        var bleDictionary = bleManager.bleAvg
        var bleSpotDictionary = bleManager.bleSpotAvg
        if (deviceModel == "iPhone 12 Mini" || deviceModel == "iPhone X") {
            bleDictionary.keys.forEach { bleDictionary[$0] = bleDictionary[$0]! + 7 }
            bleSpotDictionary.keys.forEach { bleSpotDictionary[$0] = bleSpotDictionary[$0]! + 7 }
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
                
                print(localTime + ", (Olympus) Enter Sleep Mode")
                self.isActiveService = false
            }
        }
        
        if (!bleSpotDictionary.isEmpty) {
            self.currentSpotRfd = bleSpotDictionary
        }
    }
    
    public func isWardExist() -> Bool {
        let bleDictionary = bleManager.bleAvg
        
        if (bleDictionary.isEmpty) {
            return false
        } else {
            return true
        }
    }
    
    public func getSpotResult(completion: @escaping (Int, String) -> Void) {
        let localTime = getLocalTimeString()
        
        let bleDictionray = bleManager.bleAvg
        if (!bleDictionray.isEmpty) {
            let input = createNeptuneInput(bleDictionray: bleDictionray)
            
            print(localTime + " , (Olympus) Get Spot URL : \(NEPTUNE_URL)")
            print(localTime + " , (Olympus) Get Spot Input : \(input)")
            NetworkManager.shared.calcSpots(url: NEPTUNE_URL, input: input, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    completion(statusCode, returnedString)
                } else {
                    completion(statusCode, "Invalid request")
                }
            })
        } else {
            completion(500, localTime + " , (Olympus) RFD for Spot is empty")
        }
    }
    
    public func getSpotResultForLongTime(completion: @escaping (Int, String) -> Void) {
        let localTime = getLocalTimeString()
        
        let bleDictionray = bleManager.bleAvgLong
        if (!bleDictionray.isEmpty) {
            let input = createNeptuneInput(bleDictionray: bleDictionray)
            
            print(localTime + " , (Olympus) Get Spot for Long Time URL : \(NEPTUNE_URL)")
            print(localTime + " , (Olympus) Get Spot for Long Time Input : \(input)")
            NetworkManager.shared.calcSpots(url: NEPTUNE_URL, input: input, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    completion(statusCode, returnedString)
                } else {
                    completion(statusCode, "Invalid request")
                }
            })
        } else {
            completion(500, localTime + " , (Olympus) RFD for Spot is empty")
        }
    }
    
    func createNeptuneInput(bleDictionray: Dictionary<String, Double>) -> ReceivedForce {
        let localTime = getLocalTimeString()
        
        var rfd: rf = rf()
        var inputReceivedForce: [ble] = [ble()]
        
        print(localTime + " , (Olympus) Create Input : \(bleDictionray.keys.count)")
        for key in bleDictionray.keys {
            let id = key
            let rssi: Double = bleDictionray[key] ?? -100.0

            var wardData: ble = ble()
            wardData.wardID = id
            wardData.rssi = rssi

            inputReceivedForce.append(wardData)
            print(localTime + " , (Olympus) Create Input : \(wardData.wardID) = \(wardData.rssi)")
        }

        inputReceivedForce.remove(at: 0)
        rfd.bles = inputReceivedForce

        let receivedForce: ReceivedForce = ReceivedForce(rf: rfd)
        
        return receivedForce
    }
    
    public func changeSpot(spotID: String, completion: @escaping (Int, String) -> Void) {
        let localTime = getLocalTimeString()
        
        let bleDictionary = bleManager.bleSpotAvg
        if (!bleDictionary.isEmpty) {
            let input = createNeptuneInput(bleDictionray: bleDictionary)
            let url = CHANGE_SPOT_URL + spotID + "/rf"
            
            print(localTime + " , (Olympus) Change Spot URL : \(url)")
            print(localTime + " , (Olympus) Change Spot Input : \(input)")
            NetworkManager.shared.changeSpot(url: url, input: input, completion: { statusCode, returnedString in
                if (statusCode == 200) {
                    completion(statusCode, returnedString)
                } else {
                    completion(statusCode, "Invalid request")
                }
            })
        } else {
            completion(500, localTime + " , (Olympus) RFD for Spot is empty")
        }
    }
    
    func clearServiceVaraibles() {
        self.currentRfd = [String: Double]()
        self.currentSpotRfd = [String: Double]()
    }
    
    public func setRegion(regionName: String) {
        let localTime = getLocalTimeString()
        
        if (regionName.isEmpty) {
            REGION = "global"
        } else {
            REGION = regionName
        }
        
        BASE_URL = HTTPS + REGION + ".calc.olympus.tjlabs.dev/"
        NEPTUNE_URL = BASE_URL + "engines/neptune"
        CHANGE_SPOT_URL = BASE_URL + "spots/"
        
        print(localTime + " , (Olympus) Region : \(REGION)")
        print(localTime + " , (Olympus) Get Spot URL Changed : \(NEPTUNE_URL)")
        print(localTime + " , (Olympus) Change Spot URL Changed : \(CHANGE_SPOT_URL)")
    }
}

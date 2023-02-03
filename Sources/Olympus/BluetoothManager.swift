import Foundation
import CoreBluetooth

let NRF_UUID_SERVICE         = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
let NRF_UUID_CHAR_READ       = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";
let NRF_UUID_CHAR_WRITE      = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
let NI_UUID_SERVICE          = "00001530-1212-efde-1523-785feabcd123";
let RSSI_BIAS: Double        = 0

let TJLABS_UUID: String          = "0000FEAA-0000-1000-8000-00805f9b34fb";

extension Notification.Name {
    public static let bluetoothReady      = Notification.Name("bluetoothReady")
    public static let startScan           = Notification.Name("startScan")
    public static let stopScan            = Notification.Name("stopScan")
    public static let foundDevice         = Notification.Name("foundDevice")
    public static let deviceConnected     = Notification.Name("deviceConnected")
    public static let deviceReady         = Notification.Name("deviceReady")
    public static let didReceiveData      = Notification.Name("didReceiveData")
    public static let scanInfo            = Notification.Name("scanInfo")
    public static let notificationEnabled = Notification.Name("notificationEnabled")
    public static let didEnterBackground  = Notification.Name("didEnterBackground")
    public static let didBecomeActive     = Notification.Name("didBecomeActive")
}

enum BLEScanOption: Int {
    case Foreground = 1
    case Background
}

let UUIDService = CBUUID(string: NRF_UUID_SERVICE)
let UUIDRead    = CBUUID(string: NRF_UUID_CHAR_READ)
let UUIDWrite   = CBUUID(string: NRF_UUID_CHAR_WRITE)
let NIService   = CBUUID(string: NI_UUID_SERVICE)
let digit: Double = pow(10, 2)

class BLECentralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager: CBCentralManager!
    var peripherals = [CBPeripheral]()
    var devices = [(name:String, device:CBPeripheral, RSSI:NSNumber)]()
    
    var discoveredPeripheral: CBPeripheral!
    
    var readCharacteristic: CBCharacteristic?
    var writeCharacteristic: CBCharacteristic?
    
    var identifier:String = ""
    
    var authorized: Bool = false
    var bluetoothReady:Bool = false

    var connected:Bool = false
    var isDeviceReady: Bool = false
    var isTransferring: Bool = false
    
    var isScanning: Bool = false
    var tryToConnect: Bool = false
    var isNearScan: Bool = false
    
    var foundDevices = [String]()
    
    var isBackground: Bool = false
    
    var waitTimer: Timer? = nil
    var waitTimerCounter: Int = 0
    
    var baseUUID: String = "-0000-1000-8000-00805f9b34fb"
    
    let oneServiceUUID   = CBUUID(string: TJLABS_UUID)
    
    var bleDictionary = [String: [[Double]]]()
    var bleDictionaryLong = [String: [[Double]]]()
    var bleRaw = [String: Double]()
    var bleAvg = [String: Double]()
    var bleAvgLong = [String: Double]()
    var bleCheck = [String: [Double]]()
    
    var bleForSpotChange = [String: [[Double]]]()
    var bleSpotAvg = [String: Double]()
    var bleDiscoveredTime: Double = 0
    
    public var BLE_VALID_TIME: Double = 1000
    public var BLE_VALID_TIME_LONG: Double = 10000 //ms
    let BLE_SPOT_VALID_TIME: Double = 10000
    
    override init() {
        super.init()
        
        self.centralManager = CBCentralManager(delegate: self, queue: nil, options: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .didEnterBackground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onDidReceiveNotification), name: .didBecomeActive, object: nil)
    }
    
    var isBluetoothPermissionGranted: Bool {
        if #available(iOS 13.1, *) {
            return CBCentralManager.authorization == .allowedAlways
        } else if #available(iOS 13.0, *) {
            return CBCentralManager().authorization == .allowedAlways
        }
        return true
    }
    
    // MARK: - Notification
    @objc func onDidReceiveNotification(_ notification: Notification) {
        if notification.name == .didEnterBackground {
            stopScan()
            
            startWaitTimer()
            
            startScan(option: .Background)
        }
        
        if notification.name == .didBecomeActive {
            stopWaitTimer()
            
            stopScan()
            
            startScan(option: .Foreground)
        }
        
    }
    
    // MARK: - CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case .poweredOff:
            print("CoreBluetooth BLE hardware is powered off")
            self.bluetoothReady = false
            break
        case .poweredOn:
//            print("CoreBluetooth BLE hardware is powered on and ready")
            self.bluetoothReady = true
            NotificationCenter.default.post(name: .bluetoothReady, object: nil, userInfo: nil)
            
            if self.centralManager.isScanning == false {
                startScan(option: .Foreground)
            }
            break
        case .resetting:
            //            print("CoreBluetooth BLE hardware is resetting")
            break
        case .unauthorized:
            //            print("CoreBluetooth BLE state is unauthorized")
            break
        case .unknown:
            //            print("CoreBluetooth BLE state is unknown");
            break
        case .unsupported:
            //            print("CoreBluetooth BLE hardware is unsupported on this platform");
            break
        //    default: break
        @unknown default:
            print("CBCentralManage: unknown state")
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        discoveredPeripheral = peripheral
        
        if let bleName = discoveredPeripheral.name {
            
            if bleName.contains("TJ-") {
                
                let deviceIDString = bleName.substring(from: 8, to: 15)
                
                var userInfo = [String:String]()
                userInfo["Identifier"] = peripheral.identifier.uuidString
                userInfo["DeviceID"] = deviceIDString
                userInfo["RSSI"] = String(format: "%d", RSSI.intValue )
                
                let bleTime = getCurrentTimeInMilliseconds()
                bleDiscoveredTime = bleTime
                
                if RSSI.intValue != 127 {
                    NotificationCenter.default.post(name: .scanInfo, object: nil, userInfo: userInfo)
                    
                    let condition: ((String, [[Double]])) -> Bool = {
                        $0.0.contains(bleName)
                    }
                    
                    if (bleDictionary.contains(where: condition)) {
                        let data = bleDictionary.filter(condition)
                        var value:[[Double]] = data[bleName]!
                        let dataToAdd: [Double] = [RSSI.doubleValue, bleTime]
                        value.append(dataToAdd)
                        
                        bleDictionary.updateValue(value, forKey: bleName)
                    } else {
                        bleDictionary.updateValue([[RSSI.doubleValue, bleTime]], forKey: bleName)
                    }
                    
                    if (bleDictionaryLong.contains(where: condition)) {
                        let data = bleDictionaryLong.filter(condition)
                        var value:[[Double]] = data[bleName]!
                        let dataToAdd: [Double] = [RSSI.doubleValue, bleTime]
                        value.append(dataToAdd)
                        
                        bleDictionaryLong.updateValue(value, forKey: bleName)
                    } else {
                        bleDictionaryLong.updateValue([[RSSI.doubleValue, bleTime]], forKey: bleName)
                    }
                    
                    if (bleForSpotChange.contains(where: condition)) {
                        let data = bleForSpotChange.filter(condition)
                        var value:[[Double]] = data[bleName]!
                        let dataToAdd: [Double] = [RSSI.doubleValue, bleTime]
                        value.append(dataToAdd)
                        
                        bleForSpotChange.updateValue(value, forKey: bleName)
                    } else {
                        bleForSpotChange.updateValue([[RSSI.doubleValue, bleTime]], forKey: bleName)
                    }
                    
                    trimBleData()
                    trimLongBleData()
                    trimSpotBleData()
                    
                    NotificationCenter.default.post(name: .scanInfo, object: nil, userInfo: userInfo)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral).(\(error!.localizedDescription))")
        
        self.connected = false
        
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        self.discoveredPeripheral.delegate = self
        self.connected = true
        
        var userInfo = [String:String]()
        userInfo["Identifier"] = peripheral.identifier.uuidString
        
        NotificationCenter.default.post(name: .deviceConnected, object: nil, userInfo: userInfo)
        
        discoveredPeripheral.discoverServices([UUIDService])
    }
    
    // MARK: - CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            
            return
        }
        
        for service in (peripheral.services)! {
            discoveredPeripheral.discoverCharacteristics([UUIDRead, UUIDWrite], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            
            return
        }
        
        for characteristic in (service.characteristics)! {
            if characteristic.uuid.isEqual(UUIDRead) {
                
                readCharacteristic = characteristic
                if readCharacteristic!.isNotifying != true {
                    discoveredPeripheral.setNotifyValue(true, for: readCharacteristic!)
                    
                }
            }
            if characteristic.uuid.isEqual(UUIDWrite) {
                
                writeCharacteristic = characteristic
                
                var userInfo = [String:String]()
                userInfo["Identifier"] = peripheral.identifier.uuidString
                
                NotificationCenter.default.post(name: .deviceReady, object: nil, userInfo: userInfo)
                
                isDeviceReady = true
            }
            
        }
    }
    
    func setValidTime(mode: String) {
        if (mode == "dr") {
            self.BLE_VALID_TIME = 1000
        } else {
            self.BLE_VALID_TIME = 1500
        }
    }
    
    func setValidLongTime(time: Double) {
        // time is ms
        self.BLE_VALID_TIME_LONG = time
        trimLongBleData()
        
        let localTime = getLocalTimeString()
        print(localTime + " , (Olympus) Set Valid RFD Time for long duration = \(self.BLE_VALID_TIME_LONG)")
    }
    
    func trimBleData() {
        let nowTime = getCurrentTimeInMilliseconds()
        
        let keys: [String] = Array(bleDictionary.keys.sorted())
        for index in 0..<keys.count {
            let bleID: String = keys[index]
            let bleData: [[Double]] = bleDictionary[bleID]!
            let bleCount = bleData.count
            var newValue = [[Double]]()
            for i in 0..<bleCount {
                let rssi = bleData[i][0]
                let time = bleData[i][1]
                
                if ((nowTime - time <= BLE_VALID_TIME) && (rssi >= -100)) {
                    let dataToAdd: [Double] = [rssi, time]
                    newValue.append(dataToAdd)
                }
            }
            
            if ( newValue.count == 0 ) {
                bleDictionary.removeValue(forKey: bleID)
            } else {
                bleDictionary.updateValue(newValue, forKey: bleID)
            }
        }
        
        bleCheck = chekcBleData(bleDictionary: bleDictionary)
        bleRaw = latestBleData(bleDictionary: bleDictionary)
        bleAvg = avgBleData(bleDictionary: bleDictionary)
    }
    
    func trimLongBleData() {
        let nowTime = getCurrentTimeInMilliseconds()
        
        let keys: [String] = Array(bleDictionaryLong.keys.sorted())
        for index in 0..<keys.count {
            let bleID: String = keys[index]
            let bleData: [[Double]] = bleDictionaryLong[bleID]!
            let bleCount = bleData.count
            var newValue = [[Double]]()
            for i in 0..<bleCount {
                let rssi = bleData[i][0]
                let time = bleData[i][1]
                
                if ((nowTime - time <= BLE_VALID_TIME_LONG) && (rssi >= -100)) {
                    let dataToAdd: [Double] = [rssi, time]
                    newValue.append(dataToAdd)
                }
            }
            
            if ( newValue.count == 0 ) {
                bleDictionaryLong.removeValue(forKey: bleID)
            } else {
                bleDictionaryLong.updateValue(newValue, forKey: bleID)
            }
        }
        
        bleAvgLong = avgBleData(bleDictionary: bleDictionaryLong)
    }
    
    func trimSpotBleData() {
        let nowTime = getCurrentTimeInMilliseconds()
        
        let keys: [String] = Array(bleForSpotChange.keys.sorted())
        for index in 0..<keys.count {
            let bleID: String = keys[index]
            let bleData: [[Double]] = bleForSpotChange[bleID]!
            let bleCount = bleData.count
            var newValue = [[Double]]()
            for i in 0..<bleCount {
                let rssi = bleData[i][0]
                let time = bleData[i][1]
                
                if ((nowTime - time <= BLE_SPOT_VALID_TIME) && (rssi >= -100)) {
                    let dataToAdd: [Double] = [rssi, time]
                    newValue.append(dataToAdd)
                }
            }
            
            if ( newValue.count == 0 ) {
                bleForSpotChange.removeValue(forKey: bleID)
            } else {
                bleForSpotChange.updateValue(newValue, forKey: bleID)
            }
        }
        
        bleSpotAvg = avgBleData(bleDictionary: bleForSpotChange)
    }
    
    func avgBleData(bleDictionary: Dictionary<String, [[Double]]>) -> Dictionary<String, Double> {
        var ble = [String: Double]()
        
        let keys: [String] = Array(bleDictionary.keys)
        for index in 0..<keys.count {
            let bleID: String = keys[index]
            let bleData: [[Double]] = bleDictionary[bleID]!
            let bleCount = bleData.count
            
            var rssiSum: Double = 0
            
            for i in 0..<bleCount {
                let rssi = bleData[i][0]
                rssiSum += rssi
            }
            let rssiFinal: Double = floor(((rssiSum/Double(bleData.count)) + RSSI_BIAS) * digit) / digit
            
            if ( rssiSum == 0 ) {
                ble.removeValue(forKey: bleID)
            } else {
                ble.updateValue(rssiFinal, forKey: bleID)
            }
        }
        return ble
    }
    
    
    func latestBleData(bleDictionary: Dictionary<String, [[Double]]>) -> Dictionary<String, Double> {
        var ble = [String: Double]()
        
        let keys: [String] = Array(bleDictionary.keys)
        for index in 0..<keys.count {
            let bleID: String = keys[index]
            let bleData: [[Double]] = bleDictionary[bleID]!
            
            let rssiFinal: Double = bleData[bleData.count-1][0]
            
            ble.updateValue(rssiFinal, forKey: bleID)
        }
        return ble
    }
    
    func chekcBleData(bleDictionary: Dictionary<String, [[Double]]>) -> Dictionary<String, [Double]> {
        var ble = [String: [Double]]()
        
        let keys: [String] = Array(bleDictionary.keys)
        for index in 0..<keys.count {
            let bleID: String = keys[index]
            let bleData: [[Double]] = bleDictionary[bleID]!
            let bleCount = bleData.count
            
            var rssiSum: Double = 0
//            print("BLE INFO :", bleCount, "/", bleID, "/", bleData)
            
            for i in 0..<bleCount {
                let rssi = bleData[i][0]
                rssiSum += rssi
            }
            let rssiFinal: Double = floor(((rssiSum/Double(bleData.count)) + RSSI_BIAS) * digit) / digit
            
            if ( rssiSum == 0 ) {
                ble.removeValue(forKey: bleID)
            } else {
                ble.updateValue([rssiFinal, Double(bleCount)], forKey: bleID)
            }
        }
        return ble
    }
    
    func isConnected() -> Bool {
        return connected
    }
    
    func disconnectAll() {
        if discoveredPeripheral != nil {
            centralManager.cancelPeripheralConnection(discoveredPeripheral)
        }
    }
    
    func startScan(option: BLEScanOption) -> Void {
        if centralManager.isScanning {
            stopScan()
        }
        
        if bluetoothReady {
            self.centralManager.scanForPeripherals(withServices: [oneServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : NSNumber(value: true as Bool)])
            self.isScanning = true
            
            NotificationCenter.default.post(name: .startScan, object: nil)
        }
    }
    
    func stopScan() -> Void {
        self.centralManager.stopScan()
        
        self.isScanning = false
        
        NotificationCenter.default.post(name: .stopScan, object: nil)
    }
    
    // timer
    func startWaitTimer() {
        waitTimerCounter = 0
        self.waitTimer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.waitTimerUpdate), userInfo: nil, repeats: true)
    }
    
    func stopWaitTimer() {
        if waitTimer != nil {
            waitTimer!.invalidate()
            waitTimer = nil
        }
    }
    
    @objc func waitTimerUpdate() {
        stopScan()
        
        startScan(option: .Background)
    }
    
    func getCurrentTimeInMilliseconds() -> Double
    {
        return Double(Date().timeIntervalSince1970 * 1000)
    }
    
    // Eddystone parsing
     func parseURLFromFrame(frameData: NSData) -> NSURL? {
         if frameData.length > 0 {
               let count = frameData.length
               var frameBytes = [UInt8](repeating: 0, count: count)
               frameData.getBytes(&frameBytes, length: count)

               if let URLPrefix = URLPrefixFromByte(schemeID: frameBytes[2]) {
                 var output = URLPrefix
                 for i in 3..<frameBytes.count {
                   if let encoded = encodedStringFromByte(charVal: frameBytes[i]) {
                     output.append(encoded)
                   }
                 }

                 return NSURL(string: output)
               }
             }

             return nil
      }
    
     func URLPrefixFromByte(schemeID: UInt8) -> String? {
        switch schemeID {
        case 0x00:
          return "http://www."
        case 0x01:
          return "https://www."
        case 0x02:
          return "http://"
        case 0x03:
          return "https://"
        default:
          return nil
        }
      }

       func encodedStringFromByte(charVal: UInt8) -> String? {
        switch charVal {
        case 0x00:
          return ".com/"
        case 0x01:
          return ".org/"
        case 0x02:
          return ".edu/"
        case 0x03:
          return ".net/"
        case 0x04:
          return ".info/"
        case 0x05:
          return ".biz/"
        case 0x06:
          return ".gov/"
        case 0x07:
          return ".com"
        case 0x08:
          return ".org"
        case 0x09:
          return ".edu"
        case 0x0a:
          return ".net"
        case 0x0b:
          return ".info"
        case 0x0c:
          return ".biz"
        case 0x0d:
          return ".gov"
        default:
          return String(data: Data(bytes: [ charVal ] as [UInt8], count: 1), encoding: .utf8)
        }
      }
}

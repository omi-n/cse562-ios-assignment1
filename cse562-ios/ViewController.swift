//
//  ViewController.swift
//  cse562-ios
//
//  Created by Nabil Omi on 4/7/25.
//

import UIKit
import SwiftUI
import Charts
import CoreMotion

struct Tilt: Identifiable {
    let id = UUID()
    var x: Double
    var y: Double
    var z: Double
}

struct MotionDataPoint: Identifiable {
    let id = UUID()
    
    var accelX: Double
    var accelY: Double
    var accelZ: Double
    
    var gyroX: Double
    var gyroY: Double
    var gyroZ: Double
    
    
    static func fromMotion(_ accelData: CMAccelerometerData, _ gyroData: CMGyroData) -> MotionDataPoint {
        return MotionDataPoint(
            accelX: Double(accelData.acceleration.x),
            accelY: Double(accelData.acceleration.y),
            accelZ: Double(accelData.acceleration.z),
            
            gyroX: Double(gyroData.rotationRate.x),
            gyroY: Double(gyroData.rotationRate.y),
            gyroZ: Double(gyroData.rotationRate.z)
        )
    }
    
    func normalize(mean: MotionDataPoint, variance: MotionDataPoint) -> MotionDataPoint {
        return MotionDataPoint(accelX: (accelX - mean.accelX),
                               accelY: (accelY - mean.accelY),
                               accelZ: (accelZ - mean.accelZ),
                               gyroX: (gyroX - mean.gyroX),
                               gyroY: (gyroY - mean.gyroY),
                               gyroZ: (gyroZ - mean.gyroZ))
    }

    func gyroToTilt(currentTilt: Tilt, deltaTime: Double) -> Tilt {
         let rollChange = gyroX * deltaTime
         let pitchChange = gyroY * deltaTime
         let yawChange = gyroZ * deltaTime
         
        return Tilt(x: rollChange + currentTilt.x,
                    y: pitchChange + currentTilt.y,
                    z: yawChange + currentTilt.z)
     }
}


class MotionDataPointViewModel : ObservableObject {
    var maxCount = 10000
    var calibrationDone = false
    var remainingCalibrationSeconds = 0.0
    var calibrationMean: MotionDataPoint? = nil
    var calibrationVar: MotionDataPoint? = nil
    
    @Published var data: [MotionDataPoint] = []
    
    var dataMeanVar: (mean: MotionDataPoint, var: MotionDataPoint) {
        let means = self.mean()
        return (mean: means, var: self.variance(means))
    }
    
    
    
    func setMaxCount(_ count: Int) {
        maxCount = count
    }
    
    func setCalibrationDone() {
        calibrationDone = true
        calibrationMean = self.mean()
        calibrationVar = self.variance(calibrationMean!)
    }
    
    func setRemainingCalibrationSeconds(_ sec: Double) {
        remainingCalibrationSeconds = sec
    }
    
    func mean() -> MotionDataPoint {
        if self.data.isEmpty {
            return MotionDataPoint(accelX: 0,
                                   accelY: 0,
                                   accelZ: 0,
                                   gyroX: 0,
                                   gyroY: 0,
                                   gyroZ: 0)
        }
        
        let meanAccelX = self.data.reduce(0) { result, point in
            result + point.accelX } / Double(self.data.count)
        
        let meanAccelY = self.data.reduce(0) { result, point in
            result + point.accelY } / Double(self.data.count)
        
        let meanAccelZ = self.data.reduce(0) { result, point in
            result + point.accelZ } / Double(self.data.count)
        
        let meanGyroX = self.data.reduce(0) { result, point in
            result + point.gyroX } / Double(self.data.count)
        
        let meanGyroY = self.data.reduce(0) { result, point in
            result + point.gyroY } / Double(self.data.count)
        
        let meanGyroZ = self.data.reduce(0) { result, point in
            result + point.gyroZ } / Double(self.data.count)
        
        return MotionDataPoint(accelX: meanAccelX,
                               accelY: meanAccelY,
                               accelZ: meanAccelZ,
                               gyroX: meanGyroX,
                               gyroY: meanGyroY,
                               gyroZ: meanGyroZ)
        
    }
    
    func variance(_ means: MotionDataPoint) -> MotionDataPoint {
        if self.data.isEmpty {
            return MotionDataPoint(accelX: 0,
                                   accelY: 0,
                                   accelZ: 0,
                                   gyroX: 0,
                                   gyroY: 0,
                                   gyroZ: 0)
        }
        
        let varAccelX = self.data.reduce(into: 0) { result, point
            in result += pow(point.accelX - means.accelX, 2)
        } / Double(self.data.count)
        
        let varAccelY = self.data.reduce(into: 0) { result, point
            in result += pow(point.accelY - means.accelY, 2)
        } / Double(self.data.count)
        
        let varAccelZ = self.data.reduce(into: 0) { result, point
            in result += pow(point.accelZ - means.accelZ, 2)
        } / Double(self.data.count)
        
        let varGyroX = self.data.reduce(into: 0) { result, point
            in result += pow(point.gyroX - means.gyroX, 2)
        } / Double(self.data.count)
        
        let varGyroY = self.data.reduce(into: 0) { result, point
            in result += pow(point.gyroY - means.gyroY, 2)
        } / Double(self.data.count)
        
        let varGyroZ = self.data.reduce(into: 0) { result, point
            in result += pow(point.gyroZ - means.gyroZ, 2)
        } / Double(self.data.count)
        
        return MotionDataPoint(accelX: varAccelX,
                               accelY: varAccelY,
                               accelZ: varAccelZ,
                               gyroX: varGyroX,
                               gyroY: varGyroY,
                               gyroZ: varGyroZ)
    }
    
    func addData(_ newData: MotionDataPoint) {
        if self.data.count > self.maxCount {
            self.data.removeFirst(self.data.count - self.maxCount)
        }
        self.data.append(newData)
    }
    
    func computeAccelFromK(start: Int, k: Int) -> MotionDataPoint {
        let minIdx = max(start - k, 0)
        
        let accelX = self.data[minIdx..<self.data.count]
            .reduce(into: 0.0) { result, point in result += point.accelX}
        let accelY = self.data[minIdx..<self.data.count]
            .reduce(into: 0.0) { result, point in result += point.accelY}
        let accelZ = self.data[minIdx..<self.data.count]
            .reduce(into: 0.0) { result, point in result += point.accelZ}
        
        return MotionDataPoint(
            accelX: accelX / Double(k),
            accelY: accelY / Double(k),
            accelZ: accelZ / Double(k),
            gyroX: 0.0, gyroY: 0.0, gyroZ: 0.0
        )
    }
}

struct TiltChartView: View {
    @ObservedObject var motionData: MotionDataPointViewModel
    let timeWindow: Int = 100
    let alpha: Double = 0.05
    
    // complementary filter: angle = α * (angle + gyro * dt) + (1 - α) * accel_angle
    func complementaryFilter(_ dataPoint: MotionDataPoint, type: String) -> Double {
        switch type {
        // accel roll = x
        // gyro roll = y
        case "Roll" : return dataPoint.gyroY * alpha + dataPoint.accelX * (1 - alpha)
        // accel pitch = y
        // gyro pitch = x
        case "Pitch" : return dataPoint.gyroX * alpha + dataPoint.accelY * (1 - alpha)
        // yaw you can only really use the gyro here
        case "Yaw": return dataPoint.gyroZ
        default:
            return 0.0
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if motionData.calibrationDone {
                    let baccelX = motionData.calibrationMean!.accelX
                    let vaccelX = motionData.calibrationVar!.accelX
                    
                    let bgyroX = motionData.calibrationMean!.gyroX
                    let vgyroX = motionData.calibrationVar!.gyroX
                    Text("Calibration finished. \n"
                          + "Bias[AccelX]: \(baccelX), Variance[AccelX]: \(vaccelX)\n"
                          + "Bias[GyroX]: \(bgyroX), Variance[GyroX]: \(vgyroX)")
                        .font(.headline)
                } else {
                    Text("Calibration running, remaining \(motionData.remainingCalibrationSeconds)")
                        .font(.headline)
                }
                
                // Accelerometer can't measure yaw... leaving it out.
                Text("Accelerometer Tilt Data").font(.headline)
                
                VStack(alignment: .leading) {
                    Text("Accelerometer Roll").font(.subheadline)
                    
                    Chart {
                        ForEach(Array(motionData.data.suffix(timeWindow).enumerated()), id: \.element.id) { index, point in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Value", point.accelX)
                            )
                            .foregroundStyle(Color.red)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: -1.5...1.5)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Accelerometer Pitch").font(.subheadline)
                    
                    Chart {
                        ForEach(Array(motionData.data.suffix(timeWindow).enumerated()), id: \.element.id) { index, point in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Value", -point.accelY)
                            )
                            .foregroundStyle(Color.blue)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: -1.5...1.5)
                }
                .padding(.horizontal)
                
                Text("Gyroscope Tilt Data").font(.headline).padding(.top)
                
                VStack(alignment: .leading) {
                    Text("Gyroscope Roll").font(.subheadline)
                    
                    Chart {
                        ForEach(Array(motionData.data.suffix(timeWindow).enumerated()), id: \.element.id) { index, point in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Value", point.gyroY)
                            )
                            .foregroundStyle(Color.red)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: -1.5...1.5)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Gyroscope Pitch").font(.subheadline)
                    
                    Chart {
                        ForEach(Array(motionData.data.suffix(timeWindow).enumerated()), id: \.element.id) { index, point in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Value", point.gyroX)
                            )
                            .foregroundStyle(Color.blue)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: -1.5...1.5)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Gyroscope Yaw").font(.subheadline)
                    
                    Chart {
                        ForEach(Array(motionData.data.suffix(timeWindow).enumerated()), id: \.element.id) { index, point in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Value", point.gyroZ)
                            )
                            .foregroundStyle(Color.green)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: -1.5...1.5)
                }
                .padding(.horizontal)
                
                // complementary filter: angle = α * (angle + gyro * dt) + (1 - α) * accel_angle

                Text("Complementary Tilt Data").font(.headline).padding(.top)
                
                VStack(alignment: .leading) {
                    Text("Complementary Roll").font(.subheadline)
                    
                    Chart {
                        ForEach(Array(motionData.data.suffix(timeWindow).enumerated()), id: \.element.id) { index, point in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Value", complementaryFilter(point, type: "Roll"))
                            )
                            .foregroundStyle(Color.red)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: -1.5...1.5)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Complementary Pitch").font(.subheadline)
                    
                    Chart {
                        ForEach(Array(motionData.data.suffix(timeWindow).enumerated()), id: \.element.id) { index, point in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Value", -complementaryFilter(point, type: "Pitch"))
                            )
                            .foregroundStyle(Color.blue)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: -1.5...1.5)
                }
                .padding(.horizontal)
                
                
                VStack(alignment: .leading) {
                    Text("Complementary Yaw").font(.subheadline)
                    
                    Chart {
                        ForEach(Array(motionData.data.suffix(timeWindow).enumerated()), id: \.element.id) { index, point in
                            LineMark(
                                x: .value("Time", index),
                                y: .value("Value", complementaryFilter(point, type: "Yaw"))
                            )
                            .foregroundStyle(Color.green)
                        }
                    }
                    .frame(height: 150)
                    .chartYScale(domain: -1.5...1.5)
                }
                .padding(.horizontal)
                
            }
            .padding(.vertical)
        }
    }
}


class ViewController: UIViewController {
    let motion = CMMotionManager()
    let motionUpdateHz = 1.0 / 60.0
    let maxDataSizeSeconds = 5

    let motionData: MotionDataPointViewModel = MotionDataPointViewModel()
    var remainingCalibrationSteps: Int = 5 * 60
    var gyroTilt = Tilt(x: 0.0, y: 0.0, z: 0.0)
    let accelEma = 0.1
    var lastAdjustedData: MotionDataPoint? = nil
    let phi: Double = 0.01
    
    var meanAdjustment = MotionDataPoint(accelX: 0.0,
                                         accelY: 0.0,
                                         accelZ: 0.0,
                                         gyroX: 0.0,
                                         gyroY: 0.0,
                                         gyroZ: 0.0)
    var varAdjustment = MotionDataPoint(accelX: 1.0,
                                        accelY: 1.0,
                                        accelZ: 1.0,
                                        gyroX: 1.0,
                                        gyroY: 1.0,
                                        gyroZ: 1.0)
    
    func startAccelAndGyro() {
        if self.motion.isAccelerometerAvailable && self.motion.isGyroAvailable {
            self.motion.startAccelerometerUpdates()
            self.motion.startGyroUpdates()
            self.motion.accelerometerUpdateInterval = motionUpdateHz
            self.motion.gyroUpdateInterval = motionUpdateHz
        }
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        startAccelAndGyro()
        motionData.setMaxCount(maxDataSizeSeconds * Int(1 / motionUpdateHz))
        
        Timer.scheduledTimer(timeInterval: motionUpdateHz,
                             target: self,
                             selector: #selector(ViewController.runLoop),
                             userInfo: nil,
                             repeats: true)
        
        let hostingController = UIHostingController(rootView: TiltChartView(motionData: motionData))
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        hostingController.didMove(toParent: self)
        
        }
    
    
    @objc func runLoop() {
        if let accelData = self.motion.accelerometerData {
            if let gyroData = self.motion.gyroData {
                let data = MotionDataPoint.fromMotion(accelData, gyroData)
                
                if remainingCalibrationSteps > 0 {
                    let (mAdj, vAdj) = motionData.dataMeanVar
                    meanAdjustment = mAdj
                    varAdjustment = vAdj
                    remainingCalibrationSteps -= 1
                    motionData.setRemainingCalibrationSeconds(motionUpdateHz * Double(remainingCalibrationSteps))
                } else {
                    if !motionData.calibrationDone {
                        motionData.setCalibrationDone()
                    }
                }
                
                var adjustedData = data.normalize(mean: meanAdjustment, variance: varAdjustment)
                if lastAdjustedData != nil {
                    adjustedData.accelX = adjustedData.accelX * accelEma + (lastAdjustedData!.accelX * (1.0 - accelEma))
                    adjustedData.accelY = adjustedData.accelY * accelEma + (lastAdjustedData!.accelY * (1.0 - accelEma))
                    adjustedData.accelZ = adjustedData.accelZ * accelEma + (lastAdjustedData!.accelZ * (1.0 - accelEma))
                }
                
                gyroTilt = adjustedData.gyroToTilt(currentTilt: gyroTilt, deltaTime: motionUpdateHz)
                
                let newData = MotionDataPoint(accelX: adjustedData.accelX,
                                              accelY: adjustedData.accelY,
                                              accelZ: adjustedData.accelZ,
                                              gyroX: gyroTilt.x / 1.57,
                                              gyroY: gyroTilt.y / 1.57,
                                              gyroZ: gyroTilt.z / 1.57)
                motionData.addData(newData)
                lastAdjustedData = adjustedData
                
            }
        }
        
    }
}

//
//  AVCaptureDevice_Tests.swift
//  
//
//  Created by ChakaN on 1/24/24.
//

import XCTest
import AVFoundation
@testable import MovieCamPro

final class AVCaptureDevice_Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

//    func test_AVCaptureDevice_printAllAvailableFormats_shouldNotThrowError() {
//        // Arrange
//        
//        let sessionQueue = DispatchQueue(label: "session Queue")
//        let captureSession = AVCaptureSession()
//        var device: AVCaptureDevice!
//        
//        sessionQueue.async {
//            captureSession.sessionPreset = .high
//            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualCamera], mediaType: .video, position: .unspecified)
//            captureSession.beginConfiguration()
//            guard let videoDevice = discoverySession.devices.first else {
//                fatalError("no device")
//            }
//            device = videoDevice
//            captureSession.commitConfiguration()
//        }
//        
//        // Act
//        
//        // Assertion
//        
//        XCTAssertNoThrow(device.printAllAvailableFormats())
//    }
}

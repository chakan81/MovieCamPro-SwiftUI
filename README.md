# MovieCamPro-SwiftUI

## Detailed movie camera control interface for SwiftUI

You can configure following features manually in SwiftUI environment.

> - dimensions
> - frame rate
> - camera lens (i.e. wide, ultra wide, telephoto)
> - slo-mo
> - zoom
> - exposure
> - image stabilizer
> - HDR
> - DolbyVision
> - and so on

## Ver. 0.2.0

# How to Use

1. import MovieCamPro
   
        import MovieCamPro

2. Add these properties to your info.plist

    > Privacy - Camera Usage Description
    > Privacy - Michrophoe Usage Description
    > Privacy - Photo Library Additions Usage Description


3. implement CameraService

        @StateObject var cameraService: CameraService = CameraService()

4. set dimension, frame rate, zoom and dolby
   <pre>
   <code>
        cameraService.dimension = CMVideoDimensions(width: 3840, height: 2160)
        cameraService.frameRate = 30.0
        cameraService.zoomFactor = 1.0
        cameraService.dolbyOn = true
    </code>
    </pre>
    a. you can use only 4 dimensions.
    > CMVideoDimensions(width: 3840, height: 2160)
    > CMVideoDimensions(width: 1920, height: 1080)
    > CMVideoDimensions(width: 1280, height: 720)
    > CMVideoDimensions(width: 640, height: 480)

    b. frameRate > 60 will be a slo-mo movie.
    
    c. zoomFactor 1.0 is basic wideAngleCam. 0.5 is basic ultraWideAngleCam. Transition point to TelephotoCam varies by device.

5. setup and start session

    You can use .onAppear() to setup and start session.
    <pre>
    <code>
    .onAppear(perform: {
            cameraService.setupSession()
            cameraService.startSession()
        })
    </code>
    </pre>

6. start and stop recording

    Use cameraService.startRecording() and cameraService.stopRecording() to start and stop recording.
    Make sure check camera is recording or not with cameraService.isRecording

    <pre>
    <code>
    DispatchQueue.main.async {
        if cameraService.isRecording {
            cameraService.stopRecording()
        } else {       
            cameraService.startRecording()
        }
        cameraService.isRecording.toggle()
    }
    </code>
    </pre>

    Once you stop recording, video will be saved to Photo Library.

import SwiftUI
import UIKit
import AVFoundation

/// Native camera interface for capturing profile photos
struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.cameraDevice = .front // Default to front camera for selfies

        // Configure for profile photos
        picker.cameraOverlayView = createOverlayView()

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func createOverlayView() -> UIView {
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.clear

        // Create circular guide
        let circularGuide = UIView()
        circularGuide.backgroundColor = UIColor.clear
        circularGuide.layer.borderColor = UIColor.white.cgColor
        circularGuide.layer.borderWidth = 2
        circularGuide.layer.cornerRadius = 100
        circularGuide.translatesAutoresizingMaskIntoConstraints = false

        overlayView.addSubview(circularGuide)

        NSLayoutConstraint.activate([
            circularGuide.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            circularGuide.centerYAnchor.constraint(equalTo: overlayView.centerYAnchor, constant: -50),
            circularGuide.widthAnchor.constraint(equalToConstant: 200),
            circularGuide.heightAnchor.constraint(equalToConstant: 200)
        ])

        // Add instruction label
        let instructionLabel = UILabel()
        instructionLabel.text = "Position your face in the circle"
        instructionLabel.textColor = .white
        instructionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        instructionLabel.textAlignment = .center
        instructionLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        instructionLabel.layer.cornerRadius = 8
        instructionLabel.layer.masksToBounds = true
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false

        overlayView.addSubview(instructionLabel)

        NSLayoutConstraint.activate([
            instructionLabel.centerXAnchor.constraint(equalTo: overlayView.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: circularGuide.bottomAnchor, constant: 30),
            instructionLabel.widthAnchor.constraint(equalToConstant: 250),
            instructionLabel.heightAnchor.constraint(equalToConstant: 40)
        ])

        return overlayView
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Prefer edited image, fallback to original
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)

            if let capturedImage = image {
                parent.onImageCaptured(capturedImage)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            // Handle cancellation - close the camera
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    CameraView { image in
        print("Captured image: \(image)")
    }
}
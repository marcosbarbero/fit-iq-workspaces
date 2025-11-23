import UIKit

// Quick test to verify camera availability
print("Camera available: \(UIImagePickerController.isSourceTypeAvailable(.camera))")
print("Photo library available: \(UIImagePickerController.isSourceTypeAvailable(.photoLibrary))")

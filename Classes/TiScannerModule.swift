//
//  TiScannerModule.swift
//  titanium-scanner
//
//  Created by Your Name
//  Copyright (c) 2021 Your Company. All rights reserved.
//  Updated to support barcode scanning with DataScannerViewController (iOS 16+)
//

import UIKit
import TitaniumKit
import PDFKit

#if canImport(Vision)
import Vision
import VisionKit
#endif

@objc(TiScannerModule)
class TiScannerModule: TiModule {
  
  func moduleGUID() -> String {
    return "fc40b436-6d90-4cf0-9627-f56e4321b30f"
  }
  
  override func moduleId() -> String! {
    return "ti.scanner"
  }
  
#if canImport(Vision)
  // Existing document scanner for pages...
  var _scanner: VNDocumentCameraViewController?
  var currentScan: VNDocumentCameraScan?
  
  func scannerInstance() -> VNDocumentCameraViewController {
    if let scanner = _scanner {
      return scanner
    }
    _scanner = VNDocumentCameraViewController()
    _scanner!.delegate = self
    return _scanner!
  }
  
  func dismissAndCleanup() {
    _scanner?.delegate = nil
    _scanner = nil
  }
  
  // New property to hold the barcode scanner instance (iOS 16+)
  @available(iOS 16.0, *)
  var _barcodeScanner: DataScannerViewController?
  
  // MARK: Public APIs
  
  @objc(isSupported:)
  func isSupported(unused: [Any]?) -> Bool {
    return VNDocumentCameraViewController.isSupported
  }
  
  @objc(showScanner:)
  func showScanner(unused: [Any]?) {
    TiApp.controller().present(scannerInstance(), animated: true, completion: nil)
  }
  
  // New API to show the barcode scanner using DataScannerViewController
    @MainActor @objc(showBarcodeScanner:)
    func showBarcodeScanner(unused: [Any]?) {
      if #available(iOS 16.0, *) {
        // Configure the scanner to look only for barcodes.
        let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [
            .barcode(symbologies: [.ean13, .ean8, .upce, .gs1DataBar, .code128, .gs1DataBarLimited, .gs1DataBarExpanded])
        ]
        
          let scanner = DataScannerViewController(
                recognizedDataTypes: recognizedDataTypes,
                qualityLevel: .balanced,
                recognizesMultipleItems: false,
                isHighFrameRateTrackingEnabled: false,
                isPinchToZoomEnabled: true,
                isGuidanceEnabled: true,       // guidance comes first
                isHighlightingEnabled: true     // then highlighting
              )
        
        scanner.delegate = self
        _barcodeScanner = scanner
        
        // Present the scanner and start scanning once presentation completes.
        TiApp.controller().present(scanner, animated: true) {
          try? scanner.startScanning()
        }
      } else {
        fireEvent("error", with: ["error": "Barcode scanning requires iOS 16 or later"])
      }
    }
  
  @objc(imageOfPageAtIndex:)
  func imageOfPageAtIndex(args: [Any]) -> TiBlob? {
    guard let index = args.first as? Int, let scan = currentScan else { return nil }
    let image = scan.imageOfPage(at: index)
    return TiBlob(image: image)
  }
  
  @objc(pdfOfPageAtIndex:)
  func pdfOfPageAtIndex(args: [Any]) -> TiBlob? {
    guard let index = args.first as? Int, let scan = currentScan else { return nil }
    let image = scan.imageOfPage(at: index)
    let pdfDocument = PDFDocument()
    if let pdfPage = PDFPage(image: image) {
      pdfDocument.insert(pdfPage, at: 0)
    }
    return TiBlob(data: pdfDocument.dataRepresentation(), mimetype: "application/pdf")
  }
  
  @objc(pdfOfAllPages:)
  func pdfOfAllPages(args: [Any]?) -> TiBlob? {
    guard let scan = currentScan else { return nil }
    
    var resizeImages = false
    var padding = 80
    var compressionQuality = 1.0
    
    if let params = args?.first as? [String: Any] {
      resizeImages = params["resizeImages"] as? Bool ?? false
      padding = params["padding"] as? Int ?? 80
      compressionQuality = params["compressionQuality"] as? Double ?? 1.0
    }
    
    let pdfDocument = PDFDocument()
    
    for index in 0..<scan.pageCount {
      let image = UIImage(data: scan.imageOfPage(at: index).jpegData(compressionQuality: compressionQuality)!)
      if resizeImages {
        if let pdfData = A4PDFDataFromCentered(image: image!, with: Float(padding)) {
          if let pdfDataDocument = PDFDocument(data: pdfData) {
            if let pdfPage = pdfDataDocument.page(at: 0) {
              pdfDocument.insert(pdfPage, at: index)
            }
          }
        }
      } else {
        if let pdfPage = PDFPage(image: image!) {
          pdfDocument.insert(pdfPage, at: index)
        }
      }
    }
    
    return TiBlob(data: pdfDocument.dataRepresentation(), mimetype: "application/pdf")
  }
#endif
}

#if canImport(Vision)
// MARK: VNDocumentCameraViewControllerDelegate

extension TiScannerModule: VNDocumentCameraViewControllerDelegate {
  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    fireEvent("cancel")
    controller.dismiss(animated: true, completion: nil)
    dismissAndCleanup()
  }
  
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
    fireEvent("error", with: ["error": error.localizedDescription])
    controller.dismiss(animated: true, completion: nil)
    dismissAndCleanup()
  }
  
  func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
    currentScan = scan
    fireEvent("success", with: ["count": scan.pageCount, "title": scan.title] as [String: Any])
    controller.dismiss(animated: true, completion: nil)
    dismissAndCleanup()
  }
}

// MARK: DataScannerViewControllerDelegate (Barcode Scanning)
@available(iOS 16.0, *)
extension TiScannerModule: DataScannerViewControllerDelegate {

    // Called when new items are recognized in the camera feed.
    func dataScanner(_ scanner: DataScannerViewController, didRecognize items: [RecognizedItem]) {
        print("[TiScannerModule] didRecognize called with \(items.count) items.")
        for item in items {
            switch item {
            case .barcode(let barcode):
                let payload = barcode.payloadStringValue ?? ""
                print("[TiScannerModule] Recognized barcode payload: '\(payload)'")
                if !payload.isEmpty {
                    // Fire the barcode event to Titanium.
                    fireEvent("barcode", with: ["value": payload])
                    // Log and then dismiss the scanner.
                    DispatchQueue.main.async {
                        scanner.stopScanning()
                        scanner.dismiss(animated: true, completion: {
                            print("[TiScannerModule] Scanner dismissed after barcode detection.")
                        })
                        self._barcodeScanner = nil
                    }
                    // Once a barcode is detected, break out.
                    return
                } else {
                    print("[TiScannerModule] Barcode payload is empty.")
                }
            case .text(let text):
                print("[TiScannerModule] Recognized text: '\(text.transcript)'")
            default:
                print("[TiScannerModule] Recognized unknown item.")
            }
        }
    }
    
    // Optional: Called when new items are added.
    func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
      print("[TiScannerModule] didAdd called – added \(addedItems.count) items; total \(allItems.count).")
      for item in addedItems {
        switch item {
        case .barcode(let barcode):
          let payload = barcode.payloadStringValue ?? ""
          print("[TiScannerModule] Recognized barcode payload: '\(payload)'")
          if !payload.isEmpty {
            // Fire the barcode event to Titanium.
            fireEvent("barcode", with: ["value": payload])
            // Stop scanning and dismiss.
            DispatchQueue.main.async {
              scanner.stopScanning()
              scanner.dismiss(animated: true) {
                print("[TiScannerModule] Scanner dismissed after barcode detection.")
              }
              self._barcodeScanner = nil
            }
            return
          } else {
            print("[TiScannerModule] Barcode payload is empty.")
          }
        case .text(let text):
          print("[TiScannerModule] Recognized text: '\(text.transcript)'")
        default:
          print("[TiScannerModule] Recognized unknown item.")
        }
      }
    }
    
    // Optional: Called when items are updated.
    func dataScanner(_ scanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        print("[TiScannerModule] didUpdate called – updated \(updatedItems.count) items.")
    }
    
    // Called when the user taps on a recognized item.
    func dataScanner(_ scanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        print("[TiScannerModule] didTapOn called for item: \(item)")
    }
    
    // Called when the scanner is dismissed.
    func dataScannerDidDismiss(_ scanner: DataScannerViewController) {
        print("[TiScannerModule] Scanner was dismissed by the user.")
        fireEvent("cancel")
        _barcodeScanner = nil
    }
    
    // Called if an error occurs during scanning.
    func dataScanner(_ scanner: DataScannerViewController, didEncounterError error: Error) {
        print("[TiScannerModule] Scanner encountered error: \(error.localizedDescription)")
        fireEvent("error", with: ["error": error.localizedDescription])
        scanner.dismiss(animated: true, completion: nil)
        _barcodeScanner = nil
    }
}


// MARK: Utils to generate a centered A4 PDF

extension TiScannerModule {
  func A4PDFDataFromCentered(image: UIImage, with padding: Float) -> Data? {
    let A4_WIDTH: Float = 595.2
    let A4_HEIGHT: Float = 841.8
    let pdfData = NSMutableData()
    let pdfConsumer = CGDataConsumer(data: pdfData as CFMutableData)!
    let imageWidth = A4_WIDTH - (padding * 2)
    let imageHeight = round(CGFloat(imageWidth) * (image.size.height / image.size.width))
    var mediaBox = CGRect(x: 0, y: 0, width: CGFloat(A4_WIDTH), height: CGFloat(A4_HEIGHT))
    let imageBox = CGRect(x: CGFloat((A4_WIDTH / 2) - (imageWidth / 2)),
                           y: (CGFloat(A4_HEIGHT) / 2) - (imageHeight / 2),
                           width: CGFloat(imageWidth),
                           height: CGFloat(imageHeight))
    let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil)!
    pdfContext.beginPage(mediaBox: &mediaBox)
    pdfContext.draw(image.cgImage!, in: imageBox)
    pdfContext.endPage()
    pdfContext.closePDF()
    return pdfData as Data
  }
}
#endif

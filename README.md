# Titanium iOS 13+ Document & Barcode Scanner

Use the iOS 13+ `VisionKit` document scanner API in Appcelerator Titanium—now enhanced with barcode scanning using the iOS 16+ `DataScannerViewController`.  
Pro tip: Combine with [Ti.Vision](https://github.com/hansemannn/titanium-vision) to apply machine learning to the detected document.

<img src="./example.gif" width="400" />

## Requirements

- **Document scanning:** iOS 13+
- **Barcode scanning:** iOS 16+ (requires a device with an Apple Neural Engine)
- **Titanium SDK:** 8.2.0+
- **Permissions:** Granted camera permissions

## APIs

### Methods

- **`showScanner`**  
  Presents the document scanner.

- **`showBarcodeScanner`**  
  Presents the barcode scanner (iOS 16+).  
  The barcode scanner detects common symbologies (e.g., EAN13, EAN8, UPC/E, GS1 DataBar, Code128).

- **`imageOfPageAtIndex(index)`**  
  Returns an image blob for the specified page (after the `success` event).

- **`pdfOfPageAtIndex(index)`**  
  Returns a PDF blob for the specified page (after the `success` event).

- **`pdfOfAllPages(params)`**  
  Returns a PDF blob for all pages (after the `success` event).  
  *Params:* The dictionary can include `resizeImages` (Boolean) and `padding` (number) to generate resized A4 PDFs.

### Events

- **`success`**  
  Fired when the document scanner successfully captures a document.

- **`barcode`**  
  Fired when a barcode is successfully scanned (iOS 16+).  
  The event object contains `value`, which holds the scanned barcode payload.

- **`error`**  
  Fired when an error occurs.

- **`cancel`**  
  Fired when the user cancels the scanner.

## Example

The following example demonstrates how to use both document and barcode scanning:

```js
import Scanner from 'ti.scanner';

const win = Ti.UI.createWindow({
    backgroundColor: '#fff'
});

// Button to launch document scanning
const docBtn = Ti.UI.createButton({
    title: 'Scan Document',
    top: 50
});
docBtn.addEventListener('click', () => {
    Ti.Media.requestCameraPermissions(event => {
        if (!event.success) {
            alert('No camera permissions');
            return;
        }
        Scanner.showScanner();
    });
});

// Button to launch barcode scanning (iOS 16+)
const barcodeBtn = Ti.UI.createButton({
    title: 'Scan Barcode',
    bottom: 50
});
barcodeBtn.addEventListener('click', () => {
    Ti.Media.requestCameraPermissions(event => {
        if (!event.success) {
            alert('No camera permissions');
            return;
        }
        Scanner.showBarcodeScanner();
    });
});

// Document scanning events
Scanner.addEventListener('cancel', () => {
    Ti.API.warn('Cancelled …');
});

Scanner.addEventListener('error', event => {
    Ti.API.error('Errored …');
    Ti.API.error(event.error);
});

Scanner.addEventListener('success', event => {
    Ti.API.warn('Document scan succeeded …');
    Ti.API.warn(event);

    const win2 = Ti.UI.createWindow({
        backgroundColor: '#333'
    });

    const image = Ti.UI.createImageView({
        height: '70%',
        image: Scanner.imageOfPageAtIndex(0) // Alternatively, use pdfOfPageAtIndex(0)
    });

    win2.add(image);
    win2.open();
});

// Barcode scanning event (iOS 16+)
Scanner.addEventListener('barcode', event => {
    Ti.API.info('Barcode detected: ' + event.value);
    // Process the barcode value or dismiss the scanner as needed.
});

win.add(docBtn);
win.add(barcodeBtn);
win.open();
```

License

MIT

Author

Hans Knöchel

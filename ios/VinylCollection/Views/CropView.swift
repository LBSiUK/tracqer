import SwiftUI
import UIKit

// MARK: - Camera + Crop flow (single fullScreenCover, no chained presentations)

/// Host view controller that presents UIImagePickerController from viewDidAppear,
/// guaranteeing it's in the window hierarchy before attempting presentation.
/// Using a UIViewController subclass avoids the race where updateUIViewController
/// fires before the hosting controller is visible.
final class CameraContainerVC: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    var onCancel:  (() -> Void)?
    private var hasPresented = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPresented else { return }
        hasPresented = true

        let picker = UIImagePickerController()
        picker.sourceType        = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate          = self
        present(picker, animated: true)
    }
}

extension CameraContainerVC: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let img = info[.originalImage] as? UIImage {
            picker.dismiss(animated: true) { self.onCapture?(img) }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { self.onCancel?() }
    }
}

struct CameraHostView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CameraContainerVC {
        let vc = CameraContainerVC()
        vc.view.backgroundColor = .black
        vc.onCapture = { img in capturedImage = img }
        vc.onCancel  = { onCancel() }
        return vc
    }

    func updateUIViewController(_ vc: CameraContainerVC, context: Context) {}
}

/// Single-cover wrapper: shows camera, then transitions to crop in the same cover.
struct CameraAndCropView: View {
    let aspectRatio: CGFloat
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var capturedImage: UIImage? = nil

    var body: some View {
        if let image = capturedImage {
            CropView(image: image, aspectRatio: aspectRatio) { cropped in
                onComplete(cropped)
            } onCancel: {
                capturedImage = nil   // "Retake" — go back to camera
            }
        } else {
            CameraHostView(capturedImage: $capturedImage, onCancel: onCancel)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Identifiable wrapper so fullScreenCover(item:) works with UIImage

struct CropItem: Identifiable {
    let id    = UUID()
    let image: UIImage
    let ratio: CGFloat
}

// MARK: - Crop view

struct CropView: View {
    let image: UIImage
    let aspectRatio: CGFloat
    let onCrop:   (UIImage) -> Void
    let onCancel: () -> Void

    @State private var offset: CGSize = .zero
    @State private var cropScale: CGFloat = 1.0
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchDelta: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let layout        = CropLayout(container: geo.size, image: image, ratio: aspectRatio)
            let liveScale     = max(0.15, min(1.0, cropScale * pinchDelta))
            let effectiveSize = CGSize(width:  layout.cropSize.width  * liveScale,
                                       height: layout.cropSize.height * liveScale)
            let live     = layout.clamp(offset + dragDelta, cropSize: effectiveSize)
            let cropRect = layout.cropRect(offset: live, cropSize: effectiveSize)

            // Safe area top so buttons sit below the status bar / Dynamic Island
            let topPad = geo.safeAreaInsets.top + 8

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Semi-transparent overlay with crop hole
                CropMaskShape(cropRect: cropRect)
                    .fill(Color.black.opacity(0.6), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Border, grid, corner handles
                Canvas { ctx, _ in
                    ctx.stroke(Path(cropRect), with: .color(.white.opacity(0.9)), lineWidth: 1)

                    var grid = Path()
                    for i in 1...2 {
                        let x = cropRect.minX + cropRect.width  / 3 * CGFloat(i)
                        let y = cropRect.minY + cropRect.height / 3 * CGFloat(i)
                        grid.move(to: .init(x: x, y: cropRect.minY))
                        grid.addLine(to: .init(x: x, y: cropRect.maxY))
                        grid.move(to: .init(x: cropRect.minX, y: y))
                        grid.addLine(to: .init(x: cropRect.maxX, y: y))
                    }
                    ctx.stroke(grid, with: .color(.white.opacity(0.35)), lineWidth: 0.5)

                    let arm: CGFloat = 22
                    let lw:  CGFloat =  3
                    var h = Path()
                    h.move(to: .init(x: cropRect.minX, y: cropRect.minY + arm))
                    h.addLine(to: .init(x: cropRect.minX, y: cropRect.minY))
                    h.addLine(to: .init(x: cropRect.minX + arm, y: cropRect.minY))
                    h.move(to: .init(x: cropRect.maxX - arm, y: cropRect.minY))
                    h.addLine(to: .init(x: cropRect.maxX, y: cropRect.minY))
                    h.addLine(to: .init(x: cropRect.maxX, y: cropRect.minY + arm))
                    h.move(to: .init(x: cropRect.minX, y: cropRect.maxY - arm))
                    h.addLine(to: .init(x: cropRect.minX, y: cropRect.maxY))
                    h.addLine(to: .init(x: cropRect.minX + arm, y: cropRect.maxY))
                    h.move(to: .init(x: cropRect.maxX - arm, y: cropRect.maxY))
                    h.addLine(to: .init(x: cropRect.maxX, y: cropRect.maxY))
                    h.addLine(to: .init(x: cropRect.maxX, y: cropRect.maxY - arm))
                    ctx.stroke(h, with: .color(.white), lineWidth: lw)
                }
                .allowsHitTesting(false)

                // Invisible drag target (moves the crop box)
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: cropRect.width, height: cropRect.height)
                    .position(x: cropRect.midX, y: cropRect.midY)
                    .gesture(
                        DragGesture()
                            .updating($dragDelta) { v, state, _ in state = v.translation }
                            .onEnded { v in
                                offset = layout.clamp(offset + v.translation, cropSize: effectiveSize)
                            }
                    )

                // Buttons — X top-left, ✓ top-right, both below safe area
                VStack {
                    HStack {
                        Button { onCancel() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .padding(.leading, 16)

                        Spacer()

                        Button {
                            let finalScale  = max(0.15, min(1.0, cropScale))
                            let finalSize   = CGSize(width:  layout.cropSize.width  * finalScale,
                                                     height: layout.cropSize.height * finalScale)
                            let finalOffset = layout.clamp(offset, cropSize: finalSize)
                            let finalRect   = layout.cropRect(offset: finalOffset, cropSize: finalSize)
                            onCrop(layout.crop(image: image, rect: finalRect))
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.orange)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 16)
                    }
                    .padding(.top, topPad)

                    Spacer()
                }
            }
            // Pinch anywhere on screen to resize the crop box (aspect ratio locked)
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinchDelta) { value, state, _ in state = value }
                    .onEnded { value in
                        cropScale = max(0.15, min(1.0, cropScale * value))
                        let newSize = CGSize(width:  layout.cropSize.width  * cropScale,
                                             height: layout.cropSize.height * cropScale)
                        offset = layout.clamp(offset, cropSize: newSize)
                    }
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Crop layout math

struct CropLayout {
    let imageDisplaySize: CGSize
    let imageOrigin: CGPoint
    let cropSize: CGSize

    init(container: CGSize, image: UIImage, ratio: CGFloat) {
        let imgR = image.size.width / image.size.height
        let conR = container.width / container.height
        if imgR > conR {
            let w = container.width
            let h = w / imgR
            imageDisplaySize = CGSize(width: w, height: h)
            imageOrigin      = CGPoint(x: 0, y: (container.height - h) / 2)
        } else {
            let h = container.height
            let w = h * imgR
            imageDisplaySize = CGSize(width: w, height: h)
            imageOrigin      = CGPoint(x: (container.width - w) / 2, y: 0)
        }
        let dr = imageDisplaySize.width / imageDisplaySize.height
        if dr > ratio {
            let h = imageDisplaySize.height
            cropSize = CGSize(width: h * ratio, height: h)
        } else {
            let w = imageDisplaySize.width
            cropSize = CGSize(width: w, height: w / ratio)
        }
    }

    private var imageCenter: CGPoint {
        CGPoint(x: imageOrigin.x + imageDisplaySize.width  / 2,
                y: imageOrigin.y + imageDisplaySize.height / 2)
    }

    func cropRect(offset: CGSize, cropSize: CGSize) -> CGRect {
        CGRect(x: imageCenter.x + offset.width  - cropSize.width  / 2,
               y: imageCenter.y + offset.height - cropSize.height / 2,
               width: cropSize.width, height: cropSize.height)
    }

    func clamp(_ offset: CGSize, cropSize: CGSize) -> CGSize {
        let mx = (imageDisplaySize.width  - cropSize.width)  / 2
        let my = (imageDisplaySize.height - cropSize.height) / 2
        return CGSize(width:  max(-mx, min(mx, offset.width)),
                      height: max(-my, min(my, offset.height)))
    }

    /// Crops using UIGraphics so UIImage.imageOrientation is respected correctly.
    func crop(image: UIImage, rect: CGRect) -> UIImage {
        let scale = image.size.width / imageDisplaySize.width
        let destSize = CGSize(width: rect.width * scale, height: rect.height * scale)
        let srcOrigin = CGPoint(x: -(rect.minX - imageOrigin.x) * scale,
                                y: -(rect.minY - imageOrigin.y) * scale)
        UIGraphicsBeginImageContextWithOptions(destSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        image.draw(in: CGRect(origin: srcOrigin,
                              size: CGSize(width: image.size.width, height: image.size.height)))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

// MARK: - Overlay mask shape

struct CropMaskShape: Shape {
    let cropRect: CGRect
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        p.addRect(cropRect)
        return p
    }
}

// MARK: - CGSize + operator

private func + (lhs: CGSize, rhs: CGSize) -> CGSize {
    CGSize(width: lhs.width + rhs.width, height: lhs.height + rhs.height)
}

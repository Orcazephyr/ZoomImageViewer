//
//  FullScreenImageView.swift
//  ZoomImageViewer
//
//  Created by Ryan Lintott on 2020-09-21.
//

import SwiftUI
import UIKit

struct FullScreenImageView<CloseButtonStyle: ButtonStyle>: View {
    @Binding var uiImage: UIImage?
    var watermark: UIImage?
    var baseImage: UIImage?
    let closeButtonStyle: CloseButtonStyle
    
    init(uiImage: Binding<UIImage?>, closeButtonStyle: CloseButtonStyle, onDismiss: (() -> Void)? = nil, watermark: UIImage?) {
        self._uiImage = uiImage
        self.closeButtonStyle = closeButtonStyle
        self.onDismiss = onDismiss
        self.watermark = watermark
        self.baseImage = uiImage.wrappedValue
    }
    var onDismiss: (() -> Void)? // Optional closure called when the view disappears
    @State private var isInteractive: Bool = true
    @State private var zoomState: ZoomState = .min
    @State private var offset: CGSize = .zero
    @State private var predictedOffset: CGSize = .zero
    @State private var backgroundOpacity: Double = .zero
    @State private var imageOpacity: Double = .zero
    
    @GestureState private var isDragging = false
    
    let animationSpeed = 0.4
    let dismissThreshold: CGFloat = 200
    let opacityAtDismissThreshold: Double = 0.8
    let dismissDistance: CGFloat = 1000
    
    var dragImageGesture: some Gesture {
        DragGesture()
            .updating($isDragging) { value, gestureState, transaction in
                gestureState = true
            }
            .onChanged { value in
                predictedOffset = value.predictedEndTranslation
                onDrag(translation: value.translation)
            }
            .onEnded { value in
                predictedOffset = value.predictedEndTranslation
            }
    }
    @State private var image = UIImage()
    @State private var showShareSheet = false

    var body: some View {
        /// This helps center animated rotations
        Color.clear.overlay(
            GeometryReader { proxy in
                if let uiImage = uiImage {
                    ImageZoomView(proxy: proxy, isInteractive: $isInteractive, zoomState: $zoomState, maximumZoomScale: 2.0, content: UIImageView(image: uiImage))
                        .accessibilityIgnoresInvertColors()
                        .offset(offset)
                        /// For testing contentShape
//                        .overlay(
//                            Rectangle()
//                                .scaleToFit(CGSize(width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing, height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom), aspectRatio: uiImage.size.aspectRatio)
//                                .fill(Color.red.opacity(0.5))
//                                .allowsHitTesting(false)
//                        )
                        .contentShape(
                            Rectangle()
                                .scaleToFit(
                                    CGSize(
                                        width: proxy.size.width + proxy.safeAreaInsets.leading + proxy.safeAreaInsets.trailing,
                                        height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom
                                    ),
                                    aspectRatio: uiImage.size.aspectRatio
                                )
                        )
                        .gesture(zoomState == ZoomState.min ? dragImageGesture : nil)
                        .onChange(of: isDragging, perform: { isDragging in
                            if !isDragging {
                                onDragEnded(predictedEndTranslation: predictedOffset)
                            }
                        })
                        .edgesIgnoringSafeArea(.all)
                        .background(
                            Color.black.padding(-.maximum(proxy.size.height, proxy.size.width)).edgesIgnoringSafeArea(.all)
                                .opacity(backgroundOpacity)
                        )
                        .overlay(
                            HStack {                                
                                Button {
                                    withAnimation(.easeOut(duration: animationSpeed)) {
                                        self.uiImage = nil
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.title)
                                        .accessibilityLabel("Close")
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(closeButtonStyle)
                                .opacity(backgroundOpacity)
                                Button {
                                    // Share watermarked image
                                    let watermarked = watermarkImage(baseImage: baseImage ?? UIImage(), watermarkImage: watermark ?? UIImage())
                                    self.image = watermarked
                                    showShareSheet = true
                                } label: {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title)
                                        .accessibilityLabel("Share")
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(closeButtonStyle)
                                .opacity(backgroundOpacity)
                            }, alignment: .topLeading
                        )
                        .sheet(isPresented: $showShareSheet, content: {
                            ActivityView(activityItems: [image] as [Any], applicationActivities: nil)
                        })
                        .opacity(imageOpacity)
                        .onAppear(perform: onAppear)
                        .onDisappear(perform: onDisappear)
                }
            }
                .onChange(of: uiImage) { uiImage in
                    /// Included to prevent errors when image is dismissed and clicked quickly again
                    uiImage == nil ? onDisappear() : onAppear()
                }
        )
    }
    
    func onAppear() {
        offset = .zero
        backgroundOpacity = 1
        withAnimation(Animation.easeIn(duration: animationSpeed)) {
            imageOpacity = 1
        }
    }
    
    func onDisappear() {
        backgroundOpacity = .zero
        imageOpacity = .zero
        onDismiss!()
    }
    
    func onDrag(translation: CGSize) {
        isInteractive = false
        offset = translation
        backgroundOpacity = 1 - Double(offset.magnitude / dismissThreshold) * (1 - opacityAtDismissThreshold)
    }
    
    func onDragEnded(predictedEndTranslation: CGSize) {
        if predictedEndTranslation.magnitude > dismissThreshold {
            withAnimation(Animation.linear(duration: animationSpeed)) {
                offset = .max(predictedEndTranslation, predictedEndTranslation.normalized * dismissDistance)
                backgroundOpacity = .zero
            }
            withAnimation(Animation.linear(duration: 0.1).delay(animationSpeed)) {
                uiImage = nil
            }
        } else {
            isInteractive = true
            withAnimation(Animation.easeOut) {
                backgroundOpacity = 1
                offset = .zero
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityView>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityView>) {
    }
}

func watermarkImage(baseImage: UIImage, watermarkImage: UIImage) -> UIImage? {
    let renderer = UIGraphicsImageRenderer(size: baseImage.size)
    
    let watermarkedImage = renderer.image { context in
        // Draw the base image
        baseImage.draw(at: .zero)
        
        // Define the scale as 10% of the base image's shorter dimension
        let scale = 0.1
        let watermarkAspect = watermarkImage.size.width / watermarkImage.size.height
        var watermarkHeight = min(baseImage.size.width, baseImage.size.height) * scale
        var watermarkWidth = watermarkHeight * watermarkAspect

        // Ensure the watermark does not exceed 10% of image's width
        if watermarkWidth > baseImage.size.width * scale {
            watermarkWidth = baseImage.size.width * scale
            watermarkHeight = watermarkWidth / watermarkAspect
        }

        // Calculate position to place it at the bottom right corner with a 5% margin
        let marginX = baseImage.size.width * 0.05
        let marginY = baseImage.size.height * 0.05
        let watermarkX = baseImage.size.width - watermarkWidth - marginX
        let watermarkY = baseImage.size.height - watermarkHeight - marginY
        let watermarkRect = CGRect(x: watermarkX, y: watermarkY, size: CGSize(width: watermarkWidth, height: watermarkHeight))

        // Draw the watermark image
        watermarkImage.draw(in: watermarkRect, blendMode: .normal, alpha: 0.5)  // Adjust alpha as desired
    }

    return watermarkedImage
}

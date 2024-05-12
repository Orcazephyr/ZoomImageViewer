//
//  SwiftUIView.swift
//  
//
//  Created by Ryan Lintott on 2021-01-13.
//

import SwiftUI

/// A view for displaying fullscreen images that supports zooming, panning, and dismissing a zoomed-out image with a drag gesture.
///
/// Close button style is customizable.
public struct ZoomImageViewer<CloseButtonStyle: ButtonStyle>: View {
    @Binding private var uiImage: UIImage?
    private var watermark: UIImage?
    let closeButtonStyle: CloseButtonStyle
    var onDismiss: (() -> Void)?
    
    /// Creates a view with a zoomable image and a close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    ///   - closeButtonStyle: Button style to use for close button.
    public init(uiImage: Binding<UIImage?>, closeButtonStyle: CloseButtonStyle, onDismiss: (() -> Void)?, watermark: UIImage?) {
        self._uiImage = uiImage
        self.closeButtonStyle = closeButtonStyle
        self.onDismiss = onDismiss
        self.watermark = watermark
    }
    
    public var body: some View {
        if uiImage != nil {
            FullScreenImageView(uiImage: $uiImage, closeButtonStyle: closeButtonStyle, onDismiss: onDismiss, watermark: watermark)
        }
    }
}

public extension ZoomImageViewer<ZoomImageCloseButtonStyle> {
    /// Creates a view with a zoomable image and a default close button.
    /// - Parameters:
    ///   - uiImage: Image to present.
    init(uiImage: Binding<UIImage?>, onDismiss: (() -> Void)?, watermark: UIImage?) {
        self._uiImage = uiImage
        self.closeButtonStyle = ZoomImageCloseButtonStyle()
        self.onDismiss = onDismiss
        self.watermark = watermark
    }
}

//
//  ZoomableImageView.swift
//  DateMap
//
//  Created by 김기중 on 7/16/26.
//

import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()

        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.zoomScale = 1

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.alwaysBounceVertical = false
        scrollView.bounces = false
        scrollView.decelerationRate = .fast
        scrollView.delaysContentTouches = false
        scrollView.canCancelContentTouches = true

        scrollView.backgroundColor = .black

        let imageView = UIImageView(image: image)

        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.leadingAnchor
            ),
            imageView.trailingAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.trailingAnchor
            ),
            imageView.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor
            ),
            imageView.bottomAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.bottomAnchor
            ),
            imageView.widthAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.widthAnchor
            ),
            imageView.heightAnchor.constraint(
                equalTo: scrollView.frameLayoutGuide.heightAnchor
            )
        ])

        let doubleTapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(
                Coordinator.handleDoubleTap(_:)
            )
        )

        doubleTapGesture.numberOfTapsRequired = 2
        imageView.addGestureRecognizer(doubleTapGesture)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        return scrollView
    }

    func updateUIView(
        _ scrollView: UIScrollView,
        context: Context
    ) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?

        func viewForZooming(
            in scrollView: UIScrollView
        ) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(
            _ scrollView: UIScrollView
        ) {
            centerImage(
                in: scrollView
            )
        }

        @objc
        func handleDoubleTap(
            _ gesture: UITapGestureRecognizer
        ) {
            guard
                let scrollView,
                let imageView
            else {
                return
            }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(
                    scrollView.minimumZoomScale,
                    animated: true
                )
                return
            }

            let targetZoomScale: CGFloat = 2.5
            let tapPoint = gesture.location(
                in: imageView
            )

            let zoomWidth =
                scrollView.bounds.width /
                targetZoomScale

            let zoomHeight =
                scrollView.bounds.height /
                targetZoomScale

            let zoomRect = CGRect(
                x: tapPoint.x - zoomWidth / 2,
                y: tapPoint.y - zoomHeight / 2,
                width: zoomWidth,
                height: zoomHeight
            )

            scrollView.zoom(
                to: zoomRect,
                animated: true
            )
        }

        private func centerImage(
            in scrollView: UIScrollView
        ) {
            guard let imageView else {
                return
            }

            let horizontalInset = max(
                0,
                (
                    scrollView.bounds.width -
                    imageView.frame.width
                ) / 2
            )

            let verticalInset = max(
                0,
                (
                    scrollView.bounds.height -
                    imageView.frame.height
                ) / 2
            )

            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }
    }
}

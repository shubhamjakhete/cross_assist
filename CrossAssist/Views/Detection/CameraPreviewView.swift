//
//  CameraPreviewView.swift
//  CrossAssist
//
//  Created by Shubham Jakhete on 3/7/26.
//

import ARKit
import SwiftUI

/// A UIViewRepresentable that displays the ARSession camera feed using ARSCNView.
struct CameraPreviewView: UIViewRepresentable {
    let session: ARSession

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView()
        view.session = session
        view.automaticallyUpdatesLighting = false
        view.showsStatistics = false
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if uiView.session !== session {
            uiView.session = session
        }
    }
}

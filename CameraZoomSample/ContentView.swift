//
//  ContentView.swift
//  CameraZoomSample
//
//  Created by paku on 2024/04/11.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject var viewModel = ViewModel()
    
    var body: some View {
        VStack {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(contentMode: .fit)
                
                Button(action: {
                    viewModel.image = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: 80, height: 80, alignment: .center)
                }
            } else {
                let aspectRatio = viewModel.imageAspectRatio ?? 1.0
                CALayerView(
                    caLayer: viewModel.previewLayer,
                    aspectRatio: aspectRatio
                )
                .onAppear {
                    viewModel.startSession()
                }
                
                Button(action: {
                    viewModel.captureImageOnce()
                }) {
                    Image(systemName: "camera.circle.fill")
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: 80, height: 80, alignment: .center)
                }
                
                Slider(
                    value: $viewModel.linearZoomFactor,
                    in: Float(viewModel.minFactor)...Float(viewModel.maxFactor)
                ).padding()


                Spacer()
            }
        }
    }
}

struct CALayerView: UIViewRepresentable {
    var caLayer: CALayer?
    var aspectRatio: CGFloat?

    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        view.contentMode = .scaleAspectFill
        if let caLayer {
            view.layer.addSublayer(caLayer)
        }
        updateViewSize(view)

        return view
    }


    func updateUIView(_ uiView: UIViewType, context: Context) {
        updateViewSize(uiView)
    }
    
    private func updateViewSize(_ view: UIView) {
        guard let caLayer else {
            return
        }
        let size = UIScreen.main.bounds.size
        let aspectRatio = aspectRatio ?? 1.0
        let contentSize = CGSize(width: size.width, height: size.width / aspectRatio)
        view.frame = CGRect(origin: .zero, size: contentSize)
        caLayer.frame = view.frame
    }
}


struct CameraPreview: UIViewRepresentable {
    var previewLayer: CALayer?
    var aspectRatio: CGFloat?
    
    func makeUIView(context: Context) -> UIView  {
        let view = UIView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .red
        if let previewLayer {
            previewLayer.frame = view.frame
            view.layer.addSublayer(previewLayer)
            
            let size = UIScreen.main.bounds.size
            let aspectRatio = self.aspectRatio ?? 1.0
            let contentSize = CGSize(width: size.width, height: size.width / aspectRatio)
            view.frame = CGRect(origin: .zero, size: contentSize)
            previewLayer.frame = view.frame
        }
        
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        guard let previewLayer else { return }
        
        let size = UIScreen.main.bounds.size
        let aspectRatio = self.aspectRatio ?? 1.0
        let contentSize = CGSize(width: size.width, height: size.width / aspectRatio)
        uiView.frame = CGRect(origin: .zero, size: contentSize)
        previewLayer.frame = uiView.frame
    }
}

#Preview {
    ContentView()
}

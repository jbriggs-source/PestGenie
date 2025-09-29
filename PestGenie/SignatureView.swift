import SwiftUI

struct SignatureView: View {
    var onSigned: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentDrawing: [CGPoint] = []
    @State private var drawings: [[CGPoint]] = []
    var body: some View {
        VStack {
            Text("Sign below").font(.headline).padding()
            Canvas { context, size in
                for drawing in drawings {
                    var path = Path()
                    if let first = drawing.first {
                        path.move(to: first)
                        for p in drawing.dropFirst() {
                            path.addLine(to: p)
                        }
                        context.stroke(path, with: .color(.blue), lineWidth: 2)
                    }
                }
                if let first = currentDrawing.first {
                    var path = Path()
                    path.move(to: first)
                    for p in currentDrawing.dropFirst() {
                        path.addLine(to: p)
                    }
                    context.stroke(path, with: .color(.blue), lineWidth: 2)
                }
            }
            .background(Color.white)
            .gesture(DragGesture(minimumDistance: 0.1, coordinateSpace: .local)
                .onChanged { value in
                    currentDrawing.append(value.location)
                }
                .onEnded { _ in
                    drawings.append(currentDrawing)
                    currentDrawing = []
                }
            )
            .clipShape(Rectangle())
            .border(Color.gray)
            .padding()
            HStack {
                Button("Clear") {
                    drawings = []
                    currentDrawing = []
                }
                .padding()
                Spacer()
                Button("Done") {
                    let renderer = ImageRenderer(content: signatureImage)
                    if let img = renderer.uiImage, let data = img.pngData() {
                        onSigned(data)
                    }
                    dismiss()
                }
                .padding()
            }
        }
    }
    private var signatureImage: some View {
        Canvas { context, size in
            for drawing in drawings {
                var path = Path()
                if let first = drawing.first {
                    path.move(to: first)
                    for p in drawing.dropFirst() {
                        path.addLine(to: p)
                    }
                    context.stroke(path, with: .color(.black), lineWidth: 2)
                }
            }
        }
        .frame(width: 300, height: 200)
        .background(Color.white)
    }
}
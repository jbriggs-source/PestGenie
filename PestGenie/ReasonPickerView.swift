import SwiftUI

/// A view that presents available reason codes as a picker inside a sheet. When
/// the user taps a reason, the selection is stored and the sheet will be
/// dismissed. This component is used both for skipping and reordering jobs.
struct ReasonPickerView: View {
    @Binding var reason: ReasonCode?
    @Environment(\.presentationMode) private var presentationMode
    var body: some View {
        NavigationView {
            List {
                ForEach(ReasonCode.allCases) { code in
                    Button(code.rawValue) {
                        reason = code
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Reason")
        }
    }
}
import SwiftUI

/// A view that presents available reason codes as a picker inside a sheet. When
/// the user taps a reason, the selection is stored and the sheet will be
/// dismissed. This component is used both for skipping and reordering jobs.
struct ReasonPickerView: View {
    @Binding var reason: ReasonCode?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(ReasonCode.allCases) { code in
                    Button(code.rawValue) {
                        reason = code
                        dismiss()
                    }
                }
            }
            .navigationTitle("Reason")
        }
    }
}
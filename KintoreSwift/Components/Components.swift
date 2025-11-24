//  Components.swift

import SwiftUI

struct RoundedFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .font(.body)
    }
}

struct SegmentedPickerRow: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)

            Picker(title, selection: $selection) {
                Text("左").tag("L")
                Text("右").tag("R")
                Text("なし").tag("")
            }
            .pickerStyle(.segmented)
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .font(.headline)
        }
    }
}

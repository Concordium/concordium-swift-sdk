import ConcordiumSwiftSdk
import SwiftUI

struct AccountView: View {
    @State private var sender: String = ""
    @State private var receiver: String = ""
    @State private var amount: String = ""

    var body: some View {
        VStack {
            buildInput(for: $sender, withLabel: "From")
            buildInput(for: $receiver, withLabel: "To")
            buildInput(for: $amount, withLabel: "Amount (µϾ)")

            BlueButton("Submit") {}
        }
        Spacer()
    }

    private func buildInput(for variable: Binding<String>, withLabel label: String) -> some View {
        VStack {
            Text(label)
            TextField("", text: variable)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }.padding()
    }
}

#Preview {
    AccountView()
}

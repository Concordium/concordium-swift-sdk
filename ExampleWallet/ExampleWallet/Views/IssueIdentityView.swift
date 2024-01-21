import SwiftUI

enum DummyProvider: String, CaseIterable {
    case concordium = "Concordium Testnet IP"
    case digitalTrust = "Digital Trust Solutions TestNet"
    case notabene = "Notabene (Staging)"
}

struct IssueIdentityView: View {
    @State private var selectedProvider = DummyProvider.concordium

    var body: some View {
        VStack {
            Picker("Select an identity provider", selection: $selectedProvider) {
                ForEach(DummyProvider.allCases, id: \.self) {
                    Text($0.rawValue)
                }
            }
            .pickerStyle(MenuPickerStyle())

            BlueButton("Submit") {
                print("Selected provider: \(selectedProvider)")
            }
            .padding()
        }
        .padding()
    }
}

#Preview {
    IssueIdentityView()
}

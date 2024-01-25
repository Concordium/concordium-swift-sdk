import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationView {
            VStack {
                getNavigationLinkTo(destination: SeedPhraseView(), withLabel: "Seed phrase view")

                BlueButton("Identity recovery view") {}

                BlueButton("Identity view") {}

                BlueButton("Account view") {}

                Spacer()
            }
        }
    }

    private func getNavigationLinkTo<Destination: View>(destination: Destination, withLabel label: String) -> some View {
        NavigationLink(destination: destination) {
            Text(label).modifier(BlueTextStyle())
        }.padding()
    }
}

#Preview {
    MainView()
}

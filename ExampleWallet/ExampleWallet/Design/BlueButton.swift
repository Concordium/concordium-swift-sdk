import SwiftUI

struct BlueButton: View {
    var title: String
    var action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title).modifier(BlueTextStyle())
        }
        .padding()
    }
}

#Preview {
    BlueButton("Test") { print("Blue button pressed") }
}

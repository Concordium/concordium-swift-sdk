import SwiftUI

struct BlueTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(Color.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(8)
    }
}

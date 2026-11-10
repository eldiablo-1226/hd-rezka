import SwiftUI
import NukeUI

/// A developer card (used by AboutUsView).
struct PersonCardComponent: View {
    var url: String
    var job: String
    var name: String
    var description: LocalizedStringKey

    var body: some View {
        HStack {
            LazyImage(url: URL(string: url), transaction: Transaction(animation: .easeInOut)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 76)
                        .cornerRadius(50)
                        .padding(16)
                        .transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))
                } else {
                    Color.clear
                        .frame(width: 108, height: 108)
                        .transition(.asymmetric(insertion: .wipe(angle: .degrees(45), blurRadius: 10), removal: .wipe(angle: .degrees(225), blurRadius: 10)))
                }
            }
            VStack(alignment: .leading) {
                Text(name)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(job)
                    .font(.caption)
                    .opacity(0.6)
                Text(description)
                    .font(.callout)
                    .padding(.top, 0.1)
            }
            .padding(.vertical, 16)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(.quinary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

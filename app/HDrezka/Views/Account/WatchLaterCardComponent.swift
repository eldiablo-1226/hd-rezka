import SwiftUI

/// One "continue watching" card: tap opens the details, a long press switches to delete / cancel
/// (body 0x10005d5e8, content 0x10005daf0).
struct WatchLaterCardComponent: View {
    var movie: MovieWatchLater
    var moviePosition: Int
    @State var isRemoveMode: Bool = false
    @State var isPresented: Bool = false
    @Binding var movieList: [MovieWatchLater]

    var body: some View {
        ViewThatFits {
            VStack {
                if !isRemoveMode {
                    HStack {
                        Text(movie.name).bold()
                        Text(movie.details).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .lineLimit(1)
                    .padding(.bottom)
                    HStack(alignment: .bottom) {
                        Text(movie.date)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 5)
                        Spacer()
                        VStack {
                            Text(movie.watchingInfo)
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            if let buttonText = movie.buttonText {
                                Text(buttonText)
                                    .padding(5)
                                    .foregroundStyle(.secondary)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(.secondary, lineWidth: 1)
                                            .foregroundStyle(.secondary))
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .font(.caption)
                } else {
                    HStack {
                        Button {
                            _ = withAnimation(.default) { movieList.remove(at: moviePosition) }
                            Task { try await AccountService().removeWatchingItem(item: movie) }
                        } label: {
                            Text("key_delete").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                        Button {
                            withAnimation(.default) { isRemoveMode = false }
                        } label: {
                            Text("key_cancel")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.primary)
                        }
                        .foregroundStyle(.secondary)
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(15)
            .background(alignment: .center) {
                // The gestures sit on the background shape, as in the binary (closure #2 in closure #1).
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .foregroundStyle(.quinary)
                    .onTapGesture {
                        isPresented.toggle()
                    }
                    .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 10) {
                        withAnimation(.default.speed(1.2)) { isRemoveMode = true }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
            }
        }
        .padding(.horizontal)
        .navigationDestination(isPresented: $isPresented) {
            DetailsView(id: movie.id)
        }
    }
}

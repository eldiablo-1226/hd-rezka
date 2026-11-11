import SwiftUI

struct PersonView: View {
    var id: String
    @State var personDetails: PersonDetailed? = nil
    @State var isNavigated: Bool = false
    /// improvement: the page did not load; 1.6.0 kept spinning (the error was dropped inside the Task).
    @State var loadFailure: PageLoadFailure? = nil
    @Binding var isPresentedMoreSheet: Bool

    var body: some View {
        if personDetails != nil {
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .bottom) {
                    PersonPosterView(url: personDetails!.photo)
                    VStack(alignment: .leading) {
                        Text(personDetails!.nameRu)
                            .font(.title)
                            .bold()
                            .padding(.bottom, 2)
                        Text(personDetails!.nameOrig ?? "")
                            .foregroundStyle(.secondary)
                            .fontWeight(.semibold)
                    }
                    .padding(.bottom, 16)
                    .padding(.leading, 8)
                    Spacer()
                }
                .padding(.bottom, 18)
                .padding(.horizontal, 16)
                VStack(alignment: .leading) {
                    HStack { infoRow("key_career", personDetails!.career) }
                    if personDetails!.birthDate != nil {
                        HStack { infoRow("key_date+of+birth", personDetails!.birthDate!) }
                    }
                    if personDetails!.birthPlace != nil {
                        HStack { infoRow("key_place+of+birth", personDetails!.birthPlace!) }
                    }
                    // Height comes before the death rows in the binary (closure #4 of 0x100093e8c).
                    if personDetails!.height != nil {
                        HStack { infoRow("key_height", personDetails!.height!) }
                    }
                    if personDetails!.deathDate != nil {
                        HStack { infoRow("key_date+of+death", personDetails!.deathDate!) }
                    }
                    if personDetails!.deathPlace != nil {
                        HStack { infoRow("key_place+of+death", personDetails!.deathPlace!) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom)
                VStack {
                    if personDetails!.actorMovies != nil {
                        PesonHorizontalGrid(movies: personDetails!.actorMovies!, title: "key_actor", isNavigated: $isNavigated)
                    }
                    if personDetails!.directorMovies != nil {
                        PesonHorizontalGrid(movies: personDetails!.directorMovies!, title: "key_director", isNavigated: $isNavigated)
                    }
                    if personDetails!.producerMovies != nil {
                        PesonHorizontalGrid(movies: personDetails!.producerMovies!, title: "key_producer", isNavigated: $isNavigated)
                    }
                    if personDetails!.screenwriterMovies != nil {
                        PesonHorizontalGrid(movies: personDetails!.screenwriterMovies!, title: "key_screenwriter", isNavigated: $isNavigated)
                    }
                    if personDetails!.operatorMovies != nil {
                        PesonHorizontalGrid(movies: personDetails!.operatorMovies!, title: "key_operator", isNavigated: $isNavigated)
                    }
                    if personDetails!.editorMovies != nil {
                        PesonHorizontalGrid(movies: personDetails!.editorMovies!, title: "key_editor", isNavigated: $isNavigated)
                    }
                    if personDetails!.artistMovies != nil {
                        PesonHorizontalGrid(movies: personDetails!.artistMovies!, title: "key_artist", isNavigated: $isNavigated)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Going back to the movie (not deeper into a title) reopens the info sheet (0x100096f14).
            .onDisappear {
                if !isNavigated {
                    isPresentedMoreSheet.toggle()
                }
            }
        } else if let loadFailure {
            // Back to the spinner, whose onAppear loads the page again.
            PageLoadFailedView(failure: loadFailure) { self.loadFailure = nil }
        } else {
            ProgressView()
                .onAppear {
                    Task { @MainActor in
                        do {
                            personDetails = try await PeopleRepository().getPersonDetails(id: id)
                        } catch {
                            loadFailure = PageLoadFailure(error: error, statusCode: nil)
                        }
                    }
                }
        }
    }

    /// "<localized label>: " in bold, then the value in secondary color.
    private func infoRow(_ key: String.LocalizationValue, _ value: String) -> Text {
        Text(String(localized: key) + ": ").bold() + Text(value).foregroundColor(.secondary)
    }
}

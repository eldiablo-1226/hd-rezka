import SwiftUI

/// FancyScrollView without a header (0x1000630cc…0x10006386c).
struct AppleMusicStyleScrollView: View {
    var content: AnyView
    @State var offset: CGFloat = 0

    var body: some View {
        ZStack {
            ScrollView {
                ZStack {
                    GeometryReader { geometry -> Text in
                        let minY = geometry.frame(in: .global).minY
                        DispatchQueue.main.async { offset = minY }
                        return Text("")
                    }
                    content
                }
            }
            GeometryReader { geometry in
                BlurView()
                    .opacity(offset < 0 ? 1 : 0)
                    .frame(width: geometry.size.width, height: geometry.safeAreaInsets.top)
                    .position(x: geometry.size.width / 2, y: geometry.safeAreaInsets.top / 2)
                    .edgesIgnoringSafeArea(.top)
            }
        }
        .background(NavigationConfigurator(hidden: true))
    }
}

/// Hides the UIKit navigation bar of the hosting controller (0x1000acab8…0x1000acd90).
private struct NavigationConfigurator: UIViewControllerRepresentable {
    let hidden: Bool

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        uiViewController.navigationController?.navigationBar.isHidden = hidden
        context.coordinator.navigationController = uiViewController.navigationController
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var navigationController: UINavigationController?
    }
}

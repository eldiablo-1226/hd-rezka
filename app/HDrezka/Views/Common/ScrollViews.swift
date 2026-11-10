import SwiftUI

// Embedded copy of nerdsupremacist/FancyScrollView, as in the binary (0x10000fb94…0x10003f828),
// plus the app's own changes: Back/Share buttons in the header and a swipe-back keeping configurator.

enum ScrollUpHeaderBehavior: Equatable, Hashable {
    case parallax
    case sticky
}

enum ScrollDownHeaderBehavior: Equatable, Hashable {
    case offset
    case sticky
}

struct FancyScrollView: View {
    let title: String
    let titleColor: Color
    let headerHeight: CGFloat
    let scrollUpHeaderBehavior: ScrollUpHeaderBehavior
    let scrollDownHeaderBehavior: ScrollDownHeaderBehavior
    let header: AnyView?
    let content: AnyView

    init<A: View>(title: String = "", titleColor: Color = .white, headerHeight: CGFloat = 300, scrollUpHeaderBehavior: ScrollUpHeaderBehavior = .parallax, scrollDownHeaderBehavior: ScrollDownHeaderBehavior = .offset, content: () -> A) {
        self.title = title; self.titleColor = titleColor; self.headerHeight = headerHeight
        self.scrollUpHeaderBehavior = scrollUpHeaderBehavior; self.scrollDownHeaderBehavior = scrollDownHeaderBehavior
        self.header = nil; self.content = AnyView(content())
    }

    init<A: View, B: View>(title: String = "", titleColor: Color = .white, headerHeight: CGFloat = 300, scrollUpHeaderBehavior: ScrollUpHeaderBehavior = .parallax, scrollDownHeaderBehavior: ScrollDownHeaderBehavior = .offset, header: () -> A?, content: () -> B) {
        self.title = title; self.titleColor = titleColor; self.headerHeight = headerHeight
        self.scrollUpHeaderBehavior = scrollUpHeaderBehavior; self.scrollDownHeaderBehavior = scrollDownHeaderBehavior
        // 0x10001049c wraps the `A?` itself (Optional: View), as upstream does: `header` is never nil here.
        self.header = AnyView(header()); self.content = AnyView(content())
    }

    var body: some View {
        if let header {
            return AnyView(
                HeaderScrollView(title: title,
                                 titleColor: titleColor,
                                 headerHeight: headerHeight,
                                 scrollUpBehavior: scrollUpHeaderBehavior,
                                 scrollDownBehavior: scrollDownHeaderBehavior,
                                 header: header,
                                 content: content)
            )
        } else {
            return AnyView(
                AppleMusicStyleScrollView(content: AnyView(
                    VStack {
                        if title != "" {
                            HStack {
                                Text(title)
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                    .fontWeight(.black)
                                    .padding(.horizontal, 16)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                            }
                        }
                        if title != "" {
                            Spacer()
                        }
                        content
                    }
                ))
            )
        }
    }
}

struct HeaderScrollView: View {
    @Environment(\.colorScheme) var colorScheme
    let title: String
    let titleColor: Color
    let headerHeight: CGFloat
    let scrollUpBehavior: ScrollUpHeaderBehavior
    let scrollDownBehavior: ScrollDownHeaderBehavior
    let header: AnyView
    let content: AnyView

    var body: some View {
        GeometryReader { globalGeometry in
            ScrollView {
                VStack(spacing: 0) {
                    GeometryReader { geometry -> AnyView in
                        let geometry = self.geometry(from: geometry, safeArea: globalGeometry.safeAreaInsets)
                        return AnyView(
                            header
                                .frame(width: geometry.width, height: geometry.headerHeight)
                                .clipped()
                                .opacity(sqrt(geometry.largeTitleWeight))
                                .offset(y: geometry.headerOffset)
                        )
                    }
                    .frame(width: globalGeometry.size.width, height: headerHeight)

                    GeometryReader { geometry -> AnyView in
                        let geometry = self.geometry(from: geometry, safeArea: globalGeometry.safeAreaInsets)
                        return AnyView(
                            ZStack {
                                Rectangle()
                                    .fill(Color.clear)
                                    .background(.ultraThinMaterial, ignoresSafeAreaEdges: .all)
                                    .opacity(1 - sqrt(geometry.largeTitleWeight))
                                    .offset(y: geometry.blurOffset)

                                VStack {
                                    if geometry.largeTitleWeight == 1 {
                                        HStack {
                                            BackButton(color: .white)
                                            Spacer()
                                            ShareButton(color: .white)
                                        }
                                        .frame(width: geometry.width, height: 44)
                                    }
                                    Spacer()
                                    HeaderScrollViewTitle(title: title,
                                                          titleColor: titleColor,
                                                          height: 44,
                                                          largeTitle: geometry.largeTitleWeight)
                                        .layoutPriority(1000)
                                }
                                .padding(.top, globalGeometry.safeAreaInsets.top)
                                // fcsel against 44.0 at 0x10003ef24: the title bar never collapses below 44 pt.
                                .frame(width: geometry.width, height: max(geometry.elementsHeight, 44))
                                .offset(y: geometry.elementsOffset)
                            }
                        )
                    }
                    .frame(width: globalGeometry.size.width, height: headerHeight)
                    .zIndex(1000)
                    .offset(y: -headerHeight)

                    content
                        .offset(y: -headerHeight)
                        .padding(.bottom, -headerHeight)
                }
            }
            .edgesIgnoringSafeArea(.top)
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
        .navigationBarHidden(true)
        .background(NavigationConfigurator())
    }
}

extension HeaderScrollView {
    private struct HeaderScrollViewGeometry {
        let width: CGFloat
        let headerHeight: CGFloat
        let elementsHeight: CGFloat
        let headerOffset: CGFloat
        let blurOffset: CGFloat
        let elementsOffset: CGFloat
        let largeTitleWeight: Double
    }

    /// 0x10003e9ec. Field names are guesses (the type is private); the arithmetic is the binary's.
    private func geometry(from geometry: GeometryProxy, safeArea: EdgeInsets) -> HeaderScrollViewGeometry {
        let minY = geometry.frame(in: .global).minY
        if minY > 0 {
            return HeaderScrollViewGeometry(
                width: geometry.size.width,
                headerHeight: scrollUpBehavior == .parallax ? geometry.size.height + minY : geometry.size.height,
                elementsHeight: scrollUpBehavior == .sticky ? geometry.size.height : geometry.size.height + minY,
                headerOffset: -minY,
                blurOffset: -minY,
                elementsOffset: -minY,
                largeTitleWeight: 1)
        }
        let remainingHeight = headerHeight - 44 - safeArea.top
        if remainingHeight > -minY {
            let titleProgress = minY + remainingHeight
            return HeaderScrollViewGeometry(
                width: geometry.size.width,
                headerHeight: geometry.size.height,
                elementsHeight: geometry.size.height + minY,
                headerOffset: scrollDownBehavior == .sticky ? -minY : 0,
                blurOffset: 0,
                elementsOffset: minY * -0.5,
                largeTitleWeight: titleProgress > 45 ? 1 : Double(titleProgress / 45))
        }
        let offset = safeArea.top + (-minY - headerHeight + 44)
        return HeaderScrollViewGeometry(
            width: geometry.size.width,
            headerHeight: geometry.size.height,
            elementsHeight: geometry.size.height + minY,
            headerOffset: offset,
            blurOffset: offset,
            elementsOffset: offset * 0.5 - minY * 0.5,
            largeTitleWeight: 0)
    }
}

/// Keeps the swipe-back gesture alive while HeaderScrollView hides the navigation bar (0x100012750…0x100012ef4).
private struct NavigationConfigurator: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.title = "Some title"
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        if let delegate = uiViewController.navigationController?.interactivePopGestureRecognizer?.delegate,
           !(delegate is Coordinator) {
            context.coordinator.navigationController = uiViewController.navigationController
            context.coordinator.originalDelegate = delegate
            uiViewController.navigationController?.interactivePopGestureRecognizer?.delegate = context.coordinator
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?
        weak var originalDelegate: UIGestureRecognizerDelegate?

        override func forwardingTarget(for aSelector: Selector!) -> Any? { originalDelegate }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if let navigationController, navigationController.isNavigationBarHidden { return true }
            return originalDelegate?.gestureRecognizerShouldBegin?(gestureRecognizer) ?? false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            if let navigationController, navigationController.isNavigationBarHidden { return true }
            return originalDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: touch) ?? false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive event: UIEvent) -> Bool {
            if let navigationController, navigationController.isNavigationBarHidden { return true }
            return originalDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: event) ?? false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
            if let navigationController, navigationController.isNavigationBarHidden { return true }
            return originalDelegate?.gestureRecognizer?(gestureRecognizer, shouldReceive: press) ?? false
        }
    }
}

struct BlurView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blurView, at: 0)
        NSLayoutConstraint.activate([
            blurView.heightAnchor.constraint(equalTo: view.heightAnchor),
            blurView.widthAnchor.constraint(equalTo: view.widthAnchor),
            blurView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            blurView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let effectView = uiView.subviews.first as? UIVisualEffectView else { return }
        effectView.effect = UIBlurEffect(style: context.environment.colorScheme == .dark ? .dark : .light)
    }
}

struct VisualEffectView: UIViewRepresentable {
    var effect: UIVisualEffect?
    func makeUIView(context: Context) -> UIVisualEffectView { UIVisualEffectView() }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) { uiView.effect = effect }
}

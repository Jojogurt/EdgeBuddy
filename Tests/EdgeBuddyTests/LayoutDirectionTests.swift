import SwiftUI
import Testing
@testable import EdgeBuddy

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
@Suite("Layout direction and small fixes")
struct LayoutDirectionTests {
    /// Resolves the frame of a 50 pt square put first in an HStack, the way a
    /// stage does (`anchorPreference` + `GeometryProxy` subscript).
    private func firstItemFrame(_ direction: LayoutDirection) -> CGRect? {
        final class Box { var rect: CGRect? }
        let box = Box()
        let size = CGSize(width: 300, height: 100)
        let root = HStack(spacing: 0) {
            Color.red.frame(width: 50, height: 50).figureAnchor("first")
            Spacer()
        }
        .frame(width: size.width, height: size.height)
        .overlayPreferenceValue(FigureAnchorsKey.self) { items in
            GeometryReader { proxy in
                Color.clear.onAppear { box.rect = items.first.map { proxy[$0.bounds] } }
            }
        }
        .environment(\.layoutDirection, direction)
        #if canImport(UIKit)
        let host = UIHostingController(rootView: root)
        host.view.frame = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        #else
        let host = NSHostingView(rootView: root)
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        #endif
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        return box.rect
    }

    @Test("Anchor frames resolved by the stage are physical, also in right-to-left")
    func framesArePhysical() throws {
        let ltr = try #require(firstItemFrame(.leftToRight))
        let rtl = try #require(firstItemFrame(.rightToLeft))
        print("RTL probe: ltr minX \(ltr.minX), rtl minX \(rtl.minX)")
        #expect(ltr.minX == 0)
        // The first item sits on the right in RTL, and the proxy reports that
        // real position: `.trailing` in the figure's geometry is the physical right.
        #expect(rtl.minX == 250)
    }

    @Test("figureHeight is clamped when set; non-finite falls back to the default")
    func heightClamp() {
        #expect(PeekingFigureMetrics.clampedHeight(4) == PeekingFigureMetrics.minimumHeight)
        #expect(PeekingFigureMetrics.clampedHeight(-20) == PeekingFigureMetrics.minimumHeight)
        #expect(PeekingFigureMetrics.clampedHeight(80) == 80)
        #expect(PeekingFigureMetrics.clampedHeight(.nan) == PeekingFigureMetrics.defaultHeight)
        #expect(PeekingFigureMetrics.clampedHeight(.infinity) == PeekingFigureMetrics.defaultHeight)
        #expect(PeekingFigureMetrics(height: .nan).height == PeekingFigureMetrics.defaultHeight)
    }
}

@Suite("Leading / trailing follow the layout direction")
struct EdgeMappingTests {
    @Test("Left-to-right keeps the edges")
    func leftToRight() {
        #expect(FigureEdges.all.physical(for: .leftToRight) == .all)
        #expect(FigureEdges.leading.physical(for: .leftToRight) == .leading)
    }

    @Test("Right-to-left swaps leading and trailing, keeps top and bottom")
    func rightToLeft() {
        #expect(FigureEdges.leading.physical(for: .rightToLeft) == .trailing)
        #expect(FigureEdges.trailing.physical(for: .rightToLeft) == .leading)
        #expect(FigureEdges([.top, .leading]).physical(for: .rightToLeft) == [.top, .trailing])
        #expect(FigureEdges.all.physical(for: .rightToLeft) == .all)
        #expect(FigureEdges.bottom.physical(for: .rightToLeft) == .bottom)
    }

    @Test("A pin's edge is mapped too; the rest is untouched")
    func pin() {
        let pin = FigurePin(anchor: "a", edge: .leading, pose: .flag, spot: 0.3, animated: false)
        let rtl = pin.physical(for: .rightToLeft)
        #expect(rtl.edge == .trailing && rtl.anchor == pin.anchor && rtl.spot == 0.3 && !rtl.animated)
        #expect(pin.physical(for: .leftToRight) == pin)
    }
}

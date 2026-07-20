@testable import SwiftUIFormattingRules
import XCTest

final class SwiftUIComponentSpacingRuleTests: XCTestCase {
    func testAddsBlankLinesBetweenNestedSwiftUIComponents() {
        let input = """
        import SwiftUI

        struct ExampleView: View {
            var body: some View {
                VStack(alignment: .leading, spacing: 1) {
                    Text("System Pulse")
                        .font(.headline)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)
                        Text("LIVE · 1 SEC")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        """

        let expected = """
        import SwiftUI

        struct ExampleView: View {
            var body: some View {
                VStack(alignment: .leading, spacing: 1) {
                    Text("System Pulse")
                        .font(.headline)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(.green)

                        Text("LIVE · 1 SEC")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        """

        XCTAssertEqual(SwiftUIComponentSpacingRule.format(input), expected)
    }

    func testPreservesExistingBlankLines() {
        let source = """
        import SwiftUI

        struct ExampleView: View {
            var body: some View {
                HStack {
                    Image(systemName: "heart")

                    Text("Favorite")
                }
            }
        }
        """

        XCTAssertEqual(SwiftUIComponentSpacingRule.format(source), source)
    }

    func testDoesNotSplitViewArgumentsOrModifierChains() {
        let source = """
        import SwiftUI

        struct ExampleView: View {
            var body: some View {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        """

        XCTAssertEqual(SwiftUIComponentSpacingRule.format(source), source)
    }
}

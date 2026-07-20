import SwiftFormat

public enum SwiftUIComponentSpacingRule {
    public static func format(_ source: String) -> String {
        let formatter = Formatter(tokenize(source))
        let tokens = formatter.tokens
        let resultBuilderScopes = resultBuilderScopeIndices(in: formatter, tokens: tokens)
        var componentStartsByScope: [Int: [Int]] = [:]

        for index in tokens.indices where isComponentStart(tokens[index]) {
            let lineStart = lineStartIndex(for: index, in: tokens)
            guard isFirstTokenOnLine(index, lineStart: lineStart, in: tokens),
                  let scopeStart = formatter.startOfScope(at: index),
                  tokens[scopeStart] == .startOfScope("{"),
                  resultBuilderScopes.contains(scopeStart)
            else {
                continue
            }

            componentStartsByScope[scopeStart, default: []].append(lineStart)
        }

        let insertionIndices = Set(componentStartsByScope.values.flatMap { componentStarts in
            componentStarts.dropFirst().filter { lineStart in
                needsBlankLine(before: lineStart, in: tokens)
            }
        })

        for index in insertionIndices.sorted(by: >) {
            formatter.insertLinebreak(at: index)
        }

        return sourceCode(for: formatter.tokens)
    }

    private static func resultBuilderScopeIndices(
        in formatter: Formatter,
        tokens: [Token]
    ) -> Set<Int> {
        var resultBuilderScopes: Set<Int> = []

        for index in tokens.indices where tokens[index] == .startOfScope("{") {
            let lineStart = formatter.startOfLine(at: index)
            let lineTokens = tokens[lineStart ..< index].filter {
                !$0.isSpaceOrCommentOrLinebreak
            }
            let tokenStrings = lineTokens.map(\.string)

            if tokenStrings.contains("var"),
               tokenStrings.contains("body"),
               tokenStrings.contains("some"),
               tokenStrings.contains("View")
            {
                resultBuilderScopes.insert(index)
                continue
            }

            if isControlFlowScope(lineTokens),
               let parentScope = containingBrace(before: index, in: formatter, tokens: tokens),
               resultBuilderScopes.contains(parentScope)
            {
                resultBuilderScopes.insert(index)
                continue
            }

            guard !isDeclarationScope(lineTokens),
                  let owner = closureOwner(before: index, in: formatter, tokens: tokens)
            else {
                continue
            }

            if owner.first?.isUppercase == true || viewBuilderModifiers.contains(owner) {
                resultBuilderScopes.insert(index)
            }
        }

        return resultBuilderScopes
    }

    private static func isControlFlowScope(_ lineTokens: [Token]) -> Bool {
        lineTokens.contains { token in
            switch token {
            case .keyword("if"), .keyword("else"), .keyword("switch"):
                true
            default:
                false
            }
        }
    }

    private static func isDeclarationScope(_ lineTokens: [Token]) -> Bool {
        let declarationKeywords: Set = [
            "class", "enum", "extension", "func", "init", "protocol", "struct", "subscript",
        ]
        return lineTokens.contains { token in
            if case let .keyword(keyword) = token {
                return declarationKeywords.contains(keyword)
            }
            return false
        }
    }

    private static func closureOwner(
        before braceIndex: Int,
        in formatter: Formatter,
        tokens: [Token]
    ) -> String? {
        guard var ownerIndex = previousSignificantToken(before: braceIndex, in: tokens) else {
            return nil
        }

        if tokens[ownerIndex] == .endOfScope(")"),
           let parenthesisStart = formatter.startOfScope(at: ownerIndex),
           let indexBeforeParenthesis = previousSignificantToken(before: parenthesisStart, in: tokens)
        {
            ownerIndex = indexBeforeParenthesis
        }

        switch tokens[ownerIndex] {
        case let .identifier(owner), let .keyword(owner):
            return owner
        default:
            return nil
        }
    }

    private static func containingBrace(
        before index: Int,
        in formatter: Formatter,
        tokens: [Token]
    ) -> Int? {
        var currentIndex = index
        while let scopeStart = formatter.startOfScope(at: currentIndex) {
            if tokens[scopeStart] == .startOfScope("{") {
                return scopeStart
            }
            currentIndex = scopeStart
        }
        return nil
    }

    private static func previousSignificantToken(before index: Int, in tokens: [Token]) -> Int? {
        guard index > 0 else { return nil }
        return tokens[..<index].lastIndex { !$0.isSpaceOrCommentOrLinebreak }
    }

    private static func isComponentStart(_ token: Token) -> Bool {
        switch token {
        case let .identifier(name):
            name.first?.isUppercase == true
        case .keyword("if"), .keyword("switch"):
            true
        default:
            false
        }
    }

    private static func lineStartIndex(for index: Int, in tokens: [Token]) -> Int {
        var lineStart = index
        while lineStart > 0, case .space = tokens[lineStart - 1] {
            lineStart -= 1
        }
        return lineStart
    }

    private static func isFirstTokenOnLine(
        _ index: Int,
        lineStart: Int,
        in tokens: [Token]
    ) -> Bool {
        guard lineStart <= index else { return false }
        return lineStart == 0 || tokens[lineStart - 1].isLinebreak
    }

    private static func needsBlankLine(before lineStart: Int, in tokens: [Token]) -> Bool {
        guard lineStart > 1, tokens[lineStart - 1].isLinebreak else {
            return false
        }

        var previousIndex = lineStart - 2
        while previousIndex >= 0, case .space = tokens[previousIndex] {
            previousIndex -= 1
        }

        guard previousIndex >= 0 else { return false }
        let previousToken = tokens[previousIndex]
        return !previousToken.isLinebreak && !previousToken.isComment
    }

    private static let viewBuilderModifiers: Set<String> = [
        "background",
        "contextMenu",
        "fullScreenCover",
        "mask",
        "overlay",
        "popover",
        "safeAreaInset",
        "sheet",
        "toolbar",
    ]
}

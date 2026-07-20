import Foundation
import SwiftUIFormattingRules

let inputPaths = CommandLine.arguments.dropFirst()
guard !inputPaths.isEmpty else {
    throw SwiftUIFormatError.missingInput
}

let fileManager = FileManager.default
let inputURLs = inputPaths.map { URL(fileURLWithPath: String($0)) }
let swiftFiles = try inputURLs.flatMap { inputURL -> [URL] in
    let values = try inputURL.resourceValues(forKeys: [.isDirectoryKey])
    guard values.isDirectory == true else {
        return inputURL.pathExtension == "swift" ? [inputURL] : []
    }

    guard let enumerator = fileManager.enumerator(
        at: inputURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return []
    }

    return enumerator.compactMap { element in
        guard let fileURL = element as? URL,
              fileURL.pathExtension == "swift",
              (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        else {
            return nil
        }
        return fileURL
    }
}

var changedFileCount = 0
for fileURL in Set(swiftFiles).sorted(by: { $0.path < $1.path }) {
    let source = try String(contentsOf: fileURL, encoding: .utf8)
    let formattedSource = SwiftUIComponentSpacingRule.format(source)
    guard formattedSource != source else { continue }

    try formattedSource.write(to: fileURL, atomically: true, encoding: .utf8)
    changedFileCount += 1
}

print("SwiftUI component spacing completed. \(changedFileCount) file(s) changed.")

private enum SwiftUIFormatError: LocalizedError {
    case missingInput

    var errorDescription: String? {
        "Pass at least one Swift source file or directory."
    }
}

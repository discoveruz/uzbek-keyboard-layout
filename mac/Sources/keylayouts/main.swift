import Foundation
import UzbekKeyboardMac

let usage = """
    usage: keylayouts bundle --version <x.y.z> <output folder>
           keylayouts pictures <output folder>
           keylayouts app-icon <output.icns>
           keylayouts verify
    Run it in the folder with the .klc files (the repo root).
    """

let arguments = Array(CommandLine.arguments.dropFirst())
let klcFolder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

do {
    switch arguments.first {
    case "bundle" where arguments.count == 4 && arguments[1] == "--version":
        let layouts = try MacLayouts.build(klcFolder: klcFolder)
        let bundle = try BundleWriter.write(layouts, version: arguments[2], to: URL(fileURLWithPath: arguments[3]))
        print("Wrote \(bundle.path)")
    case "pictures" where arguments.count == 2:
        try MacLayouts.writePictures(klcFolder: klcFolder, to: URL(fileURLWithPath: arguments[1]))
        print("Wrote the layout pictures to \(arguments[1])")
    case "app-icon" where arguments.count == 2:
        try Icon.icns(sizes: Icon.appSizes).write(to: URL(fileURLWithPath: arguments[1]))
        print("Wrote \(arguments[1])")
    case "verify" where arguments.count == 1:
        let result = try Verifier.run(klcFolder: klcFolder)
        result.report.forEach { print($0) }
        exit(result.passed ? 0 : 1)
    default:
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}

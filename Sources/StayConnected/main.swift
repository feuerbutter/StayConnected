import AppKit
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.isEmpty || arguments == ["--agent"] {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
} else {
    exit(CLI.run(arguments: arguments))
}

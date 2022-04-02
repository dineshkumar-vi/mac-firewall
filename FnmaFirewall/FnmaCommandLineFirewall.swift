/// HelloCommand.swift
import Foundation

final class HelloCommand: Command {
        
    struct Signature: CommandSignature {

        @Argument(name: "name", help: "The name to say hello")
        var name: String

        @Option(name: "greeting", short: "g", help: "Greeting used")
        var greeting: String?

        @Flag(name: "capitalize", short: "c", help: "Capitalizes the name")
        var capitalize: Bool
    }

    let help = "This command will say hello to a given name."

    func run(using context: CommandContext, signature: Signature) throws {
        let greeting = signature.greeting ?? "Hello"
        var name = signature.name
        if signature.capitalize {
            name = name.capitalized
        }
        print("\(greeting) \(name)!")
    }
}

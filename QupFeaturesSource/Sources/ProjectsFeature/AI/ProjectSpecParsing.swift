import FoundationModelsKit
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)
@available(iOS 26, macOS 26, *)
@Generable
struct ParsedProjectSpec {
    @Guide(description: "A concise project name.")
    var name: String

    @Guide(description: "A one or two sentence description of the project.")
    var description: String

    @Guide(description: "The primary programming language, if mentioned, otherwise an empty string.")
    var programmingLanguage: String

    @Guide(description: "The framework used, if mentioned, otherwise an empty string.")
    var framework: String
}
#endif

/// On-device "paste a spec/description" → structured project fields, for
/// pre-filling `CreateProjectSheet` instead of typing each field by hand.
/// Type/status stay manual since those are server-driven catalog IDs, not
/// something a schema can reliably guess.
enum ProjectSpecParsing {
    #if canImport(FoundationModels)
    @available(iOS 26, macOS 26, *)
    static func parseSpec(_ text: String) async throws -> ParsedProjectSpec {
        try await FoundationModelsGuidedGeneration.generate(
            ParsedProjectSpec.self,
            instructions: "Extract a project name, description, programming language, and framework from the user's pasted spec or description.",
            prompt: text
        )
    }
    #endif
}

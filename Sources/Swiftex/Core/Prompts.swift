import Foundation

enum Prompts {
    /// Pattern-neutral role + output contract. ALL UI knowledge — AND which pattern
    /// to use (PView, bottom sheet, …) — comes from the routed skill, never baked in.
    private static let generationBase = """
    You are an iOS engineer. Convert a Figma design into Swift source
    files, following the attached skill EXACTLY. The skill alone decides the pattern,
    the output shape, and how many files to produce.

    ## Output
    Respond with ONLY a JSON object (no prose, no markdown fences, no ``` blocks):
    { "files": [ { "relativePath": "<Feature>/X.swift", "content": "<full Swift source>" } ] }
    Each "content" is complete, compilable Swift for one file — raw Swift, never fenced.
    """

    private static let noSkillsWarning = """

    ## NOTE
    No skills folder was found, so detailed project conventions are unavailable.
    Generate a best-effort PView (struct conforming to PView with @ObservedObject
    Output, an Input of AnyPublisher events, and a PViewModelable ViewModel), using
    PUIKit components (PText, PButtonView/ButtonView, PImageView). Avoid SwiftUI
    Text/Button/Image.
    """

    static func generationSystem(skills: String, directive: String, examples: String = "") -> String {
        var prompt = skills.isEmpty
            ? generationBase + noSkillsWarning
            : generationBase
                + "\n\n## This task (authoritative — overrides any other pattern)\n"
                + directive
                + "\n\n# Attached skill (follow exactly)\n\n"
                + skills
        if !examples.isEmpty {
            prompt += "\n\n# Real examples from this codebase\n"
                + "Mimic these conventions EXACTLY (imports, init(viewModel: ViewModel), token names, file shape). "
                + "Names differ per design; the patterns are authoritative.\n\n"
                + examples
        }
        return prompt
    }

    static func generationUser(
        module: String,
        feature: String,
        rootFrameName: String,
        design: String,
        freeform: Bool = false
    ) -> String {
        if freeform {
            return """
            Feature folder: \(feature)

            ## Request
            \(String(design.prefix(12_000)))

            Generate the Swift file(s) fulfilling this request, following the attached
            skill exactly. If it's a PView or bottom sheet, follow that pattern; for a
            plain SwiftUI view keep it idiomatic. Use flat <Feature>/... paths.
            """
        }
        return """
        Module: \(module)
        Feature folder: \(feature)
        Root frame: \(rootFrameName)

        ## Design from Figma
        This may be a layer tree, or Dev Mode code (React/Tailwind) with design-system
        token names and real copy. Convert it to the target per the skills — map tokens
        and components to PUIKit, do not emit React/Tailwind.

        \(String(design.prefix(12_000)))

        Generate the Swift files for this design now.
        """
    }
}

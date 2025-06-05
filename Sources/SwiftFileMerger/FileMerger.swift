import Foundation

struct FileMerger {
    private let fileDiscovery: FileDiscovery
    private let outputDirectory: String
    private let outputFile: String
    private let sourceDirectory: String
    
    init(sourceDirectory: String, outputDirectory: String = "./build", outputFileName: String = "merged.swift") {
        self.sourceDirectory = sourceDirectory
        self.outputDirectory = outputDirectory
        self.outputFile = outputFileName
        self.fileDiscovery = FileDiscovery(targetDirectory: sourceDirectory)
    }
    
    func mergeFiles() throws {
        let (regularFiles, entryPoint) = try fileDiscovery.findSwiftFilesWithEntryPoint()
        
        guard !regularFiles.isEmpty || entryPoint != nil else {
            throw FileMergerError.noSwiftFilesFound(sourceDirectory)
        }
        
        try createOutputDirectory()
        
        let outputPath = URL(fileURLWithPath: outputDirectory).appendingPathComponent(outputFile).path
        
        // Collect all imports and process files
        var allImports = Set<String>()
        var processedFiles: [(relativePath: String, content: String)] = []
        
        // Process regular files
        for relativePath in regularFiles {
            let fileContent = try fileDiscovery.readFileContent(relativePath: relativePath)
            let (imports, contentWithoutImports) = extractImports(from: fileContent)
            
            allImports.formUnion(imports)
            processedFiles.append((relativePath: relativePath, content: contentWithoutImports))
        }
        
        // Process entry point if found
        var entryPointContent: String? = nil
        if let entryPointPath = entryPoint {
            let fileContent = try fileDiscovery.readFileContent(relativePath: entryPointPath)
            let (imports, contentWithoutImports) = extractImports(from: fileContent)
            
            allImports.formUnion(imports)
            entryPointContent = cleanEntryPoint(contentWithoutImports)
        }
        
        // Build final merged content
        var mergedContent = ""
        
        // Add consolidated imports at the top
        let sortedImports = allImports.sorted()
        for importStatement in sortedImports {
            mergedContent += "\(importStatement)\n"
        }
        
        // Add empty line after imports if there are any
        if !sortedImports.isEmpty {
            mergedContent += "\n"
        }
        
        // Add processed regular file contents
        for (index, fileInfo) in processedFiles.enumerated() {
            // Add file boundary comment
            mergedContent += "// === File: \(fileInfo.relativePath) ===\n"
            mergedContent += fileInfo.content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Add spacing between files (except for the last file or entry point)
            if index < processedFiles.count - 1 || entryPoint != nil {
                mergedContent += "\n\n"
            }
        }
        
        // Add entry point at the end
        if let entryPointPath = entryPoint, let content = entryPointContent {
            mergedContent += "// === File: \(entryPointPath) ===\n"
            mergedContent += content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        try mergedContent.write(toFile: outputPath, atomically: true, encoding: .utf8)
        
        let totalFiles = regularFiles.count + (entryPoint != nil ? 1 : 0)
        print("📁 Merged \(totalFiles) Swift files:")
        for file in regularFiles {
            print("   • \(file)")
        }
        if let entryPointPath = entryPoint {
            print("   • \(entryPointPath) (entry point)")
        }
    }
    
    private func extractImports(from content: String) -> (imports: Set<String>, contentWithoutImports: String) {
        let lines = content.components(separatedBy: .newlines)
        var imports = Set<String>()
        var contentLines: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("import ") {
                imports.insert(trimmedLine)
            } else {
                contentLines.append(line)
            }
        }
        
        // Remove leading empty lines from content
        while contentLines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
            contentLines.removeFirst()
        }
        
        let contentWithoutImports = contentLines.joined(separator: "\n")
        return (imports: imports, contentWithoutImports: contentWithoutImports)
    }
    
    private func cleanEntryPoint(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        
        // Check if content already has @main or a main function
        let contentString = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if contentString.contains("@main") || contentString.contains("func main(") {
            // Already clean, return as-is
            return content
        }
        
        // Detect problematic top-level expressions
        var problematicLines: [String] = []
        var safeLines: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") {
                safeLines.append(line)
                continue
            }
            
            // Check if this line is a problematic top-level expression
            if isProblematicTopLevelExpression(trimmed) {
                problematicLines.append(line)
            } else {
                safeLines.append(line)
            }
        }
        
        // If no problematic lines found, return original content
        if problematicLines.isEmpty {
            return content
        }
        
        // Wrap problematic lines in a main function
        var result = safeLines.joined(separator: "\n")
        
        // Remove trailing empty lines from safe content
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add main function with problematic code
        if !result.isEmpty {
            result += "\n\n"
        }
        
        result += "@main\nstruct AppMain {\n    static func main() {\n"
        for line in problematicLines {
            // Don't include main() calls inside the main function
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.hasPrefix("main()") {
                result += "        \(line)\n"
            }
        }
        result += "    }\n}"
        
        return result
    }
    
    private func isProblematicTopLevelExpression(_ line: String) -> Bool {
        // Lines that are definitely safe at top level
        if line.hasPrefix("import ") ||
           line.hasPrefix("@") ||
           line.hasPrefix("class ") ||
           line.hasPrefix("struct ") ||
           line.hasPrefix("enum ") ||
           line.hasPrefix("func ") ||
           line.hasPrefix("extension ") ||
           line.hasPrefix("protocol ") ||
           line.hasPrefix("typealias ") ||
           line.hasPrefix("//") ||
           line == "{" ||
           line == "}" ||
           line.isEmpty {
            return false
        }
        
        // Variable/constant declarations with initialization expressions are problematic
        if (line.hasPrefix("let ") || line.hasPrefix("var ")) && line.contains("=") {
            let assignmentPart = String(line.split(separator: "=", maxSplits: 1).last ?? "").trimmingCharacters(in: .whitespaces)
            
            // Simple literal values are safe
            if isSimpleLiteral(assignmentPart) {
                return false
            }
            
            // Complex expressions (method calls, constructors, property access) are problematic
            return true
        }
        
        // Pure variable declarations without initialization are safe
        if (line.hasPrefix("let ") || line.hasPrefix("var ")) && !line.contains("=") {
            return false
        }
        
        // Function calls and other expressions are problematic
        return true
    }
    
    private func isSimpleLiteral(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // String literals
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"")) ||
           (trimmed.hasPrefix("'") && trimmed.hasSuffix("'")) {
            return true
        }
        
        // Number literals
        if Int(trimmed) != nil || Double(trimmed) != nil {
            return true
        }
        
        // Boolean literals
        if trimmed == "true" || trimmed == "false" {
            return true
        }
        
        // nil literal
        if trimmed == "nil" {
            return true
        }
        
        // Array/dictionary literals (simple check)
        if (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) ||
           (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) {
            return true
        }
        
        // Everything else (method calls, constructors, property access) is complex
        return false
    }
    
    private func createOutputDirectory() throws {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: outputDirectory) {
            try fileManager.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
}

enum FileMergerError: LocalizedError {
    case noSwiftFilesFound(String)
    
    var errorDescription: String? {
        switch self {
        case .noSwiftFilesFound(let directory):
            return "No Swift files found in \(directory)"
        }
    }
}

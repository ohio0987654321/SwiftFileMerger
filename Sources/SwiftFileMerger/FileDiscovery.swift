import Foundation

struct FileDiscovery {
    private let targetDirectory: String
    
    init(targetDirectory: String) {
        self.targetDirectory = targetDirectory
    }
    
    
    func findSwiftFilesWithEntryPoint() throws -> (regularFiles: [String], entryPoint: String?) {
        let allSwiftFiles = try findAllSwiftFiles()
        let entryPoint = try findBestEntryPoint(from: allSwiftFiles)
        let regularFiles = allSwiftFiles.filter { file in
            shouldIncludeAsRegularFile(file, excludingEntryPoint: entryPoint)
        }
        
        return (regularFiles: regularFiles, entryPoint: entryPoint)
    }
    
    private func findAllSwiftFiles() throws -> [String] {
        let fileManager = FileManager.default
        let resolvedPath = try resolveTargetPath()
        
        guard fileManager.fileExists(atPath: resolvedPath) else {
            throw FileDiscoveryError.targetDirectoryNotFound(targetDirectory)
        }
        
        var swiftFiles: [String] = []
        
        if let enumerator = fileManager.enumerator(atPath: resolvedPath) {
            for case let file as String in enumerator {
                if file.hasSuffix(".swift") && !file.hasSuffix("merged.swift") {
                    swiftFiles.append(file)
                }
            }
        }
        
        return swiftFiles.sorted()
    }
    
    private func findBestEntryPoint(from files: [String]) throws -> String? {
        var candidates: [(file: String, score: Int)] = []
        
        for file in files {
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            let content = try readFileContent(relativePath: file)
            
            // Check if this is a potential entry point
            if fileName == "main.swift" || content.contains("@main") {
                let score = scoreEntryPoint(content: content, fileName: fileName)
                candidates.append((file: file, score: score))
            }
        }
        
        // Return the entry point with the highest score (cleanest/safest)
        return candidates.max(by: { $0.score < $1.score })?.file
    }
    
    private func scoreEntryPoint(content: String, fileName: String) -> Int {
        var score = 0
        let lines = content.components(separatedBy: .newlines)
        
        // Prefer @main over main.swift files (generally cleaner)
        if content.contains("@main") {
            score += 20
        }
        
        // Prefer shorter files (less likely to have complex logic)
        if lines.count < 20 {
            score += 10
        } else if lines.count < 50 {
            score += 5
        }
        
        // Penalty for top-level expressions that could cause issues
        let topLevelExpressions = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.isEmpty && 
                   !trimmed.hasPrefix("//") && 
                   !trimmed.hasPrefix("import") &&
                   !trimmed.hasPrefix("@") &&
                   !trimmed.hasPrefix("class") &&
                   !trimmed.hasPrefix("struct") &&
                   !trimmed.hasPrefix("func") &&
                   !trimmed.hasPrefix("var") &&
                   !trimmed.hasPrefix("let") &&
                   !trimmed.hasPrefix("{") &&
                   !trimmed.hasPrefix("}")
        }
        
        score -= topLevelExpressions.count * 2
        
        // Prefer files in main app directory over nested ones
        if !fileName.contains("/") {
            score += 5
        }
        
        return score
    }
    
    private func shouldIncludeAsRegularFile(_ relativePath: String, excludingEntryPoint: String?) -> Bool {
        let fileName = URL(fileURLWithPath: relativePath).lastPathComponent
        
        // Exclude merged.swift files (prevent recursion)
        if fileName == "merged.swift" {
            return false
        }
        
        // Exclude the selected entry point from regular files
        if let entryPoint = excludingEntryPoint, relativePath == entryPoint {
            return false
        }
        
        // Exclude other main files and @main files that weren't selected as entry point
        if fileName == "main.swift" {
            return false
        }
        
        // Check file content for @main attribute
        do {
            let content = try readFileContent(relativePath: relativePath)
            if content.contains("@main") {
                return false
            }
        } catch {
            // If we can't read the file, include it and let the error surface later
            return true
        }
        
        return true
    }
    
    func readFileContent(relativePath: String) throws -> String {
        let fileManager = FileManager.default
        let resolvedTargetPath = try resolveTargetPath()
        let fullPath = URL(fileURLWithPath: resolvedTargetPath)
            .appendingPathComponent(relativePath)
            .path
        
        guard fileManager.fileExists(atPath: fullPath) else {
            throw FileDiscoveryError.fileNotFound(relativePath)
        }
        
        return try String(contentsOfFile: fullPath, encoding: .utf8)
    }
    
    private func resolveTargetPath() throws -> String {
        let expandedPath = expandTildePath(targetDirectory)
        
        // Check if path is already absolute
        if expandedPath.hasPrefix("/") {
            return expandedPath
        }
        
        // Handle relative path
        let fileManager = FileManager.default
        let currentDirectory = fileManager.currentDirectoryPath
        return URL(fileURLWithPath: currentDirectory).appendingPathComponent(expandedPath).path
    }
    
    private func expandTildePath(_ path: String) -> String {
        if path.hasPrefix("~/") {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
            return homeDirectory + String(path.dropFirst(1))
        } else if path == "~" {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }
        return path
    }
}

enum FileDiscoveryError: LocalizedError {
    case targetDirectoryNotFound(String)
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .targetDirectoryNotFound(let path):
            return "Target directory not found: \(path)"
        case .fileNotFound(let file):
            return "File not found: \(file)"
        }
    }
}

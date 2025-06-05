import Foundation

struct CLIOptions {
    let sourceDirectory: String
    let outputDirectory: String
    let outputFileName: String
    let verbose: Bool
    
    init(sourceDirectory: String, outputDirectory: String = "./build", outputFileName: String = "merged.swift", verbose: Bool = false) {
        self.sourceDirectory = sourceDirectory
        self.outputDirectory = outputDirectory
        self.outputFileName = outputFileName
        self.verbose = verbose
    }
}

func main() {
    let arguments = CommandLine.arguments
    
    // Handle help and version flags
    if arguments.contains("--help") || arguments.contains("-h") {
        printHelp()
        exit(0)
    }
    
    if arguments.contains("--version") || arguments.contains("-v") {
        printVersion()
        exit(0)
    }
    
    // Parse command line arguments
    guard let options = parseArguments(arguments) else {
        exit(1)
    }
    
    do {
        let merger = FileMerger(
            sourceDirectory: options.sourceDirectory,
            outputDirectory: options.outputDirectory,
            outputFileName: options.outputFileName
        )
        try merger.mergeFiles()
        
        let outputPath = "\(options.outputDirectory)/\(options.outputFileName)"
        print("Swift files successfully merged into \(outputPath)")
        
        if options.verbose {
            print("Source directory: \(options.sourceDirectory)")
            print("Output directory: \(options.outputDirectory)")
            print("Output file: \(options.outputFileName)")
        }
        
    } catch {
        print("Error: \(error.localizedDescription)")
        
        // Provide helpful suggestions based on error type
        if let fileError = error as? FileDiscoveryError {
            switch fileError {
            case .targetDirectoryNotFound(let path):
                print("")
                print("Suggestions:")
                print("   • Check if the path exists: \(path)")
                print("   • Use absolute path (e.g., /Users/username/project)")
                print("   • Use ~ for home directory (e.g., ~/project)")
                print("   • Ensure you have read permissions for the directory")
            case .fileNotFound(let file):
                print("")
                print("The file \(file) could not be read")
            }
        }
        
        exit(1)
    }
}

func parseArguments(_ arguments: [String]) -> CLIOptions? {
    var sourceDirectory: String?
    var outputDirectory = "./build"
    var outputFileName = "merged.swift"
    var verbose = false
    
    var index = 1 // Skip program name
    while index < arguments.count {
        let arg = arguments[index]
        
        switch arg {
        case "--output", "-o":
            guard index + 1 < arguments.count else {
                print("Error: --output requires a directory path")
                printUsage()
                return nil
            }
            outputDirectory = arguments[index + 1]
            index += 2
            
        case "--filename", "-f":
            guard index + 1 < arguments.count else {
                print("Error: --filename requires a filename")
                printUsage()
                return nil
            }
            outputFileName = arguments[index + 1]
            index += 2
            
        case "--verbose":
            verbose = true
            index += 1
            
        default:
            if arg.hasPrefix("-") {
                print("Error: Unknown option '\(arg)'")
                printUsage()
                return nil
            } else if sourceDirectory == nil {
                sourceDirectory = arg
                index += 1
            } else {
                print("Error: Multiple source directories specified")
                printUsage()
                return nil
            }
        }
    }
    
    guard let source = sourceDirectory else {
        print("Error: Source directory is required")
        printUsage()
        return nil
    }
    
    return CLIOptions(
        sourceDirectory: source,
        outputDirectory: outputDirectory,
        outputFileName: outputFileName,
        verbose: verbose
    )
}

func printHelp() {
    print("SwiftFileMerger - Merge Swift source files into a single file")
    print("")
    printUsage()
    print("")
    print("OPTIONS:")
    print("  -h, --help               Show this help message")
    print("  -v, --version            Show version information")
    print("  -o, --output DIR         Output directory (default: ./build)")
    print("  -f, --filename FILE      Output filename (default: merged.swift)")
    print("      --verbose            Show detailed information")
    print("")
    print("EXAMPLES:")
    print("  SwiftFileMerger ~/MyProject/Sources")
    print("  SwiftFileMerger /path/to/project --output ./dist")
    print("  SwiftFileMerger ./Sources -f combined.swift --verbose")
    print("")
    print("DESCRIPTION:")
    print("  This tool recursively finds all Swift files in the specified directory,")
    print("  consolidates imports, and merges them into a single output file.")
    print("  Entry points (files with @main or main.swift) are handled specially.")
}

func printVersion() {
    print("SwiftFileMerger 1.0.0")
}

func printUsage() {
    print("Usage: SwiftFileMerger [OPTIONS] <source_directory>")
}

main()

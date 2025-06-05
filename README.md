# SwiftFileMerger

A powerful command-line tool that merges Swift source files into a single consolidated file. Perfect for code review, analysis, or preparing Swift code for AI/LLM processing.

## Installation

### From Source

```bash
git clone https://github.com/your-username/SwiftFileMerger.git
cd SwiftFileMerger
swift build -c release
```

The executable will be available at `.build/release/SwiftFileMerger`.

## Usage

### Basic Usage

```bash
# Merge all Swift files in a directory
SwiftFileMerger ~/MyProject/Sources

# Using relative path
SwiftFileMerger ./Sources

# Using absolute path
SwiftFileMerger /path/to/project/Sources
```

### Advanced Options

```bash
# Custom output directory
SwiftFileMerger ~/MyProject/Sources --output ./dist

# Custom filename
SwiftFileMerger ~/MyProject/Sources --filename combined.swift

# Verbose output with detailed information
SwiftFileMerger ~/MyProject/Sources --verbose

# All options combined
SwiftFileMerger ~/MyProject/Sources \
  --output ./output \
  --filename MyProject.swift \
  --verbose
```

### Command-Line Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--help` | `-h` | Show help message | - |
| `--version` | `-v` | Show version information | - |
| `--output DIR` | `-o` | Output directory | `./build` |
| `--filename FILE` | `-f` | Output filename | `merged.swift` |
| `--verbose` | - | Show detailed information | `false` |

## How It Works

### 1. File Discovery
- Recursively scans the specified directory for `.swift` files
- Excludes previously generated `merged.swift` files to prevent recursion
- Identifies potential entry points (`main.swift` files or files containing `@main`)

### 2. Entry Point Selection
The tool uses a scoring system to select the best entry point:
- **+20 points**: Files with `@main` attribute (preferred for cleaner code)
- **+10 points**: Shorter files (< 20 lines)
- **+5 points**: Files in the root directory
- **-2 points per line**: Top-level expressions that might cause issues

### 3. Import Consolidation
- Extracts all `import` statements from all files
- Deduplicates identical imports
- Places consolidated imports at the top of the merged file

### 4. Content Processing
- Removes import statements from individual file contents
- Processes entry points to handle problematic top-level expressions
- Wraps unsafe top-level code in `@main` structures when necessary

### 5. Output Generation
```
[Consolidated imports]

// === File: RegularFile1.swift ===
[File content without imports]

// === File: RegularFile2.swift ===
[File content without imports]

// === File: main.swift ===
[Entry point content]
```

## Examples

### Example 1: Basic iOS App
```bash
SwiftFileMerger ~/MyiOSApp/Sources
```

**Output**: `./build/merged.swift` containing all Swift files from your iOS app.

### Example 2: Swift Package
```bash
SwiftFileMerger ~/MyPackage/Sources/MyPackage \
  --output ./release \
  --filename MyPackage-combined.swift \
  --verbose
```

### Example 3: Multiple Targets
```bash
# Process main target
SwiftFileMerger ./Sources/App --filename App.swift

# Process test target  
SwiftFileMerger ./Tests/AppTests --filename Tests.swift
```

## Error Handling

The tool provides helpful error messages and suggestions:

```bash
Error: Target directory not found: ~/nonexistent

💡 Suggestions:
   • Check if the path exists: ~/nonexistent
   • Use absolute path (e.g., /Users/username/project)
   • Use ~ for home directory (e.g., ~/project)
   • Ensure you have read permissions for the directory
```

## Project Structure

```
SwiftFileMerger/
├── Sources/
│   └── SwiftFileMerger/
│       ├── main.swift           # CLI interface and argument parsing
│       ├── FileMerger.swift     # Core merging logic
│       └── FileDiscovery.swift  # File discovery and path resolution
├── Package.swift                # Swift Package Manager configuration
├── README.md                    # This file
└── .gitignore                  # Git ignore rules
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
git clone https://github.com/your-username/SwiftFileMerger.git
cd SwiftFileMerger
swift build
```

## Use Cases

- **Code Review**: Consolidate all Swift files for easier review
- **AI/LLM Processing**: Prepare Swift codebases for AI analysis
- **Documentation**: Generate comprehensive code documentation
- **Code Analysis**: Perform project-wide analysis on a single file
- **Backup**: Create consolidated snapshots of Swift projects

## Requirements

- Swift 5.7 or later
- macOS 10.15 or later

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<!-- ## Roadmap

- [ ] Add configuration file support
- [ ] Support for excluding specific directories/files via patterns
- [ ] Integration with popular Swift tools (SwiftLint, SwiftFormat)
- [ ] Support for other file types (Objective-C, C++)
- [ ] JSON/XML output formats for tooling integration -->

## Troubleshooting

### Common Issues

**Issue**: "Permission denied" error
**Solution**: Ensure you have read permissions for the source directory:
```bash
ls -la ~/path/to/directory
```

**Issue**: "No Swift files found"
**Solution**: Verify the directory contains `.swift` files:
```bash
find ~/path/to/directory -name "*.swift" | head -5
```

**Issue**: Large output file
**Solution**: Use the `--verbose` flag to see which files are being included, and consider processing subdirectories separately.

## Support

- Create an issue on GitHub for bugs or feature requests
- Check existing issues before creating new ones
- Include error messages and system information when reporting bugs

---

**Happy Merging!** 🚀

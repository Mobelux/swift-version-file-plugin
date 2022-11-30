# VersionFilePlugin

The VersionFilePlugin is a Swift Package Manager command plugin that supports maintaining a 
`Version` type with a semantic version number for packages that need to be aware of their version. 
It uses the [semver shell utility](https://github.com/fsaintjacques/semver-tool) to bump version 
numbers according to major / minor / patch releases.

The created file looks like:

```swift
enum Version {
    static let number = "1.0.0"
}
```

## Usage

### Adding the Plugin as a Dependency

To use the VersionFilePlugin with your package, first add it as a dependency:

```swift
let package = Package(
    // name, platforms, products, etc.
    dependencies: [
        // other dependencies
        .package(url: "https://github.com/mobelux/swift-version-file-plugin", from: "1.0.0"),
    ],
    targets: [
        // targets
    ]
)
```

Swift 5.6 is required in order to run the plugin.

### Creating a Version File

Create the version file with a valid version number:

```
swift package --allow-writing-to-package-directory version-file --create <version number>
```

### Bumping the Version Number

Update the file by invoking the plugin with a valid release type (one of: `major | minor | patch | release | prerel`):

```
swift package --allow-writing-to-package-directory version-file --bump <release type>
```

## Acknowledgments

- [semver shell utility](https://github.com/fsaintjacques/semver-tool)

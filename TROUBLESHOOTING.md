# Troubleshooting for Localpilot for Xcode

## Extension Permission

Localpilot for Xcode is an Xcode Source Editor extension and requires the
extension to be enabled. In the Localpilot for Xcode settings, clicking `Extension
Permission` will open the System Settings to the Extensions page where `Localpilot` 
can be enabled under `Xcode Source Editor`.

Or you can navigate to the permission manually depending on your OS version:

| macOS | Location |
| :--- | :--- |
| 15 | System Settings > General > Login Items > Extensions > Xcode Source Editor |
| 13 & 14 | System Settings > Privacy & Security  > Extensions > Xcode Source Editor |

## Accessibility Permission

Localpilot for Xcode requires the accessibility permission to receive
real-time updates from the active Xcode editor. [The XcodeKit
API](https://developer.apple.com/documentation/xcodekit)
enabled by the Xcode Source Editor extension permission only provides
information when manually triggered by the user. In order to generate
suggestions as you type, the accessibility permission is used read the
Xcode editor content in real-time.

The accessibility permission is also used to accept suggestions when `tab` is
pressed.

The accessibility permission is __not__ used to read or write to any
applications besides Xcode. There are no granular options for the permission,
but you can audit the usage in this repository: search for `CGEvent` and `AX`*.

Enable in System Settings under `Privacy & Security` > `Accessibility` > 
`Localpilot Extension` and turn on the toggle.

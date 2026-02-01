# spotv

spotv is a small, focused launcher for macOS that lets you open applications, perform quick calculations, and convert currencies from a single prompt. It appears as a compact floating window that you can bring up with a hotkey, type what you need, and act on the result immediately.

## Features

spotv searches across three categories as you type:

**Applications** - Type an app name to find and launch installed macOS applications. The search is fuzzy and prioritizes apps that start with what you typed.

**Calculator** - Type any math expression and see the result instantly. Supports arithmetic operators, functions like `sin` and `sqrt`, and number formats including hex and binary. Add suffixes to format results as durations or timestamps.

**Currency** - Type currency codes or conversion queries like `USD EUR` or `1 GBP USD` to convert amounts. Rates are cached locally for fast lookups.

spotv shows the top matching result in each category as you type. Press `Return` to act on it: launch the app, copy the calculation, or copy the converted amount. Type `/index` to refresh the app cache and exchange rates, or `/quit` to close the launcher.

### Application Search

Searching for an application is quick and forgiving. Start typing an app name and spotv will surface the most likely matches. The top result shows the app name and its icon so you can confirm you found the right app. Press `Return` to open the highlighted application.

### Calculator

The calculator evaluates expressions in real time while you type. You can use the usual arithmetic operators and parentheses, power and modulo operators, and basic bitwise operations. The calculator accepts decimal numbers and also supports hexadecimal (`0x`), binary (`0b`), and octal (`0o`) literals. Common math functions such as `sin`, `cos`, `sqrt`, and `log` are supported. Press `Return` to copy the computed value to the clipboard.

The calculator also supports optional suffixes to format or convert results. Add a colon followed by a suffix to customize the output. For time conversions, use `:msec`, `:sec`, `:min`, `:hour`, `:day`, `:week`, `:month`, or `:year` to interpret the number as milliseconds and display it as a human-readable duration. Use `:unix` or `:munix` to format a number as a UNIX timestamp (seconds or milliseconds). For number base conversions, use `:x` for hexadecimal, `:b` for binary, or `:o` for octal output. You can also append a custom unit with `:+unit`, for example `:+cm` to add centimeters as a label. If you add an asterisk after the suffix like `:sec*`, the result is displayed with an appropriate SI prefix such as `m` for milli or `k` for kilo.

### Currency Conversion

Currency conversions are fast and easy. Enter queries like `1 USD EUR`, `USD to EUR`, or `5 GBP` to get an immediate conversion. Rates are fetched from a public service and cached locally so repeated lookups are fast. Press `Return` to copy the converted amount.

### Hotkeys

The default hotkey to show or hide the launcher is `Cmd + Space`. You can also hide the window with `Cmd + Tab` or by pressing `Escape` when the window is focused.

## Getting Started

To build and run spotv, you need the V compiler and SDL2 libraries installed. Follow these steps:

- Install V: Download and install the V compiler from [vlang.io](https://vlang.io). V provides detailed installation instructions for macOS, Linux, and Windows.
- Install SDL2 libraries: You need SDL2, SDL2_ttf, and SDL2_image. On macOS, install them with Homebrew: `brew install sdl2 sdl2_ttf sdl2_image`
- Clone or download the spotv repository
- Build the app: From the project root, run `v -prod -o spotv .` to compile the binary
- Run the app: Execute `./spotv` to start the launcher
- Grant permissions: On first run, macOS will prompt you to grant Accessibility or Input Monitoring permission. Allow this so the app can respond to the global hotkey. You can also add the app manually in System Settings > Privacy & Security > Accessibility.

## Examples

Here are some examples you can try:

**Applications**

- Type `safari` and press `Return` to open Safari
- Type `code` to find and launch Visual Studio Code
- Type `terminal` to open Terminal

**Calculator**

- Type `2+2` to see `= 4`
- Type `100*1.2` to calculate a 20% increase
- Type `sqrt(16)` to evaluate square root
- Type `60:sec` to convert 60 milliseconds to a human-readable duration
- Type `1609459200:unix` to format a UNIX timestamp as a readable date
- Type `255:x` to convert 255 to hexadecimal `= 0xff`
- Type `0b1010:x` to convert binary to hex
- Type `sin(0)` to evaluate trigonometric functions
- Type `100:+meters` to add a custom unit label

**Currency**

- Type `1 USD EUR` to convert 1 US dollar to euros and press `Return` to copy
- Type `100 GBP JPY` to convert British pounds to Japanese yen
- Type `5 CAD` to get the value in euros (default when a single currency is provided)

# BTC Watcher

[中文](README_CN.md) | English

A lightweight macOS menu bar application for real-time cryptocurrency price tracking.

![Screenshot](screenshot.png)

## Quick Start 🚀

### Option 1: Download Release
1. Go to [Releases](https://github.com/chenwuai/BTCWatcher/releases) page
2. Download the latest `BTCWatcher.app.zip`
3. Unzip and drag to your Applications folder
4. Double-click to launch

### Option 2: Build from Source
If you prefer to build from source:
```bash
git clone https://github.com/chenwuai/BTCWatcher.git
cd BTCWatcher
swiftc -o BTCWatcher.app/Contents/MacOS/BTCWatcher main.swift
```

## Features

- 🚀 Lightweight menu bar app
- 💰 Multiple cryptocurrency support (BTC, ETH, DOGE)
- ➕ Custom coin pair addition
- 🔄 Real-time price updates (1s, 2s, 5s intervals)
- 🌐 Automatic API endpoint switching
- 🌍 English and Chinese language support
- 🎯 Zero dependencies, pure Swift implementation

## System Requirements

- macOS 13.0 or later
- Internet connection required for price updates

## Usage

### Basic Operations
- Click the menu bar icon to view current price
- Select different cryptocurrencies from the menu
- Use `⌘Q` to quit

### Customization
- Update Intervals: Choose between 1, 2, or 5 seconds
- API Endpoints: Auto or manual selection
- Language: Switch between English and Chinese
- Custom Pairs: Add your own trading pairs

### Keyboard Shortcuts
- `⌘N`: Add custom coin
- `1`: Set 1-second update interval
- `2`: Set 2-second update interval
- `5`: Set 5-second update interval
- `A`: Toggle API auto-switch
- `L`: Switch language
- `⌘Q`: Quit application

## Development

### Building from Source
```bash
# Compile the application
swiftc -o BTCWatcher.app/Contents/MacOS/BTCWatcher main.swift

# Generate application icons
./generate_icons.sh
```

### Project Structure
- `main.swift`: Main application code
- `AppIcon.svg`: Application icon source
- `generate_icons.sh`: Icon generation script
- `Info.plist`: Application configuration

## Data Source

Price data is fetched from Binance API through multiple endpoints:
- api.binance.com
- api1.binance.com
- api2.binance.com
- api3.binance.com
- api4.binance.com

## Technical Details

### Implementation
- Built with native macOS frameworks (Cocoa, Foundation)
- No external dependencies
- Efficient menu bar integration using NSStatusItem
- Automatic error handling and API failover
- Dynamic menu generation
- Real-time price formatting

### Price Display
- Intelligent decimal place handling
- Unicode symbols for cryptocurrencies (₿, Ξ, Ð)
- Clean and minimal interface

### Error Handling
- Automatic API endpoint switching
- Connection error recovery
- User-friendly error messages
- Graceful degradation

## Security

- Uses only public API endpoints
- Minimal system permissions required
- No sensitive data storage
- Code signed for macOS security

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests
- Improve documentation

## License

MIT License

## Author

chenwuai

## Support

For issues, questions, or suggestions:
1. Open an issue
2. Submit a pull request
3. Contact the developer

---

*Note: This application is not affiliated with Binance or any cryptocurrency exchange.*

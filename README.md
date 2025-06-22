<h1 align="center">Menubar Info</h1>

<p align="center">
  <img alt="GitHub Release" src="https://img.shields.io/github/v/release/Thinkr1/Menubar-Info?style=for-the-badge">
  <img alt="PRs Welcome" src="https://img.shields.io/badge/PRs-Welcome-green?style=for-the-badge">
  <img alt="GitHub Downloads" src="https://img.shields.io/github/downloads/Thinkr1/Menubar-Info/total?style=for-the-badge">
  <img alt="Repo Size" src="https://img.shields.io/github/repo-size/Thinkr1/Menubar-Info?style=for-the-badge">
  <img alt="License: MIT" src="https://img.shields.io/github/license/Thinkr1/Menubar-Info?style=for-the-badge">
</p>

<p align="center">
  <em>A sleek and minimal macOS menubar utility displaying live system metrics—including CPU, memory, network, ports, and battery—in real time.</em>
</p>

<p align="center">
  <img
    src="https://github.com/user-attachments/assets/13cdfd8f-993b-4b89-bb39-0f0edf41aa06"
    alt="Menubar Info Banner"
    style="width: 100%; max-width: 100%; border-radius: 16px; box-shadow: 0 2px 8px rgba(0,0,0,0.08); display: block; margin: 0 auto;"
  >
</p>

## Features

* **CPU & Memory Monitoring** – Real-time usage stats right in your menubar
* **Network Activity** – Keep an eye on connection status and connected devices
* **Battery Health** – Track your Mac’s battery info
* **Port Monitoring** – Quickly view and edit open ports

<p align="center">
  <img width="546" alt="Ports Manager Screenshot" src="https://github.com/user-attachments/assets/e2d6e749-488c-4875-9f73-50ad02e08109" />
</p>

## Installation

Download the app in **.zip** or **.dmg** format from the [latest release page »](https://github.com/Thinkr1/Menubar-Info/releases)

> **Note**: The app is not notarized (yet) due to the lack of a paid Apple Developer account. macOS will show an alert when opening the app for the first time saying it cannot be opened directly. Here are two options to open it:

### Option A – Command line

```sh
sudo xattr -rd com.apple.quarantine /path/to/Menubar-Info.app
```

Then open it normally.

### Option B – macOS Security Settings

1. Go to **System Settings > Privacy & Security**
2. Scroll down to the **Security** section
3. Click **"Open Anyway"** for `Menubar-Info.app`

<p align="center">
  <img width="461" alt="Security Settings Screenshot" src="https://github.com/user-attachments/assets/64336344-39dc-476f-87cd-6fc209e7122f" />
</p>

---

### Verify File Integrity

You can verify that your download hasn’t been tampered with by checking its SHA-256 checksum.

1. Download the matching .sha256 file:

From the release page, download:

- Menubar-Info.dmg.sha256 if you downloaded the `.dmg`
- Menubar-Info.zip.sha256 if you downloaded the `.zip`

2. Verify the file integrity through the command line *(make sure the downloaded dmg or zip is in the same folder as the checksum)*:

```sh
# For the DMG
shasum -a 256 -c Menubar-Info.dmg.sha256

# For the ZIP
shasum -a 256 -c Menubar-Info.zip.sha256
```

## Contributions

Pull requests are welcome! Whether it's a bug fix, feature suggestion, or just a cool idea—[open an issue](https://github.com/Thinkr1/Menubar-Info/issues) or submit a PR.

## License

This project is released under the [MIT License](LICENSE).

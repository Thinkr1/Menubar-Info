<p align="center">
  <img alt="GitHub Release" src="https://img.shields.io/github/v/release/Thinkr1/Menubar-Info?style=for-the-badge">
  <img alt="GitHub commits since latest release" src="https://img.shields.io/github/commits-since/Thinkr1/Menubar-Info/latest?style=for-the-badge">
  <img alt="GitHub last commit" src="https://img.shields.io/github/last-commit/Thinkr1/Menubar-Info?style=for-the-badge">
  <img alt="GitHub Downloads (all assets, all releases)" src="https://img.shields.io/github/downloads/Thinkr1/Menubar-Info/total?style=for-the-badge">
  <img alt="GitHub License" src="https://img.shields.io/github/license/Thinkr1/Menubar-Info?style=for-the-badge">
  <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/Thinkr1/Menubar-Info?style=for-the-badge">
</p>

### Menu bar info app

A lightweight macOS menu bar utility for real-time system metrics—monitoring CPU, memory, network, ports, and battery, all at a glance.

#### CPU And Memory Monitoring

<img width="576" alt="CPU" src="https://github.com/user-attachments/assets/96ace99c-c468-4109-be84-8fb4c99a8473" />
<img width="268" alt="Memory" src="https://github.com/user-attachments/assets/f57888e9-eb82-46e1-90ab-62d22659b478" />

#### Ports

<img width="374" alt="Ports" src="https://github.com/user-attachments/assets/4f7da2e5-fde5-449a-a6d9-c3a216262e2c" />
<img width="546" alt="Ports - Manager" src="https://github.com/user-attachments/assets/e2d6e749-488c-4875-9f73-50ad02e08109" />

#### Network and Battery Monitoring

<img width="308" alt="Network" src="https://github.com/user-attachments/assets/19a2c086-2a8b-4d26-9c50-544ac90c235f" />
<img width="259" alt="Battery" src="https://github.com/user-attachments/assets/7b89facd-8e7a-4269-a01a-750a0bf4e3e6" />

## Install

1. Download the dmg from the [latest release](https://github.com/Thinkr1/Menubar-Info/releases)
2. As I don't have a paid developer account, I cannot direcly notarize the app and you'll be presented with an alert saying it cannot be opened directly. Here are two options:

a) You can run the following command and then open the app normally: 

```sh
sudo xattr -rd com.apple.quarantine /path/to/app/folder/Menubar-Info.app
```

b) You can allow the app to be opened in *System Settings > Privacy & Security* by clicking "Open Anyway" for Menubar-Info.app:

<img width="461" alt="Screenshot 2025-04-21 at 4 27 22 PM" src="https://github.com/user-attachments/assets/64336344-39dc-476f-87cd-6fc209e7122f" />

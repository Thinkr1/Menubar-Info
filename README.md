<p align="center">
  <img alt="GitHub Release" src="https://img.shields.io/github/v/release/Thinkr1/Menubar-Info?style=for-the-badge">
  <img als="PRs Welcome" src="https://img.shields.io/badge/PRs-Welcome :)-green?style=for-the-badge">
  <img alt="GitHub Downloads (all assets, all releases)" src="https://img.shields.io/github/downloads/Thinkr1/Menubar-Info/total?style=for-the-badge">
  <img alt="GitHub repo size" src="https://img.shields.io/github/repo-size/Thinkr1/Menubar-Info?style=for-the-badge">
  <img alt="GitHub License" src="https://img.shields.io/github/license/Thinkr1/Menubar-Info?style=for-the-badge">
</p>

### Menu bar info app

A lightweight macOS menu bar utility for real-time system metrics—monitoring CPU, memory, network, ports, and battery, all at a glance.

#### CPU And Memory Monitoring

<img width="587" alt="CPU" src="https://github.com/user-attachments/assets/afdec0e7-d00d-4941-bc2c-73cf4b0e2ca4" />
<img width="269" alt="Memory" src="https://github.com/user-attachments/assets/487b70f9-ce98-419e-83bf-e41a78960e4f" />


#### Ports

<img width="340" alt="Ports" src="https://github.com/user-attachments/assets/8366a018-0539-439d-8744-de4e03534641" />
<img width="546" alt="Ports - Manager" src="https://github.com/user-attachments/assets/e2d6e749-488c-4875-9f73-50ad02e08109" />

#### Network and Battery Monitoring

<img width="320" alt="Network" src="https://github.com/user-attachments/assets/a36c821a-0419-4a44-a950-373d7743cec5" />
<img width="262" alt="Battery" src="https://github.com/user-attachments/assets/0b863944-5b68-4d81-9567-f4a6e66e6806" />

## Install

1. Download the dmg from the [latest release](https://github.com/Thinkr1/Menubar-Info/releases)
2. As I don't have a paid developer account, I cannot direcly notarize the app and you'll be presented with an alert saying it cannot be opened directly. Here are two options:

a) You can run the following command and then open the app normally: 

```sh
sudo xattr -rd com.apple.quarantine /path/to/app/folder/Menubar-Info.app
```

b) You can allow the app to be opened in *System Settings > Privacy & Security* by clicking "Open Anyway" for Menubar-Info.app:

<img width="461" alt="Screenshot 2025-04-21 at 4 27 22 PM" src="https://github.com/user-attachments/assets/64336344-39dc-476f-87cd-6fc209e7122f" />

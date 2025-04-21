### Menu bar info app

A simple app, built in Swift, showing CPU percentage, country flag (based on the user's public IP), and battery time remaining in the menu bar.

<img width="268" alt="IP menu bar item with its popup" src="https://github.com/user-attachments/assets/5ca3faa1-e611-4526-bda2-976dcfca486f" />
<img width="248" alt="Battery menu bar item with its popup" src="https://github.com/user-attachments/assets/8e96c97e-6a82-475f-8da5-90a91ae455f5" />
<img width="235" alt="CPU menu bar item with its popup" src="https://github.com/user-attachments/assets/95286e98-9977-40e0-b965-18da089b72e8" />

## Install

1. Download the dmg from the [latest release](https://github.com/Thinkr1/Menubar-Info/releases)
2. As I don't have a paid developer account, I cannot direcly notarize the app and you'll be presented with an alert saying it cannot be opened directly. Here are two options:

a) You can run the following command and then open the app normally: 

```sh
sudo xattr -rd com.apple.quarantine /path/to/app/folder/Menubar-Info.app
```

b) You can allow the app to be opened in *System Settings > Privacy & Security* by clicking "Open Anyway" for Rregex.app:

<img width="461" alt="Screenshot 2025-04-21 at 4 27 22 PM" src="https://github.com/user-attachments/assets/64336344-39dc-476f-87cd-6fc209e7122f" />

---

<sub>CPU percentage is obtained by using the command `ps -A -o %cpu | awk '{s+=$1} END {print s}'`</sub>


<sub>IP location is obtained by using the command `curl -s ip-api.com/json/$(curl -s ifconfig.me) | jq -r '.query + " " + .countryCode'` (and IP (v4) is obtained with `curl -s ifconfig.me`)</sub>

<sub>Battery percentage is obtained with `pmset -g batt | awk '/[0-9]+%/ {gsub(/;/, "", $3); print $3}'` and time remaining is obtained with `pmset -g batt | awk '/[0-9]+:[0-9]+/ {print $5}'`</sub>

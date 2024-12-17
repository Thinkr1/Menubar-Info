### Menu bar info app

A simple app, built in Swift, showing CPU percentage, country flag (based on the user's public IP), and battery time remaining in the menu bar.

<img width="268" alt="IP menu bar item with its popup" src="https://github.com/user-attachments/assets/5ca3faa1-e611-4526-bda2-976dcfca486f" />
<img width="248" alt="Battery menu bar item with its popup" src="https://github.com/user-attachments/assets/8e96c97e-6a82-475f-8da5-90a91ae455f5" />
<img width="235" alt="CPU menu bar item with its popup" src="https://github.com/user-attachments/assets/95286e98-9977-40e0-b965-18da089b72e8" />

<img width="546" alt="Settings panel" src="https://github.com/user-attachments/assets/17ec57cc-d520-4fc6-b4ae-f5955cb79c42" />

---

<sub>CPU percentage is obtained by using the command `ps -A -o %cpu | awk '{s+=$1} END {print s}'`</sub>


<sub>IP location is obtained by using the command `curl -s ip-api.com/json/$(curl -s ifconfig.me) | jq -r '.query + " " + .countryCode'` (and IP (v4) is obtained with `curl -s ifconfig.me`)</sub>

<sub>Battery percentage is obtained with `pmset -g batt | awk '/[0-9]+%/ {gsub(/;/, "", $3); print $3}'` and time remaining is obtained with `pmset -g batt | awk '/[0-9]+:[0-9]+/ {print $5}'`</sub>

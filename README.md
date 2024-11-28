### Menu bar info app

A simple app, built in Swift, showing CPU percentage and country flag (based on the user's IP) in the menu bar.

<img width="235" alt="CPU menu bar view" src="https://github.com/user-attachments/assets/09bd470e-b51d-43da-a4ea-c99b8af1ee10">
<img width="280" alt="IP (and loc) menu bar view" src="https://github.com/user-attachments/assets/d010c850-05db-415b-9861-b69fb2e0f45b">

<img width="612" alt="Settings panel" src="https://github.com/user-attachments/assets/adcff2dd-7b8d-4005-b3b4-a4b0b31451b0">

---

<sub>CPU percentage is obtained by using the command `ps -A -o %cpu | awk '{s+=$1} END {print s}'`</sub>


<sub>IP location is obtained by using the command `curl -s ip-api.com/json/$(curl -s ifconfig.me) | jq -r '.query + " " + .countryCode'` (and IP (v4) is obtained with `curl -s ifconfig.me`)</sub>

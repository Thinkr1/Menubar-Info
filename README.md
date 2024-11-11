### CPU Menu bar app

Simple app, built in Swift, showing CPU percentage in the menu bar.

<img width="234" alt="Menu bar view" src="https://github.com/user-attachments/assets/5e31d44a-b2c0-41e5-b3cd-87b3640df3a9">

<img width="612" alt="Settings panel" src="https://github.com/user-attachments/assets/adcff2dd-7b8d-4005-b3b4-a4b0b31451b0">

---

<sub>CPU percentage is obtained by using the command `ps -A -o %cpu | awk '{s+=$1} END {print s}'`</sub>

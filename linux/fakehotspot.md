Recommended Arch Linux tools

Tool			Purpose
aircrack-ng		Wi-Fi security auditing
iw			Wireless interface management
hostapd			Create a test access point
tcpdump			Capture network traffic
Wireshark		Inspect captured packets

sudo pacman -S aircrack-ng iw hostapd tcpdump wireshark-cli

on second terminal:
sudo tshark -i wlp1s0mon -l

check the file if it contains eapol:
tshark -r ~/hack/jasurcap.pcap -Y eapol -V

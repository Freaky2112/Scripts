from machine import Pin, PWM
import network
import socket
import time

# ----- Servo Setup -----
servo = PWM(Pin(15))
servo.freq(50)

def move_servo(angle):
    duty = int((angle / 180) * 5000 + 1000)
    servo.duty_u16(duty)

# ----- Door Sensor Setup -----
# Reed switch on GP14, using internal pull-up
door_sensor = Pin(14, Pin.IN, Pin.PULL_UP)

def door_status():
    if door_sensor.value() == 0:
        return "Closed"
    else:
        return "Open"

# ----- Wi-Fi -----
ssid = "YOUR_WIFI"
password = "YOUR_PASSWORD"

wlan = network.WLAN(network.STA_IF)
wlan.active(True)
wlan.connect(ssid, password)

while not wlan.isconnected():
    time.sleep(0.5)

print("Connected:", wlan.ifconfig())

# ----- Web Server -----
addr = socket.getaddrinfo("0.0.0.0", 80)[0][-1]
s = socket.socket()
s.bind(addr)
s.listen(1)

while True:
    client, addr = s.accept()
    request = client.recv(1024).decode()

    if "/open" in request:
        if door_status() == "Closed":  # Only pull handle if closed
            move_servo(60)
            time.sleep(0.5)
            move_servo(0)

    # HTML page showing real-time door status
    response = f"""HTTP/1.1 200 OK

<html>
  <head>
    <meta http-equiv="refresh" content="2">
  </head>
  <body>
    <h2>Door Opener</h2>
    <p><b>Door Status: {door_status()}</b></p>
    <a href="/open"><button>OPEN DOOR</button></a>
  </body>
</html>
"""    
    client.send(response)
    client.close()

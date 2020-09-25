#!/usr/bin/env python3
#!/usr/bin/env python2

import serial
import time
import datetime as dt
import matplotlib.pyplot as plt
import matplotlib.animation as animation

ser = serial.Serial(
	port = '/dev/ttyUSB0',
	baudrate = 9600,
	parity = serial.PARITY_NONE,
	stopbits = serial.STOPBITS_ONE,
	bytesize = serial.EIGHTBITS
)

# Create figure for plotting
fig = plt.figure()
ax = fig.add_subplot(1, 1, 1)
xs = []
ys = []
global realValue; 

def main():
	while (1):

		if  ser.isOpen():
			if ser.in_waiting > 4:
				out = ser.read(4);
				realValue = int.from_bytes(bytes(bytearray(out)),"little")
				print(int.from_bytes(bytes(bytearray(out)),"little"));
				print(realValue);
				print('\n')

		ani = animation.FuncAnimation(fig, animate, fargs=(xs, ys, realValue), interval=100)
		plt.show()


# This function is called periodically from FuncAnimation
def animate(i, xs, ys, realValue):

    # Read temperature (Celsius) from TMP102
	temp_c = realValue;

    # Add x and y to lists
	xs.append(dt.datetime.now().strftime('%H:%M:%S.%f'))
	ys.append(temp_c)

	# Limit x and y lists to 20 items
	xs = xs[-20:]
	ys = ys[-20:]

	# Draw x and y lists
	ax.clear()
	ax.plot(xs, ys)

	# Format plot
	plt.xticks(rotation=45, ha='right')
	plt.subplots_adjust(bottom=0.30)
	plt.title('Velocity overtime')
	plt.ylabel('RPM')

# Set up plot to call animate() function periodically
main()

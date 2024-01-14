# Correcting the syntax error and providing the complete code

# Reading the file
import pandas as pd
import matplotlib.pyplot as plt

file_path = '/mnt/data/benchmark_stats_history.csv'
data = pd.read_csv(file_path)

# Convert Timestamp to datetime and then to seconds relative to the start
data['Timestamp'] = pd.to_datetime(data['Timestamp'], unit='s')
data['Timestamp'] = (data['Timestamp'] - data['Timestamp'].min()).dt.total_seconds()

# Calculating Responses per Second
data['Time Difference'] = data['Timestamp'].diff().fillna(0)
data['Responses/s'] = data['Total Request Count'].diff().fillna(0) / data['Time Difference']
data['Responses/s'] = data['Responses/s'].replace([float('inf'), -float('inf')], 0)  # Replace infinities with 0

# Plotting
fig, axs = plt.subplots(4, 1, figsize=(15, 20))

# Requests/s vs. Timestamp
axs[0].plot(data['Timestamp'], data['Requests/s'], label='Requests/s', color='green')
axs[0].set_title('Requests per Second Over Time')
axs[0].set_xlabel('Time (seconds)')
axs[0].set_ylabel('Requests/s')
axs[0].grid(True)

# Failures/s vs. Timestamp
axs[1].plot(data['Timestamp'], data['Failures/s'], label='Failures/s', color='red')
axs[1].set_title('Failures per Second Over Time')
axs[1].set_xlabel('Time (seconds)')
axs[1].set_ylabel('Failures/s')
axs[1].grid(True)

# Response Time Percentiles vs. Timestamp
percentiles = ['50%', '75%', '99%']
for percentile in percentiles:
    axs[2].plot(data['Timestamp'], data[percentile], label=f'{percentile} Response Time')
axs[2].set_title('Response Time Percentiles Over Time')
axs[2].set_xlabel('Time (seconds)')
axs[2].set_ylabel('Response Time (ms)')
axs[2].legend()
axs[2].grid(True)

# Responses/s vs. Timestamp
axs[3].plot(data['Timestamp'], data['Responses/s'], label='Responses/s', color='purple')
axs[3].set_title('Responses per Second Over Time')
axs[3].set_xlabel('Time (seconds)')
axs[3].set_ylabel('Responses/s')
axs[3].grid(True)

# Adjust layout
plt.tight_layout()

# # Show plots
# plt.show()

# Save plot
plt.savefig('/mnt/data/graph.png')
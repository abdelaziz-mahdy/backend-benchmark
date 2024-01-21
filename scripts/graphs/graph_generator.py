import json
import pandas as pd
import matplotlib.pyplot as plt
import glob
import os
import numpy as np

 
def process_file(file_path):
    # Load the data from the provided file
    data = pd.read_csv(file_path)
    # Convert Timestamp to datetime and then to seconds relative to the start
    data['Timestamp'] = pd.to_datetime(data['Timestamp'], unit='s')
    data['Timestamp'] = (data['Timestamp'] - data['Timestamp'].min()).dt.total_seconds()

    # Calculating Responses per Second
    data['Time Difference'] = data['Timestamp'].diff().fillna(0)
    data['Responses/s'] = data['Total Request Count'].diff().fillna(0) / data['Time Difference']
    data['Responses/s'] = data['Responses/s'].replace([float('inf'), -float('inf')], 0)  # Replace infinities with 0
    data['Response Time'] = data[['50%', '75%', '99%']].mean(axis=1)

    # Calculate summary statistics for key metrics
    summary = {
        'Average Requests/s': data['Requests/s'].mean(),
        'Average Failures/s': data['Failures/s'].mean(),
        'Average Responses/s': data['Responses/s'].mean(),
        'Average Response Time 50% (ms)': data['50%'].mean(),
        'Average Response Time 75% (ms)': data['75%'].mean(),
        'Average Response Time 99% (ms)': data['99%'].mean(),
    }
    summary['Average Response Time (ms)'] = data['Response Time'].mean()

    return data,summary
def process_file_cpu_usage(file_path):
    # Load the data from the provided file
    data = pd.read_csv(file_path.replace("benchmark_stats_history.csv","cpu_usage.csv"))
    # Convert Timestamp to datetime and then to seconds relative to the start
    data['Timestamp'] = pd.to_datetime(data['Timestamp'], unit='s')
    data['Timestamp'] = (data['Timestamp'] - data['Timestamp'].min()).dt.total_seconds()

    # Calculating Responses per Second
    data['Time Difference'] = data['Timestamp'].diff().fillna(0)
    return data
def compare_and_plot(all_data, all_summaries,all_cpu):
    # Number of datasets
    num_datasets = len(all_data)

    # Plotting with a vertical summary table with adjusted width
    fig, axs = plt.subplots(11, 1, figsize=(15, 50))

    # Colors for different datasets
    colors = ['green', 'red', 'blue', 'orange', 'purple', 'brown', 'pink', 'gray', 'olive', 'cyan']

    # Ensure there are enough colors for the datasets
    if num_datasets > len(colors):
        raise ValueError("Need more colors for plotting")
    if len(all_data)!=len(all_summaries)!=len(all_cpu):
        raise ValueError("all_data, all_summaries, all_cpu should have same length")
    # Plotting the graphs for each dataset
    for i, (file_path, data) in enumerate(all_data.items()):
        file_name=get_adjusted_file_name(file_path)
        color = colors[i]

        # Requests/s vs. Timestamp
        axs[0].plot(data['Timestamp'], data['Requests/s'], label=f'{file_name} - Requests/s', color=color)

        # Failures/s vs. Timestamp
        axs[1].plot(data['Timestamp'], data['Failures/s'], label=f'{file_name} - Failures/s', color=color)

        # Response Time Percentiles vs. Timestamp
        percentiles = ['50%', '75%', '99%']
        for percentile in percentiles:
            axs[2].plot(data['Timestamp'], data[percentile], label=f'{file_name} - {percentile} Response Time', color=color)

        # Responses/s vs. Timestamp
        axs[3].plot(data['Timestamp'], data['Responses/s'], label=f'{file_name} - Responses/s', color=color)

        # Cumulative Requests and Failures Over Time
        # TODO: make it requests and response
        axs[4].plot(data['Timestamp'], data['Total Request Count'], label=f'{file_name} - Cumulative Requests', color=color)
        axs[4].plot(data['Timestamp'], data['Total Failure Count'], label=f'{file_name} - Cumulative Failures', color=color)

        # Response Time Distribution (Histogram)
        axs[5].hist(data['Total Average Response Time'].dropna(), bins=30, color=color, alpha=0.7, label=f'{file_name}')

        # Load (User Count) vs Response Time
        axs[6].scatter(data['User Count'], data['Total Average Response Time'], color=color, alpha=0.5, label=f'{file_name}')

        # User Count vs Various Metrics
        axs[7].plot(data['Timestamp'], data['User Count'], label=f'{file_name} - User Count', color=color)

        # Total Average Content Size Over Time
        axs[8].plot(data['Timestamp'], data['Total Average Content Size'], label=f'{file_name} - Average Content Size', color=color)

        axs[9].plot(all_cpu[file_path]['Timestamp'], all_cpu[file_path]['Total Average Content Size'], label=f'{file_name} - Cpu Usage', color=color)

    # Setting titles, labels, and legends
    titles = ['Requests per Second Over Time', 'Failures per Second Over Time', 'Response Time Percentiles Over Time',
              'Responses per Second Over Time', 'Cumulative Requests and Failures Over Time', 'Response Time Distribution',
              'Load vs Response Time', 'User Count Over Time', 'Average Content Size Over Time', 'Summary Table']

    for ax, title in zip(axs, titles):
        ax.set_title(title)
        ax.set_xlabel('Time (seconds)')
        ax.legend()
        ax.grid(True)

    # # Comprehensive Summary Table at the end
    # summary_df = pd.DataFrame(all_summaries)
    # table = axs[9].table(cellText=summary_df.values, rowLabels=summary_df.index, colLabels=summary_df.columns, loc='center')
    # table.auto_set_font_size(False)
    # table.set_fontsize(10)
    # table.scale(1, 2)
    # axs[9].axis('tight')
    # axs[9].axis('off')
    plot_summary_of_all(all_summaries, axs[-1])

    # Adjust layout
    plt.tight_layout()
    if len(all_data) ==1:
        file_location=list(all_summaries.keys())[0]
        plt.savefig(file_location.replace("benchmark_stats_history.csv","graph.png"))
    else:
        # Save plot
        plt.savefig('/mnt/data/comparison_graph.png')


def plot_summary_of_all(summaries, ax):
    adjusted_summaries = {}
    for file_path, summary in summaries.items():
        adjusted_name = get_adjusted_file_name(file_path)
        adjusted_summaries[adjusted_name] = summary
    summaries=adjusted_summaries
    file_paths=  list(summaries.keys())
    # Ensure summaries are numeric
    numeric_summaries = {path: validate_and_convert_to_numeric(summary) for path, summary in summaries.items()}

    # Define metrics categories
    lower_is_better_metrics = ['Average Failures/s', 'Average Response Time 50% (ms)', 
                               'Average Response Time 75% (ms)', 'Average Response Time 99% (ms)',
                               'Average Response Time (ms)']
    higher_is_better_metrics = ['Average Requests/s', 'Average Responses/s']

    # Combine all metrics into one set for table headers
    all_metrics = lower_is_better_metrics + higher_is_better_metrics

    # Transpose summaries for table orientation
    transposed_summaries = {metric: {} for metric in all_metrics}
    for path, summary in numeric_summaries.items():
        for metric in all_metrics:
            transposed_summaries[metric][path] = summary.get(metric, 'N/A')

    # Initialize table data
    table_data = []

    # Prepare data for table
    for metric in all_metrics:
        row = [metric]
        for path in file_paths:
            val = transposed_summaries[metric].get(path, 'N/A')
            if val != 'N/A' and  len(summaries) != 1 :
                base_val = min(transposed_summaries[metric].values()) if metric in lower_is_better_metrics else max(transposed_summaries[metric].values())
                diff_in_raw = val - base_val
                diff = ((diff_in_raw) / base_val) * 100 if base_val != 0 else 0
                is_better = (diff_in_raw <= 0 and metric in lower_is_better_metrics) or (diff_in_raw >= 0 and metric in higher_is_better_metrics)
                color = 'green' if is_better else 'red'
                formatted_val = f"{val} ({diff:.2f}%)"
            else:
                color = 'black'
                formatted_val = val
            row.append((formatted_val, color))
        table_data.append(row)

    # Extracting only the text part of each cell
    extracted_cell_text = [[cell[0] if isinstance(cell, tuple) else cell for cell in row] for row in table_data]
    col_labels = ['Metric'] + file_paths

    # Creating the table
    table = ax.table(cellText=np.array(extracted_cell_text, dtype=object), colLabels=col_labels, loc='center')
    if len(summaries) != 1 :
        for (i, j), cell in table.get_celld().items():
            if i == 0 or j == 0:
                continue
            original_cell = table_data[i-1][j]
            color = original_cell[1] if isinstance(original_cell, tuple) else 'black'
            cell.get_text().set_color(color)

    table.auto_set_font_size(True)
    table.scale(1, 2)
    ax.axis('off')
    ax.set_title('Results and Percentage Differences for All Metrics')

# Function to validate and convert summary values to numeric
def validate_and_convert_to_numeric(summary):
    numeric_summary = {}
    for key, value in summary.items():
        try:
            numeric_summary[key] = float(value)
        except ValueError:
            print(f"Warning: Non-numeric value encountered for {key}")
    return numeric_summary
# Adjusted file path naming
def get_adjusted_file_name(file_path):
    ignored_parts = {'results', 'tests', 'backends','','mnt','data',"benchmark",'benchmark_stats_history.csv'}
    parts = file_path.split(os.sep)
    # Filter out the ignored parts
    relevant_parts = [part for part in parts if part not in ignored_parts]
    # Join the remaining parts, typically the technology and project names

    # print(relevant_parts)
    return (' '.join(relevant_parts)).replace("-"," ")

# Initialize a dictionary to store summaries
all_summaries = {}

all_data = {}

all_cpu = {}
# Find all benchmark_stats_history.csv files in /data directory
file_paths = glob.glob('/mnt/data/**/benchmark_stats_history.csv', recursive=True)

# Process and plot each file and collect summaries
for file_path in file_paths:
    print(f"Processing file: {file_path}")
    data,summary = process_file(file_path)
    cpu= process_file_cpu_usage(file_path)
    compare_and_plot({file_path: data}, {file_path: summary}, {file_path: cpu})
    # file_path = get_adjusted_file_name(file_path)
    all_summaries[file_path] = summary
    all_data[file_path] = data
    all_cpu[file_path] = cpu

# Plot and save summary of all files
# plot_summary_of_all(all_summaries, list(all_summaries.keys()))

compare_and_plot(all_data, all_summaries,all_cpu)


# Custom serializer function for JSON
def data_json(all_summaries, all_data):
    def custom_serializer(obj):
        if isinstance(obj, pd.DataFrame):
        # Convert DataFrame to a list of dictionaries
            return obj.to_dict(orient='records')
        raise TypeError(f'Object of type {obj.__class__.__name__} is not JSON serializable')

# Assuming all_data and all_summaries are already defined dictionaries

    for path, data in all_data.items():
    # Fill NaN values with zero in the DataFrame
        if isinstance(data, pd.DataFrame):
            data.fillna(0, inplace=True)
    
        all_data[path] ={
        'service': get_adjusted_file_name(path),
        'summary': all_summaries[path],
        'cpu': all_cpu[path],
        'data': data
    }





# Using json.dumps with the custom serializer and writing to a file
    try:
        all_data_json = json.dumps(all_data, default=custom_serializer, indent=4)
        with open('/mnt/data/results_data.json', 'w') as file:
            file.write(all_data_json)
        print("JSON data successfully written to file.")
    except TypeError as e:
        print(f"Serialization error: {e}")

data_json( all_summaries, all_data)


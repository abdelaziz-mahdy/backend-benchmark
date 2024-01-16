import pandas as pd
import matplotlib.pyplot as plt
import glob
import os
import numpy as np
# Function to process and plot data from a single file
def process_and_plot(file_path):
    # Load the data from the provided file
    data = pd.read_csv(file_path)

    # Convert Timestamp to datetime and then to seconds relative to the start
    data['Timestamp'] = pd.to_datetime(data['Timestamp'], unit='s')
    data['Timestamp'] = (data['Timestamp'] - data['Timestamp'].min()).dt.total_seconds()

    # Calculating Responses per Second
    data['Time Difference'] = data['Timestamp'].diff().fillna(0)
    data['Responses/s'] = data['Total Request Count'].diff().fillna(0) / data['Time Difference']
    data['Responses/s'] = data['Responses/s'].replace([float('inf'), -float('inf')], 0)  # Replace infinities with 0

    # Calculate summary statistics for key metrics
    summary = {
        'Average Requests/s': data['Requests/s'].mean(),
        'Average Failures/s': data['Failures/s'].mean(),
        'Average Responses/s': data['Responses/s'].mean(),
        'Average Response Time 50% (ms)': data['50%'].mean(),
        'Average Response Time 75% (ms)': data['75%'].mean(),
        'Average Response Time 99% (ms)': data['99%'].mean(),
    }
    # Adding calculation for average response time
    data['Response Time'] = data[['50%', '75%', '99%']].mean(axis=1)
    summary['Average Response Time (ms)'] = data['Response Time'].mean()

    # Plotting with a vertical summary table with adjusted width
    fig, axs = plt.subplots(10, 1, figsize=(15, 50))  # Reduced subplot count by 1


    # Plotting the graphs
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

    # Cumulative Requests and Failures Over Time
    axs[4].plot(data['Timestamp'], data['Total Request Count'], label='Cumulative Requests', color='blue')
    axs[4].plot(data['Timestamp'], data['Total Failure Count'], label='Cumulative Failures', color='red')
    axs[4].set_title('Cumulative Requests and Failures Over Time')
    axs[4].set_xlabel('Time (seconds)')
    axs[4].set_ylabel('Count')
    axs[4].legend()
    axs[4].grid(True)

    # Response Time Distribution (Histogram)
    axs[5].hist(data['Total Average Response Time'].dropna(), bins=30, color='purple', alpha=0.7)
    axs[5].set_title('Response Time Distribution')
    axs[5].set_xlabel('Response Time (ms)')
    axs[5].set_ylabel('Frequency')
    axs[5].grid(True)

    # Load (User Count) vs Response Time
    axs[6].scatter(data['User Count'], data['Total Average Response Time'], color='green', alpha=0.5)
    axs[6].set_title('Load vs Response Time')
    axs[6].set_xlabel('User Count')
    axs[6].set_ylabel('Average Response Time (ms)')
    axs[6].grid(True)

    # User Count vs Various Metrics
    axs[7].plot(data['Timestamp'], data['User Count'], label='User Count', color='orange')
    axs[7].set_title('User Count Over Time')
    axs[7].set_xlabel('Time (seconds)')
    axs[7].set_ylabel('User Count')
    axs[7].grid(True)

    # Total Average Content Size Over Time
    axs[8].plot(data['Timestamp'], data['Total Average Content Size'], label='Average Content Size', color='brown')
    axs[8].set_title('Average Content Size Over Time')
    axs[8].set_xlabel('Time (seconds)')
    axs[8].set_ylabel('Size')
    axs[8].grid(True)

    # Comprehensive Summary Table at the end
    summary_df = pd.DataFrame([summary])
    cell_text = [[f"{value:.2f}"] for value in summary_df.values[0]]
    row_labels = summary_df.columns
    table = axs[9].table(cellText=cell_text, rowLabels=row_labels, loc='center', colWidths=[0.2, 0.1])
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 2)
    axs[9].axis('tight')
    axs[9].axis('off')



    # Adjust layout
    plt.tight_layout()


    # Save plot
    plt.savefig(file_path.replace("benchmark_stats_history.csv","graph.png"))

    return summary

def plot_summary_of_all(summaries, file_paths):
    # Ensure summaries are numeric
    numeric_summaries = {path: validate_and_convert_to_numeric(summary) for path, summary in summaries.items()}

    # Define metrics categories
    lower_is_better_metrics = ['Average Failures/s', 'Average Response Time 50% (ms)', 
                               'Average Response Time 75% (ms)', 'Average Response Time 99% (ms)',
                               'Average Response Time (ms)']
    higher_is_better_metrics = ['Average Requests/s', 'Average Responses/s']

    for metric_set, title in [(lower_is_better_metrics, 'Lower is Better Metrics'), 
                              (higher_is_better_metrics, 'Higher is Better Metrics')]:
        filtered_summaries = {path: {metric: summary[metric] for metric in metric_set if metric in summary}
                              for path, summary in numeric_summaries.items()}

        # Create DataFrame from summaries
        summary_df = pd.DataFrame(filtered_summaries).T

        if not summary_df.empty:
            # Sorting and calculating percentage differences
            for metric in metric_set:
                if metric in summary_df.columns:
                    ascending = metric in lower_is_better_metrics
                    summary_df.sort_values(by=metric, ascending=ascending, inplace=True)
                    min_val = summary_df[metric].min() if ascending else summary_df[metric].max()
                    summary_df[f'% Diff {metric}'] = ((summary_df[metric] - min_val) / min_val) * 100

            # Plotting bar charts without color coding
            fig, ax = plt.subplots(figsize=(15, 8))
            summary_df[metric_set].plot(kind='bar', ax=ax)
            plt.title(title)
            plt.xlabel('File Path')
            plt.ylabel('Values')
            plt.xticks(rotation=45, ha='right')
            plt.legend(metric_set)
            plt.tight_layout()
            plt.savefig(f'/mnt/data/summary_{title.replace(" ", "_").lower()}.png')

    # Combine all metrics into one set for table headers
    all_metrics = lower_is_better_metrics + higher_is_better_metrics

    # Transpose summaries for table orientation
    transposed_summaries = {metric: {} for metric in all_metrics}
    for path, summary in numeric_summaries.items():
        for metric in all_metrics:
            transposed_summaries[metric][path] = summary.get(metric, 'N/A')

    # Sort file paths for each metric and calculate base values
    sorted_file_paths = {}
    base_values = {}
    for metric in all_metrics:
        is_lower_better = metric in lower_is_better_metrics
        metric_values = {path: transposed_summaries[metric].get(path, float('inf') if is_lower_better else float('-inf')) 
                        for path in file_paths}
        sorted_paths = sorted(metric_values, key=metric_values.get, reverse=not is_lower_better)
        sorted_file_paths[metric] = sorted_paths
        base_values[metric] = metric_values[sorted_paths[0]] if sorted_paths else None

    # Initialize table data
    table_data = []

    # Prepare data for table
    for metric in all_metrics:
        row = [metric]
        for path in sorted_file_paths[metric]:
            val = transposed_summaries[metric].get(path, 'N/A')
            if val != 'N/A' and base_values[metric] is not None:
                base_val = base_values[metric]
                diff = ((val - base_val) / base_val) * 100 if base_val != 0 else 0
                is_better = (diff <= 0 and metric in lower_is_better_metrics) or \
                            (diff >= 0 and metric in higher_is_better_metrics)
                color = 'green' if is_better else 'red'
                formatted_val = f"{val} ({diff:.2f}%)"
            else:
                color = 'black'
                formatted_val = val
            row.append((formatted_val, color))
        table_data.append(row)

    # Create a separate image for the table
    fig, ax = plt.subplots(figsize=(15, 8))
    ax.axis('tight')
    ax.axis('off')

    # Column labels with 'Metric' as the first column, then sorted file paths
    col_labels = ['Metric'] + list(sorted_file_paths[all_metrics[0]])

    # Creating the table
    # Creating the table with only the text part of each cell
    # Adjust the cellText to extract only the first element of each tuple
    extracted_cell_text = [[cell[0] if isinstance(cell, tuple) else cell for cell in row] for row in table_data]
    table = ax.table(cellText=np.array(extracted_cell_text, dtype=object), colLabels=col_labels, loc='center')

    for (i, j), cell in table.get_celld().items():
        if i == 0 or j == 0:
            # Skip header or index cells
            continue

        # Extract the data from your original data structure
        original_cell = table_data[i-1][j]  # Adjust indices for headers
        
        color = 'black'

        # Set color based on the tuple in the original data
        if isinstance(original_cell, tuple) and len(original_cell) == 2:
            color = original_cell[1]
        print("for cell", original_cell, "color is", color)
        # Set the color of the cell text
        cell.get_text().set_color(color)


    table.auto_set_font_size(True)
    table.scale(1, 2)
    plt.title('Results and Percentage Differences for All Metrics', pad=20)
    plt.tight_layout()
    # plt.draw()
    plt.savefig('/mnt/data/results_percentage_differences_all_metrics.png')
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

# Find all benchmark_stats_history.csv files in /data directory
file_paths = glob.glob('/mnt/data/**/benchmark_stats_history.csv', recursive=True)

# Process and plot each file and collect summaries
for file_path in file_paths:
    print(f"Processing file: {file_path}")
    summary = process_and_plot(file_path)
    adjusted_file_name = get_adjusted_file_name(file_path)
    all_summaries[adjusted_file_name] = summary

# Plot and save summary of all files
plot_summary_of_all(all_summaries, list(all_summaries.keys()))

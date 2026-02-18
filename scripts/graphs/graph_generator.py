import glob
import json
import os

import numpy as np
import pandas as pd


def parse_mem_to_mb(value):
    """Convert Docker memory string (e.g., '123.4MiB', '1.004GiB') to float in MB."""
    s = str(value).strip()
    if s.endswith('GiB'):
        return float(s.rstrip('GiB')) * 1024
    elif s.endswith('MiB'):
        return float(s.rstrip('MiB'))
    elif s.endswith('KiB'):
        return float(s.rstrip('KiB')) / 1024
    else:
        try:
            return float(s)
        except ValueError:
            return float('nan')


def process_file(file_path):
    data = pd.read_csv(file_path, on_bad_lines='skip')

    data['timestamp'] = pd.to_numeric(
        data['Timestamp'], errors='coerce').astype('int').apply(int)
    data['Timestamp'] = pd.to_datetime(data['Timestamp'], unit='s')
    data['Timestamp'] = (data['Timestamp'] -
                         data['Timestamp'].min()).dt.total_seconds()

    data['Time Difference'] = data['Timestamp'].diff()
    data['Responses/s'] = data['Total Request Count'].diff() / \
        data['Time Difference']
    data['Responses/s'] = data['Responses/s'].replace(
        [np.inf, -np.inf], np.nan)
    window_size = 100
    data['Responses/s Smoothed'] = data['Responses/s'].rolling(
        window=window_size, min_periods=1).mean()

    data = data.dropna(subset=['Responses/s'])

    data['Response Time'] = data[['50%', '75%', '99%']].mean(axis=1)

    summary = {
        'Average Requests/s': data['Requests/s'].mean(),
        'Average Failures/s': data['Failures/s'].mean(),
        'Average Responses/s': data['Responses/s'].mean(),
        'Average Response Time 50% (ms)': data['50%'].mean(),
        'Average Response Time 75% (ms)': data['75%'].mean(),
        'Average Response Time 99% (ms)': data['99%'].mean(),
    }
    summary['Average Response Time (ms)'] = data['Response Time'].mean()

    return data, summary


def process_file_cpu_usage(file_path, summary):
    data = pd.read_csv(file_path.replace(
        "benchmark_stats_history.csv", "cpu_usage.csv"), on_bad_lines='skip')

    data['timestamp'] = pd.to_numeric(
        data['timestamp'], errors='coerce').astype('int').apply(int)
    data['Timestamp'] = pd.to_datetime(data['timestamp'], unit='s')
    data['Timestamp'] = (data['Timestamp'] -
                         data['Timestamp'].min()).dt.total_seconds()

    data['benchmark_cpu_usage'] = data['benchmark_cpu_usage'].astype(
        str).str.rstrip('%').astype(float)

    data['db_cpu_usage'] = data['db_cpu_usage'].astype(
        str).str.rstrip('%').astype(float)

    data['Time Difference'] = data['Timestamp'].diff()

    summary["Average Server CPU Usage"] = data['benchmark_cpu_usage'].mean()
    summary["Average Database CPU Usage"] = data['db_cpu_usage'].mean()
    return data, summary


def get_adjusted_file_name(file_path):
    ignored_parts = {'results', 'tests', 'backends', '', 'mnt',
                     'data', "benchmark", 'benchmark_stats_history.csv'}
    parts = file_path.split(os.sep)
    relevant_parts = [part for part in parts if part not in ignored_parts]
    return (' '.join(relevant_parts)).replace("-", " ")


def merge_data_and_cpu(data, cpu, print_data=False):
    data = data.sort_values('timestamp').reset_index(drop=True)
    cpu = cpu.sort_values('timestamp').reset_index(drop=True)

    data['benchmark_cpu_usage'] = None
    data['benchmark_mem_usage_mb'] = None
    data['db_cpu_usage'] = None
    data['db_mem_usage_mb'] = None

    cpu_index = 0
    cpu_length = len(cpu)

    for index, row in data.iterrows():
        while cpu_index < cpu_length and cpu.loc[cpu_index, 'timestamp'] < row['timestamp']:
            cpu_index += 1

        if cpu_index >= cpu_length:
            break

        if cpu_index > 0 and cpu.loc[cpu_index - 1, 'timestamp'] < row['timestamp']:
            prev_cpu_index = cpu_index - 1
            data.at[index, 'benchmark_cpu_usage'] = cpu.loc[prev_cpu_index,
                                                            'benchmark_cpu_usage']
            data.at[index, 'benchmark_mem_usage_mb'] = parse_mem_to_mb(
                cpu.loc[prev_cpu_index, 'benchmark_mem_usage_mb'])
            data.at[index, 'db_cpu_usage'] = cpu.loc[prev_cpu_index, 'db_cpu_usage']
            data.at[index, 'db_mem_usage_mb'] = parse_mem_to_mb(
                cpu.loc[cpu_index, 'db_mem_usage_mb'])
        else:
            data.at[index, 'benchmark_cpu_usage'] = None
            data.at[index, 'benchmark_mem_usage_mb'] = None
            data.at[index, 'db_cpu_usage'] = None
            data.at[index, 'db_mem_usage_mb'] = None
    return data


def data_json(all_summaries, all_data, all_cpu):
    def custom_serializer(obj):
        if isinstance(obj, pd.DataFrame):
            return obj.to_dict(orient='records')
        raise TypeError(f'Object of type {
                        obj.__class__.__name__} is not JSON serializable')

    combined_data = {}
    print_data = True
    for parent_dir in all_data:
        for path, data in all_data[parent_dir].items():
            service_name = get_adjusted_file_name(path)
            if isinstance(data, pd.DataFrame):
                data.fillna(0, inplace=True)
            if isinstance(all_summaries[parent_dir][path], pd.DataFrame):
                all_summaries[parent_dir][path].fillna(0, inplace=True)
            if isinstance(all_cpu[parent_dir][path], pd.DataFrame):
                cpu_df = all_cpu[parent_dir][path]
                for col in cpu_df.columns:
                    if cpu_df[col].dtype == 'object' or isinstance(cpu_df[col].dtype, pd.StringDtype):
                        cpu_df[col] = cpu_df[col].fillna('0')
                    else:
                        cpu_df[col] = cpu_df[col].fillna(0)

            merged_data = merge_data_and_cpu(
                data, all_cpu[parent_dir][path], print_data)

            combined_data[service_name] = {
                'summary': all_summaries[parent_dir][path],
                'data': merged_data
            }

            print_data = False

    try:
        all_data_json = json.dumps(combined_data, default=custom_serializer)
        with open('/mnt/data/benchmark-app/assets/data.json', 'w') as file:
            file.write(all_data_json)

        print("JSON data successfully written to file.")
    except TypeError as e:
        print(f"Serialization error: {e}")


# Main execution
all_summaries = {'db_test': {}, 'no_db_test': {}}
all_data = {'db_test': {}, 'no_db_test': {}}
all_cpu = {'db_test': {}, 'no_db_test': {}}

file_paths = glob.glob(
    '/mnt/data/**/benchmark_stats_history.csv', recursive=True)

for file_path in file_paths:
    print(f"Processing file: {file_path}")
    parent_dir = file_path.split('/')[-2]
    data, summary = process_file(file_path)
    cpu, summary = process_file_cpu_usage(file_path, summary)

    all_summaries[parent_dir][file_path] = summary
    all_data[parent_dir][file_path] = data
    all_cpu[parent_dir][file_path] = cpu

data_json(all_summaries, all_data, all_cpu)

print("Data generation completed.")

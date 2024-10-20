import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Line } from 'react-chartjs-2';
import 'chart.js/auto';
import './App.css'; // Import CSS for styling
import { CircularProgressbar, buildStyles } from 'react-circular-progressbar';
import 'react-circular-progressbar/dist/styles.css';

const colorMap = {
  db_test: '#FF33A8',
  no_db_test: '#333FA8',
};

const getColor = (serviceName) => {
  if (serviceName.toLowerCase().includes('no_db_test')) return colorMap.no_db_test;
  if (serviceName.toLowerCase().includes('db_test')) return colorMap.db_test;
  const baseServiceName = serviceName.toLowerCase().replace('no_db_test', '').replace('db_test', '').trim();
  return colorMap[baseServiceName] || `#${Math.floor(Math.random() * 16777215).toString(16)}`;
};

function App() {
  const [data, setData] = useState({});
  const [selectedServices, setSelectedServices] = useState([]);
  const [selectedFields, setSelectedFields] = useState([]);
  const [loading, setLoading] = useState(true);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    const baseURL = window.location.pathname.includes('backend-benchmark') ? '/backend-benchmark' : '';
    const source = axios.CancelToken.source();
    axios.get(`${baseURL}/data.json`, {
      cancelToken: source.token,
      onDownloadProgress: (progressEvent) => {
        if (progressEvent.total > 0) {
          const progress = Math.round((progressEvent.loaded * 100) / progressEvent.total);
          setProgress(progress);
        }
      }
    })
    .then(response => {
      setData(response.data);
      setLoading(false);
    })
    .catch(error => {
      if (axios.isCancel(error)) {
        console.log('Request canceled', error.message);
      } else {
        console.error('Error fetching data:', error);
      }
      setLoading(false);
    });

    return () => {
      source.cancel("Component got unmounted");
    };
  }, []);

  const handleServiceChange = (event) => {
    const value = event.target.value;
    setSelectedServices(prevServices => (
      prevServices.includes(value) ? prevServices.filter(service => service !== value) : [...prevServices, value]
    ));
  };

  const handleFieldChange = (event) => {
    const value = event.target.value;
    setSelectedFields(prevFields => (
      prevFields.includes(value) ? prevFields.filter(field => field !== value) : [...prevFields, value]
    ));
  };

  const handleServiceClick = (service) => {
    setSelectedServices(prevServices => (
      prevServices.includes(service) ? prevServices.filter(s => s !== service) : [...prevServices, service]
    ));
  };

  const generateChartDataForField = (field) => {
    const datasets = selectedServices.map(service => {
      const serviceData = data[service].data;
      return {
        label: `${service} - ${field}`,
        data: serviceData.map(item => item[field]),
        fill: false,
        borderColor: getColor(service),
      };
    });

    const labels = data[selectedServices[0]].data.map(item => item.Timestamp); // Use Timestamps from the first selected service for labels
    return { labels, datasets };
  };

  return (
    <div className="App">
      <header>
        <h1>Service Benchmarks</h1>
        <div className="legend">
          <p className="info-text">Below are the services and their corresponding colors used in the chart:</p>
          <ul>
            {Object.entries(colorMap).map(([service, color]) => (
              <li key={service} style={{ color }}>
                {service}
              </li>
            ))}
          </ul>
        </div>
      </header>
      <div className="main-content">
        <div className="sidebar">
          <div className="services">
            <label>Select Services:</label>
            {Object.keys(data).map(service => (
              <div key={service} className="checkbox-container" onClick={() => handleServiceClick(service)}>
                <input type="checkbox" value={service} onChange={handleServiceChange} checked={selectedServices.includes(service)} />
                <span style={{ color: getColor(service) }}>
                  {service.replace('no_db_test', '').replace('db_test', '').trim()}
                </span>
              </div>
            ))}
          </div>
        </div>
        {selectedServices.length > 0 && (
          <div className="fields">
            <label>Select Fields for Y-axis:</label>
            {Object.keys(data[selectedServices[0]].data[0])
              .filter(field => !['timestamp', 'Timestamp', 'Time Difference', 'Name', 'Type'].includes(field)) // Exclude specific fields from selection
              .map(field => (
                <div key={field} className="checkbox-container" onClick={() => handleFieldChange({ target: { value: field } })}>
                  <input type="checkbox" value={field} onChange={handleFieldChange} checked={selectedFields.includes(field)} />
                  {field}
                </div>
              ))}
          </div>
        )}
        <div className="chart-container">
          {loading ? (
            <div className="loading-indicator">
              <CircularProgressbar value={progress} text={`${progress}%`} styles={buildStyles({
                textSize: '16px',
                pathColor: '#3498db',
                textColor: '#3498db',
              })} />
            </div>
          ) : (
            selectedServices.length > 0 && selectedFields.length > 0 && (
              selectedFields.map(field => (
                <div key={field} className="individual-chart">
                  <h2>{field}</h2>
                  <Line data={generateChartDataForField(field)} />
                </div>
              ))
            )
          )}
        </div>
      </div>
    </div>
  );
}

export default App;

// src/App.js
import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Line } from 'react-chartjs-2';
import 'chart.js/auto';
import './App.css'; // Import CSS for styling

function App() {
  const [data, setData] = useState({});
  const [selectedServices, setSelectedServices] = useState([]);
  const [selectedFields, setSelectedFields] = useState([]);

  useEffect(() => {
    axios.get('/data.json')
      .then(response => {
        setData(response.data);
      })
      .catch(error => console.error('Error fetching data:', error));
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

  const generateChartData = () => {
    if (selectedServices.length === 0 || selectedFields.length === 0) return {};

    const datasets = selectedServices.flatMap(service => {
      const serviceData = data[service];
      return selectedFields.map(field => ({
        label: `${service} - ${field}`,
        data: serviceData.map(item => item[field]),
        fill: false,
        borderColor: `#${Math.floor(Math.random() * 16777215).toString(16)}`,
      }));
    });

    const labels = data[selectedServices[0]].map(item => item.Timestamp); // Use Timestamps from the first selected service for labels

    return { labels, datasets };
  };

  return (
    <div className="App">
      <header>
        <h1>Service Benchmarks</h1>
        <div className="service-selection">
          <div className="services">
            <label>Select Services:</label>
            {Object.keys(data).map(service => (
              <div key={service}>
                <input
                  type="checkbox"
                  value={service}
                  onChange={handleServiceChange}
                  checked={selectedServices.includes(service)}
                />
                {service}
              </div>
            ))}
          </div>
          {selectedServices.length > 0 && (
            <div className="fields">
              <label>Select Fields for Y-axis:</label>
              {Object.keys(data[selectedServices[0]][0])
                .filter(field => field !== 'Timestamp') // Exclude Timestamp from selection
                .map(field => (
                  <div key={field}>
                    <input
                      type="checkbox"
                      value={field}
                      onChange={handleFieldChange}
                      checked={selectedFields.includes(field)}
                    />
                    {field}
                  </div>
                ))}
            </div>
          )}
        </div>
      </header>
      <div className="chart-container">
        {selectedServices.length > 0 && selectedFields.length > 0 && (
          <Line data={generateChartData()} />
        )}
      </div>
    </div>
  );
}

export default App;

import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Line } from 'react-chartjs-2';
import 'chart.js/auto';
import './App.css';
import { CircularProgressbar, buildStyles } from 'react-circular-progressbar';
import 'react-circular-progressbar/dist/styles.css';
import { Info, ChevronRight, LineChart, Settings } from 'lucide-react';

// Enhanced color palette
const colorPalette = {
  primary: '#2c3e50', // Dark blue-gray
  secondary: '#3498db', // Bright blue
  accent: '#e74c3c', // Vibrant red
  background: '#ecf0f1', // Light gray
  text: '#34495e', // Soft dark gray
};

const getColor = (serviceName) => {
  const baseColors = {
    db_test: '#2ecc71', // Green for database tests
    no_db_test: '#3498db', // Blue for non-database tests
  };

  return (
    baseColors[serviceName] ||
    `#${Math.floor(Math.random() * 16777215).toString(16)}`
  );
};

function ImprovedBenchmarkApp() {
  const [data, setData] = useState({});
  const [selectedServices, setSelectedServices] = useState([]);
  const [selectedFields, setSelectedFields] = useState([]);
  const [loading, setLoading] = useState(true);
  const [progress, setProgress] = useState(0);
  const [sidebarExpanded, setSidebarExpanded] = useState(true);

  useEffect(() => {
    const baseURL = window.location.pathname.includes('backend-benchmark')
      ? '/backend-benchmark'
      : '';
    const source = axios.CancelToken.source();

    axios
      .get(`${baseURL}/data.json`, {
        cancelToken: source.token,
        onDownloadProgress: (progressEvent) => {
          if (progressEvent.total > 0) {
            const progress = Math.round(
              (progressEvent.loaded * 100) / progressEvent.total
            );
            setProgress(progress);
          }
        },
      })
      .then((response) => {
        setData(response.data);
        setLoading(false);
      })
      .catch((error) => {
        console.error('Error fetching data:', error);
        setLoading(false);
      });

    return () => {
      source.cancel('Component got unmounted');
    };
  }, []);

  const handleServiceChange = (service) => {
    setSelectedServices((prev) =>
      prev.includes(service)
        ? prev.filter((s) => s !== service)
        : [...prev, service]
    );
  };

  const handleFieldChange = (field) => {
    setSelectedFields((prev) =>
      prev.includes(field)
        ? prev.filter((f) => f !== field)
        : [...prev, field]
    );
  };

  const generateChartDataForField = (field) => {
    const datasets = selectedServices.map((service) => ({
      label: `${service} - ${field}`,
      data: data[service].data.map((item) => item[field]),
      fill: false,
      borderColor: getColor(service),
      tension: 0.1, // Add slight curve to lines
    }));

    const labels = data[selectedServices[0]].data.map(
      (item) => item.Timestamp
    );
    return { labels, datasets };
  };

  return (
    <div
      className="App"
      style={{
        backgroundColor: colorPalette.background,
        color: colorPalette.text,
      }}
    >
      <header
        style={{
          backgroundColor: colorPalette.primary,
          color: 'white',
          padding: '15px 20px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <LineChart size={24} />
          <h1 style={{ margin: 0 }}>Service Benchmarks</h1>
        </div>

        <div>
          <button
            onClick={() => setSidebarExpanded(!sidebarExpanded)}
            style={{
              background: 'none',
              border: 'none',
              color: 'white',
              cursor: 'pointer',
            }}
          >
            <Settings size={24} />
          </button>
        </div>
      </header>

      <div className="main-content" style={{ display: 'flex' }}>
        {/* Sidebar */}
        <div
          className={`sidebar ${sidebarExpanded ? '' : 'collapsed'}`}
          style={{
            width: sidebarExpanded ? '250px' : '60px', // Adjust width for collapsed state
            backgroundColor: 'white',
            padding: sidebarExpanded ? '20px' : '10px',
            boxShadow: '0 2px 5px rgba(0,0,0,0.1)',
            transition: 'width 0.3s ease', // Add transition for smooth animation
          }}
        >
          <div
            className="sidebar-toggle"
            onClick={() => setSidebarExpanded(!sidebarExpanded)}
            style={{
              display: 'flex',
              justifyContent: sidebarExpanded ? 'flex-end' : 'center',
              cursor: 'pointer',
              paddingBottom: '10px'
            }}
          >
            <ChevronRight
              size={24}
              style={{
                transform: sidebarExpanded ? '' : 'rotate(180deg)',
                transition: 'transform 0.3s ease',
              }}
            />
          </div>

          {sidebarExpanded && (
            <>
              <div className="services">
                <h3
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    marginBottom: '15px',
                  }}
                >
                  <Info size={20} /> Select Services
                </h3>
                {Object.keys(data).map((service) => (
                  <div
                    key={service}
                    className="checkbox-container"
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      padding: '8px',
                      borderRadius: '4px',
                      transition: 'background-color 0.2s',
                    }}
                    onClick={() => handleServiceChange(service)}
                  >
                    <input
                      type="checkbox"
                      checked={selectedServices.includes(service)}
                      style={{ marginRight: '10px' }}
                      onChange={() => {}}
                    />
                    <span style={{ color: getColor(service) }}>
                      {service
                        .replace('no_db_test', '')
                        .replace('db_test', '')
                        .trim()}
                    </span>
                  </div>
                ))}
              </div>
              <div className="fields">
                <h3
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    marginBottom: '15px',
                    marginTop: '20px',
                  }}
                >
                  <Info size={20} /> Select Fields
                </h3>
                {selectedServices.length > 0 &&
                  Object.keys(data[selectedServices[0]].data[0])
                    .filter(
                      (field) =>
                        !['timestamp', 'Timestamp', 'Time Difference', 'Name', 'Type'].includes(
                          field
                        )
                    )
                    .map((field) => (
                      <div
                        key={field}
                        className="checkbox-container"
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          padding: '8px',
                          borderRadius: '4px',
                          transition: 'background-color 0.2s',
                        }}
                        onClick={() => handleFieldChange(field)}
                      >
                        <input
                          type="checkbox"
                          checked={selectedFields.includes(field)}
                          style={{ marginRight: '10px' }}
                          onChange={() => {}}
                        />
                        <span>{field}</span>
                      </div>
                    ))}
              </div>
            </>
          )}
        </div>

        {/* Main Chart Area */}
        <div
          className="chart-container"
          style={{
            flex: 1,
            padding: '20px',
            overflowY: 'auto',
          }}
        >
          {loading ? (
            <div
              style={{
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                height: '100%',
              }}
            >
              <CircularProgressbar
                value={progress}
                text={`${progress}%`}
                styles={buildStyles({
                  textSize: '16px',
                  pathColor: colorPalette.secondary,
                  textColor: colorPalette.text,
                })}
              />
            </div>
          ) : (
            selectedServices.length > 0 &&
            selectedFields.length > 0 && (
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(400px, 1fr))',
                  gap: '20px',
                }}
              >
                {selectedFields.map((field) => (
                  <div
                    key={field}
                    style={{
                      backgroundColor: 'white',
                      borderRadius: '8px',
                      padding: '15px',
                      boxShadow: '0 4px 6px rgba(0,0,0,0.1)',
                    }}
                  >
                    <h2
                      style={{
                        textAlign: 'center',
                        color: colorPalette.primary,
                        marginBottom: '15px',
                      }}
                    >
                      {field}
                    </h2>
                    <Line
                      data={generateChartDataForField(field)}
                      options={{
                        responsive: true,
                        maintainAspectRatio: false,
                        plugins: {
                          legend: {
                            position: 'bottom',
                          },
                        },
                        scales: {
                          x: {
                            ticks: {
                              autoSkip: true,
                              maxTicksLimit: 10, // Adjust the number of ticks for better readability on x-axis
                            },
                          },
                          y: {
                            beginAtZero: false, // Start y-axis at zero or based on data
                          },
                        },
                      }}
                      height={400} // Set a fixed height for each chart
                    />
                  </div>
                ))}
              </div>
            )
          )}
        </div>
      </div>
    </div>
  );
}

export default ImprovedBenchmarkApp;
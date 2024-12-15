import React, { useEffect, useState } from 'react';
import axios from 'axios';
import { Line } from 'react-chartjs-2';
import 'chart.js/auto';
import './App.css';
import { CircularProgressbar, buildStyles } from 'react-circular-progressbar';
import 'react-circular-progressbar/dist/styles.css';
import {
  Info,
  ChevronDown,
  LineChart,
  Settings,
  Check,
} from 'lucide-react';

// --- Enhanced Color Palette ---
const colorPalette = {
  primary: '#2c3e50', // Dark blue-gray
  secondary: '#3498db', // Bright blue
  accent: '#e74c3c', // Vibrant red
  background: '#ecf0f1', // Light gray
  text: '#34495e', // Soft dark gray
  gray: '#bdc3c7', // Light gray for subtle UI elements
  success: '#2ecc71', // Green for positive indicators
  warning: '#f39c12', // Orange for warnings
  danger: '#e74c3c', // Red for errors or critical alerts
};

const getColor = (serviceName) => {
  const baseColors = {
    db_test: colorPalette.success,
    no_db_test: colorPalette.secondary,
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
  const [servicesExpanded, setServicesExpanded] = useState(true);
  const [fieldsExpanded, setFieldsExpanded] = useState(true);

  // --- Data Fetching ---
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

  // --- Selection Handlers ---
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

  // --- Chart Data Generation ---
  const generateChartDataForField = (field) => {
    const datasets = selectedServices.map((service) => ({
      label: `${service} - ${field}`,
      data: data[service].data.map((item) => item[field]),
      fill: false,
      borderColor: getColor(service),
      tension: 0.4, // Increased tension for smoother curves
      pointBackgroundColor: getColor(service), // Color of data points
      pointBorderColor: colorPalette.background, // Border color of data points
      pointBorderWidth: 2, // Border width of data points
      pointRadius: 4, // Radius of data points
      pointHoverRadius: 6, // Radius of data points on hover
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
        fontFamily: 'Arial, sans-serif', // Professional font
      }}
    >
      {/* --- Header --- */}
      <header
        style={{
          backgroundColor: colorPalette.primary,
          color: 'white',
          padding: '15px 20px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          boxShadow: '0 2px 4px rgba(0,0,0,0.2)', // Subtle shadow for depth
          zIndex: 10, // Ensure header stays on top
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <LineChart size={24} />
          <h1 style={{ margin: 0, fontWeight: '600' }}>
            Service Benchmarks
          </h1>
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

      {/* --- Main Content --- */}
      <div
        className="main-content"
        style={{
          display: 'flex',
          padding: '20px',
          gap: '20px', // Space between sidebar and charts
        }}
      >
        {/* --- Sidebar --- */}
        <div
          className={`sidebar ${sidebarExpanded ? '' : 'collapsed'}`}
          style={{
            width: sidebarExpanded ? '300px' : '60px',
            backgroundColor: 'white',
            borderRadius: '10px', // Rounded corners
            boxShadow: '0 4px 6px rgba(0,0,0,0.1)',
            transition: 'width 0.3s ease, transform 0.3s ease',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
            zIndex: 5,
            position: 'relative', // Needed for the toggle position
          }}
        >
          {/* Sidebar Toggle */}
          <div
            className="sidebar-toggle"
            onClick={() => setSidebarExpanded(!sidebarExpanded)}
            style={{
              position: 'absolute',
              top: '10px',
              right: sidebarExpanded ? '-30px' : '10px',
              backgroundColor: colorPalette.primary,
              width: '30px',
              height: '30px',
              borderRadius: '0 10px 10px 0', // Match sidebar rounding
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              transition: 'right 0.3s ease',
              zIndex: 20, // Make sure it's above other sidebar content
            }}
          >
            <ChevronDown
              size={20}
              color="white"
              style={{
                transform: sidebarExpanded
                  ? 'rotate(90deg)'
                  : 'rotate(-90deg)',
                transition: 'transform 0.3s ease',
              }}
            />
          </div>

          {/* --- Collapsible Sections --- */}
          <div style={{ padding: '20px', overflowY: 'auto', flex: 1 }}>
            {/* Services Section */}
            <div className="section">
              <div
                className="section-header"
                onClick={() => setServicesExpanded(!servicesExpanded)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  cursor: 'pointer',
                  marginBottom: '10px',
                }}
              >
                <h3
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    margin: 0,
                  }}
                >
                  <Info size={20} />
                  Services
                </h3>
                <ChevronDown
                  size={20}
                  style={{
                    transform: servicesExpanded ? '' : 'rotate(-90deg)',
                    transition: 'transform 0.3s ease',
                  }}
                />
              </div>
              {servicesExpanded && (
                <div className="options">
                  {Object.keys(data).map((service) => (
                    <div
                      key={service}
                      className="option"
                      onClick={() => handleServiceChange(service)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        padding: '8px',
                        borderRadius: '4px',
                        transition: 'background-color 0.2s',
                        backgroundColor: selectedServices.includes(service)
                          ? colorPalette.gray
                          : 'transparent',
                        cursor: 'pointer',
                      }}
                    >
                      <div
                        style={{
                          width: '12px',
                          height: '12px',
                          borderRadius: '50%',
                          backgroundColor: getColor(service),
                          marginRight: '10px',
                          border: '2px solid white', // Add a border to the circle
                          boxShadow: `0 0 0 2px ${getColor(
                            service
                          )}`, // Add a shadow effect
                        }}
                      >
                        {selectedServices.includes(service) && (
                          <Check
                            size={10}
                            color="white"
                            style={{
                              position: 'relative',
                              top: '1px',
                              left: '1px',
                            }}
                          />
                        )}
                      </div>
                      <span style={{ color: colorPalette.text }}>
                        {service
                          .replace('no_db_test', '')
                          .replace('db_test', '')
                          .trim()}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Fields Section */}
            <div className="section" style={{ marginTop: '20px' }}>
              <div
                className="section-header"
                onClick={() => setFieldsExpanded(!fieldsExpanded)}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  cursor: 'pointer',
                  marginBottom: '10px',
                }}
              >
                <h3
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '10px',
                    margin: 0,
                  }}
                >
                  <Info size={20} />
                  Fields
                </h3>
                <ChevronDown
                  size={20}
                  style={{
                    transform: fieldsExpanded ? '' : 'rotate(-90deg)',
                    transition: 'transform 0.3s ease',
                  }}
                />
              </div>
              {fieldsExpanded && (
                <div className="options">
                  {selectedServices.length > 0 &&
                    Object.keys(data[selectedServices[0]].data[0])
                      .filter(
                        (field) =>
                          ![
                            'timestamp',
                            'Timestamp',
                            'Time Difference',
                            'Name',
                            'Type',
                          ].includes(field)
                      )
                      .map((field) => (
                        <div
                          key={field}
                          className="option"
                          onClick={() => handleFieldChange(field)}
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            padding: '8px',
                            borderRadius: '4px',
                            transition: 'background-color 0.2s',
                            backgroundColor: selectedFields.includes(field)
                              ? colorPalette.gray
                              : 'transparent',
                            cursor: 'pointer',
                          }}
                        >
                          <div
                            style={{
                              width: '12px',
                              height: '12px',
                              borderRadius: '50%',
                              backgroundColor: selectedFields.includes(field)
                                ? colorPalette.accent
                                : colorPalette.gray,
                              marginRight: '10px',
                            }}
                          >
                            {selectedFields.includes(field) && (
                              <Check
                                size={10}
                                color="white"
                                style={{
                                  position: 'relative',
                                  top: '1px',
                                  left: '1px',
                                }}
                              />
                            )}
                          </div>
                          <span style={{ color: colorPalette.text }}>
                            {field}
                          </span>
                        </div>
                      ))}
                </div>
              )}
            </div>
          </div>
        </div>

        {/* --- Chart Container --- */}
        <div
          className="chart-container"
          style={{
            flex: 1,
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
                  trailColor: colorPalette.gray,
                })}
              />
            </div>
          ) : (
            selectedServices.length > 0 &&
            selectedFields.length > 0 && (
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(450px, 1fr))',
                  gap: '20px',
                }}
              >
                {selectedFields.map((field) => (
                  <div
                    key={field}
                    style={{
                      backgroundColor: 'white',
                      borderRadius: '10px',
                      padding: '20px',
                      boxShadow: '0 4px 6px rgba(0,0,0,0.1)',
                    }}
                  >
                    <h2
                      style={{
                        textAlign: 'center',
                        color: colorPalette.primary,
                        marginBottom: '15px',
                        fontWeight: '600',
                      }}
                    >
                      {field}
                    </h2>
                    <div style={{ height: '350px' }}>
                      {' '}
                      {/* Fixed height for charts */}
                      <Line
                        data={generateChartDataForField(field)}
                        options={{
                          responsive: true,
                          maintainAspectRatio: false,
                          plugins: {
                            legend: {
                              position: 'bottom',
                              labels: {
                                color: colorPalette.text,
                                boxWidth: 20,
                                padding: 20,
                              },
                            },
                          },
                          scales: {
                            x: {
                              ticks: {
                                autoSkip: true,
                                maxTicksLimit: 10,
                                color: colorPalette.text,
                              },
                              grid: {
                                color: colorPalette.gray,
                              },
                            },
                            y: {
                              beginAtZero: false,
                              ticks: {
                                color: colorPalette.text,
                              },
                              grid: {
                                color: colorPalette.gray,
                              },
                            },
                          },
                        }}
                      />
                    </div>
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
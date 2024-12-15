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
  Database,
  Cpu,
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

// --- Service Color Patterns ---
const serviceColorPatterns = [
  { pattern: /python/i, baseColor: '#3776AB' }, // Python (Steel Blue)
  { pattern: /django/i, baseColor: '#092E20' }, // Django (Dark Green) - more specific
  { pattern: /fast \s?api/i, baseColor: '#009485' }, // Fast API (Teal) - more specific
  { pattern: /javascript|js/i, baseColor: '#F0DB4F' }, // JavaScript (Yellow)
  { pattern: /express/i, baseColor: '#68A063' }, // Express (Light Green) - more specific
  { pattern: /bun/i, baseColor: '#F0DB4F' }, // Bun (Yellow) - more specific, same as JavaScript
  { pattern: /node/i, baseColor: '#68A063' }, // Node.js (Light Green) - more specific, same as Express
  { pattern: /go|golang/i, baseColor: '#00ADD8' }, // Go (Light Blue)
  { pattern: /mux/i, baseColor: '#00ADD8' }, // Go Mux (Light Blue) - same as Go
  { pattern: /java/i, baseColor: '#5382A1' }, // Java (Slate Blue)
  { pattern: /spring/i, baseColor: '#5382A1' }, // Spring (Slate Blue) - same as Java
  { pattern: /c#|csharp/i, baseColor: '#67217A' }, // C# (Purple)
  { pattern: /\.net/i, baseColor: '#67217A' }, // .NET (Purple) - same as C#
  { pattern: /rust/i, baseColor: '#DEA584' }, // Rust (Light Brown)
  { pattern: /actix/i, baseColor: '#DEA584' }, // Actix (Light Brown) - same as Rust
  { pattern: /dart/i, baseColor: '#0175C2' }, // Dart (Blue)
  { pattern: /server\s?pod/i, baseColor: '#0175C2' }, // Server Pod (Blue) - same as Dart
];

// --- Helper function to darken a color ---
function darkenColor(hexColor, factor = 0.6) {
  // Convert hex to RGB
  let r = parseInt(hexColor.slice(1, 3), 16);
  let g = parseInt(hexColor.slice(3, 5), 16);
  let b = parseInt(hexColor.slice(5, 7), 16);

  // Darken each component
  r = Math.floor(r * factor);
  g = Math.floor(g * factor);
  b = Math.floor(b * factor);

  // Convert back to hex
  return `#${r.toString(16).padStart(2, '0')}${g
    .toString(16)
    .padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
}

// --- Get Color Function ---
const getColor = (serviceName) => {
  const lowerCaseServiceName = serviceName.toLowerCase();
  const isDbService = lowerCaseServiceName.includes('no_db_test');

  for (const { pattern, baseColor } of serviceColorPatterns) {
    if (pattern.test(lowerCaseServiceName)) {
      // Darken the color if it's a DB service
      return isDbService ? darkenColor(baseColor) : baseColor;
    }
  }

  return colorPalette.gray; // Default to gray if no pattern matches
};


function ImprovedBenchmarkApp() {
  const [data, setData] = useState({});
  const [selectedServices, setSelectedServices] = useState([]);
  const [selectedFields, setSelectedFields] = useState([]);
  const [loading, setLoading] = useState(true);
  const [progress, setProgress] = useState(0);
  const [sidebarExpanded, setSidebarExpanded] = useState(true);
  const [servicesExpanded, setServicesExpanded] = useState(true);
  const [dbServicesExpanded, setDbServicesExpanded] = useState(true); // State for DB services section
  const [noDbServicesExpanded, setNoDbServicesExpanded] =
    useState(true); // State for No DB services section
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

  // --- Chart Data Generation with Smoothing ---
  const generateChartDataForField = (field) => {
    const datasets = selectedServices.map((service) => {
      const rawData = data[service].data.map((item) => item[field]);
      const smoothedData = smoothData(rawData); // Apply smoothing to the data

      return {
        label: `${service} - ${field}`,
        data: smoothedData, // Use smoothed data here
        fill: false,
        borderColor: getColor(service),
        tension: 0.4, // Increased tension for smoother curves
        pointBackgroundColor: getColor(service),
        pointBorderColor: colorPalette.background,
        pointBorderWidth: 2,
        pointRadius: 0, // Set pointRadius to 0 to hide data points
        pointHoverRadius: 6,
      };
    });

    const labels = data[selectedServices[0]].data.map(
      (item) => item.Timestamp
    );
    return { labels, datasets };
  };

  // --- Data Smoothing Function ---
  const smoothData = (data) => {
    if (data.length < 3) {
      return data; // Not enough data points to smooth
    }

    const smoothed = [];
    for (let i = 0; i < data.length; i++) {
      if (i === 0 || i === data.length - 1) {
        smoothed.push(data[i]); // Keep first and last data points as is
      } else {
        const average = (data[i - 1] + data[i] + data[i + 1]) / 3;
        smoothed.push(average); // Replace with average of neighboring points
      }
    }
    return smoothed;
  };

  return (
    <div
      className="App"
      style={{
        backgroundColor: colorPalette.background,
        color: colorPalette.text,
        fontFamily: 'Arial, sans-serif',
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
          boxShadow: '0 2px 4px rgba(0,0,0,0.2)',
          zIndex: 10,
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
          gap: '20px',
        }}
      >
        {/* --- Sidebar --- */}
        <div
          className={`sidebar ${sidebarExpanded ? '' : 'collapsed'}`}
          style={{
            width: sidebarExpanded ? '300px' : '60px',
            backgroundColor: 'white',
            borderRadius: '10px',
            boxShadow: '0 4px 6px rgba(0,0,0,0.1)',
            transition: 'width 0.3s ease, transform 0.3s ease',
            overflow: 'hidden',
            display: 'flex',
            flexDirection: 'column',
            zIndex: 5,
            position: 'relative',
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
              borderRadius: '0 10px 10px 0',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              transition: 'right 0.3s ease',
              zIndex: 20,
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
                <>
                  {/* DB Services */}
                  <div className="subsection">
                    <div
                      className="subsection-header"
                      onClick={() => setDbServicesExpanded(!dbServicesExpanded)}
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        cursor: 'pointer',
                        marginTop: '10px',
                      }}
                    >
                      <h4
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '10px',
                          margin: 0,
                        }}
                      >
                        <Database size={18} />
                        DB Services
                      </h4>
                      <ChevronDown
                        size={18}
                        style={{
                          transform: dbServicesExpanded ? '' : 'rotate(-90deg)',
                          transition: 'transform 0.3s ease',
                        }}
                      />
                    </div>
                    {dbServicesExpanded && (
                      <div className="options">
                        {Object.keys(data)
                          .filter(
                            (service) =>
                              service.includes('db_test') &&
                              !service.includes('no_db_test')
                          )
                          .map((service) => (
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
                                backgroundColor:
                                  selectedServices.includes(service)
                                    ? colorPalette.gray
                                    : 'transparent',
                                cursor: 'pointer',
                              }}
                            >
                              {/* ... (rest of the option content) */}
                              <div
                                style={{
                                  width: '12px',
                                  height: '12px',
                                  borderRadius: '50%',
                                  backgroundColor: getColor(service),
                                  marginRight: '10px',
                                  border: '2px solid white',
                                  boxShadow: `0 0 0 2px ${getColor(service)}`,
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
                                {service.replace('no_db_test', '')
                                  .replace('db_test', '')
                                  
                                  .trim()}
                              </span>
                            </div>
                          ))}
                      </div>
                    )}
                  </div>

                  {/* No DB Services */}
                  <div className="subsection">
                    <div
                      className="subsection-header"
                      onClick={() =>
                        setNoDbServicesExpanded(!noDbServicesExpanded)
                      }
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        cursor: 'pointer',
                        marginTop: '10px',
                      }}
                    >
                      <h4
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: '10px',
                          margin: 0,
                        }}
                      >
                        <Cpu size={18} />
                        No DB Services
                      </h4>
                      <ChevronDown
                        size={18}
                        style={{
                          transform: noDbServicesExpanded
                            ? ''
                            : 'rotate(-90deg)',
                          transition: 'transform 0.3s ease',
                        }}
                      />
                    </div>
                    {noDbServicesExpanded && (
                      <div className="options">
                        {Object.keys(data)
                          .filter((service) => service.includes('no_db_test'))
                          .map((service) => (
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
                                backgroundColor:
                                  selectedServices.includes(service)
                                    ? colorPalette.gray
                                    : 'transparent',
                                cursor: 'pointer',
                              }}
                            >
                              {/* ... (rest of the option content) */}
                              <div
                                style={{
                                  width: '12px',
                                  height: '12px',
                                  borderRadius: '50%',
                                  backgroundColor: getColor(service),
                                  marginRight: '10px',
                                  border: '2px solid white',
                                  boxShadow: `0 0 0 2px ${getColor(service)}`,
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
                </>
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
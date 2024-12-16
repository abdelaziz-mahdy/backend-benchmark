import React, { useEffect, useState, useMemo } from "react";
import axios from "axios";
import { Line } from "react-chartjs-2";
import "chart.js/auto";
import "./App.css";
import { CircularProgressbar, buildStyles } from "react-circular-progressbar";
import "react-circular-progressbar/dist/styles.css";
import {
  Info,
  ChevronDown,
  LineChart,
  Settings,
  Database,
  Cpu,
  Filter,
} from "lucide-react";
import { ToastContainer, toast } from "react-toastify";
import "react-toastify/dist/ReactToastify.css";
import { saveAs } from "file-saver";

// --- Enhanced Color Palette ---
const colorPalette = {
  primary: "#2c3e50", // Dark blue-gray
  secondary: "#3498db", // Bright blue
  accent: "#e74c3c", // Vibrant red
  background: "#ecf0f1", // Light gray
  text: "#34495e", // Soft dark gray
  gray: "#bdc3c7", // Light gray for subtle UI elements
  success: "#2ecc71", // Green for positive indicators
  warning: "#f39c12", // Orange for warnings
  danger: "#e74c3c", // Red for errors or critical alerts
  light: {
    buttonBg: "#3498db",
    buttonText: "#fff",
    buttonHoverBg: "#2980b9",
    link: "#3498db",
  },
  dark: {
    buttonBg: "#bdc3c7",
    buttonText: "#2c3e50",
    buttonHoverBg: "#95a5a6",
    link: "#bdc3c7",
  },
};

// --- Service Color Patterns ---
const serviceColorPatterns = [
  { pattern: /python/i, baseColor: "#3776AB" }, // Python (Steel Blue)
  { pattern: /django/i, baseColor: "#092E20" }, // Django (Dark Green) - more specific
  { pattern: /fast \s?api/i, baseColor: "#009485" }, // Fast API (Teal) - more specific
  { pattern: /javascript|js/i, baseColor: "#F0DB4F" }, // JavaScript (Yellow)
  { pattern: /express/i, baseColor: "#68A063" }, // Express (Light Green) - more specific
  { pattern: /bun/i, baseColor: "#F0DB4F" }, // Bun (Yellow) - more specific, same as JavaScript
  { pattern: /node/i, baseColor: "#68A063" }, // Node.js (Light Green) - more specific, same as Express
  { pattern: /go|golang/i, baseColor: "#00ADD8" }, // Go (Light Blue)
  { pattern: /mux/i, baseColor: "#00ADD8" }, // Go Mux (Light Blue) - same as Go
  { pattern: /java/i, baseColor: "#5382A1" }, // Java (Slate Blue)
  { pattern: /spring/i, baseColor: "#5382A1" }, // Spring (Slate Blue) - same as Java
  { pattern: /c#|csharp/i, baseColor: "#67217A" }, // C# (Purple)
  { pattern: /\.net/i, baseColor: "#67217A" }, // .NET (Purple) - same as C#
  { pattern: /rust/i, baseColor: "#DEA584" }, // Rust (Light Brown)
  { pattern: /actix/i, baseColor: "#DEA584" }, // Actix (Light Brown) - same as Rust
  { pattern: /dart/i, baseColor: "#0175C2" }, // Dart (Blue)
  { pattern: /server\s?pod/i, baseColor: "#0175C2" }, // Server Pod (Blue) - same as Dart
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
  return `#${r.toString(16).padStart(2, "0")}${g
    .toString(16)
    .padStart(2, "0")}${b.toString(16).padStart(2, "0")}`;
}

// --- Get Color Function ---
const getColor = (serviceName) => {
  const lowerCaseServiceName = serviceName.toLowerCase();
  const isDbService = lowerCaseServiceName.includes("no_db_test");

  for (const { pattern, baseColor } of serviceColorPatterns) {
    if (pattern.test(lowerCaseServiceName)) {
      // Darken the color if it's a DB service
      return isDbService ? darkenColor(baseColor) : baseColor;
    }
  }

  return colorPalette.gray; // Default to gray if no pattern matches
};

// --- Theme Context ---
const ThemeContext = React.createContext();

function ImprovedBenchmarkApp() {
  const [data, setData] = useState({});
  const [selectedServices, setSelectedServices] = useState([]);
  const [selectedFields, setSelectedFields] = useState([]);
  const [loading, setLoading] = useState(true);
  const [progress, setProgress] = useState(0);
  const [sidebarExpanded, setSidebarExpanded] = useState(true);
  const [servicesExpanded, setServicesExpanded] = useState(true);
  const [dbServicesExpanded, setDbServicesExpanded] = useState(true);
  const [noDbServicesExpanded, setNoDbServicesExpanded] = useState(true);
  const [fieldsExpanded, setFieldsExpanded] = useState(true);
  const [allFieldsSelected, setAllFieldsSelected] = useState(false);
  const [theme, setTheme] = useState("light");

  // --- Theme Toggle Function ---
  const toggleTheme = () => {
    setTheme(theme === "light" ? "dark" : "light");
  };

  // --- Data Fetching with Error Handling and Partial Loading ---
  useEffect(() => {
    const baseURL = window.location.pathname.includes("backend-benchmark")
      ? "/backend-benchmark"
      : "";
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
        console.error("Error fetching data:", error);
        toast.error("Failed to fetch data"); // Toast notification for error
        setLoading(false);
      });

    return () => {
      source.cancel("Component got unmounted");
    };
  }, []);

  // --- Selection Handlers with Checkboxes ---
  const handleServiceChange = (service) => {
    setSelectedServices((prev) => {
      const updatedServices = prev.includes(service)
        ? prev.filter((s) => s !== service)
        : [...prev, service];

      // // If a service is deselected, also deselect all its fields
      // if (!prev.includes(service)) {
      //   setSelectedFields((prevFields) =>
      //     prevFields.filter((field) => !data[service]?.data[0]?.hasOwnProperty(field))
      //   );
      // }

      return updatedServices;
    });
  };

  const handleFieldChange = (field) => {
    if (field === "all") {
      // Handle "All Fields" selection
      setAllFieldsSelected(!allFieldsSelected);
      if (!allFieldsSelected) {
        // Select all fields
        const allFields = Object.keys(data[selectedServices[0]].data[0]).filter(
          (f) =>
            ![
              "timestamp",
              "Timestamp",
              "Time Difference",
              "Name",
              "Type",
            ].includes(f)
        );
        setSelectedFields(allFields);
      } else {
        // Deselect all fields
        setSelectedFields([]);
      }
    } else {
      // Handle individual field selection
      setSelectedFields((prev) =>
        prev.includes(field)
          ? prev.filter((f) => f !== field)
          : [...prev, field]
      );
    }
  };

  // --- Memoized Chart Data Generation with Smoothing ---
  const generateChartDataForField = useMemo(() => {
    return (field) => {
      const datasets = selectedServices
        .filter((service) => !data[service]?.error) // Exclude services with errors
        .map((service) => {
          const rawData = data[service].data.map((item) => item[field]);
          const smoothedData = smoothData(rawData);

          return {
            label: `${service}`,
            data: smoothedData,
            fill: false,
            borderColor: getColor(service),
            tension: 0.4,
            pointBackgroundColor: getColor(service),
            pointBorderColor: colorPalette.background,
            pointBorderWidth: 2,
            pointRadius: 0,
            pointHoverRadius: 6,
          };
        });

      const labels = data[selectedServices[0]].data.map(
        (item) => item.Timestamp
      );

      return { labels, datasets };
    };
  }, [selectedServices, data]);

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

  // --- Download Chart Function ---
  const downloadChart = (chartRef, field) => {
    if (chartRef.current) {
      const chartCanvas = chartRef.current.toBase64Image();
      saveAs(chartCanvas, `chart-${field}.png`);
    }
  };

  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      <div
        className="App"
        style={{
          backgroundColor:
            theme === "light" ? colorPalette.background : colorPalette.primary,
          color: theme === "light" ? colorPalette.text : "white",
          fontFamily: "Arial, sans-serif",
        }}
      >
        <ToastContainer /> {/* Container for toast notifications */}
        {/* --- Header --- */}
        <header
          style={{
            backgroundColor:
              theme === "light"
                ? colorPalette.primary
                : colorPalette.background,
            color: theme === "light" ? "white" : colorPalette.text,
            padding: "15px 20px",
            display: "flex",
            justifyContent: "space-between",
            alignItems: "center",
            boxShadow: "0 2px 4px rgba(0,0,0,0.2)",
            zIndex: 10,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <LineChart size={24} />
            <h1 style={{ margin: 0, fontWeight: "600" }}>Service Benchmarks</h1>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            {/* Theme Toggle Button */}
            {/* <button
              onClick={toggleTheme}
              style={{
                background: 'none',
                border: 'none',
                color: theme === 'light' ? 'white' : colorPalette.text,
                cursor: 'pointer',
              }}
              aria-label="Toggle Theme"
            >
              {theme === 'light' ? '🌙' : '☀️'}
            </button> */}

            {/* Settings Button */}
            <button
              onClick={() => setSidebarExpanded(!sidebarExpanded)}
              style={{
                background: "none",
                border: "none",
                color: theme === "light" ? "white" : colorPalette.text,
                cursor: "pointer",
              }}
              aria-label="Toggle Sidebar"
            >
              <Settings size={24} />
            </button>
          </div>
        </header>
        {/* --- Main Content --- */}
        <div
          className="main-content"
          style={{ display: "flex", padding: "20px", gap: "20px" }}
        >
          {/* --- Sidebar --- */}
          <div
            className={`sidebar ${sidebarExpanded ? "" : "collapsed"}`}
            style={{
              width: sidebarExpanded ? "300px" : "60px",
              backgroundColor: "white",
              borderRadius: "10px",
              boxShadow: "0 4px 6px rgba(0,0,0,0.1)",
              transition: "width 0.3s ease, transform 0.3s ease",
              overflow: "hidden",
              display: "flex",
              flexDirection: "column",
              zIndex: 5,
              position: "relative",
            }}
          >
            {/* Sidebar Toggle */}
            <div
              className="sidebar-toggle"
              onClick={() => setSidebarExpanded(!sidebarExpanded)}
              style={{
                position: "absolute",
                top: "10px",
                right: sidebarExpanded ? "-30px" : "10px",
                backgroundColor: colorPalette.primary,
                width: "30px",
                height: "30px",
                borderRadius: "0 10px 10px 0",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                cursor: "pointer",
                transition: "right 0.3s ease",
                zIndex: 20,
              }}
            >
              <ChevronDown
                size={20}
                color="white"
                style={{
                  transform: sidebarExpanded
                    ? "rotate(90deg)"
                    : "rotate(-90deg)",
                  transition: "transform 0.3s ease",
                }}
              />
            </div>
            {/* --- Collapsible Sections --- */}
            <div style={{ padding: "20px", overflowY: "auto", flex: 1 }}>
              {/* Services Section */}
              <div className="section">
                <div
                  className="section-header"
                  onClick={() => setServicesExpanded(!servicesExpanded)}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    cursor: "pointer",
                    marginBottom: "10px",
                  }}
                >
                  <h3
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "10px",
                      margin: 0,
                    }}
                  >
                    <div className="tooltip">
                      <Info size={20} />
                      {sidebarExpanded === false && (
                        <span className="tooltiptext">Services</span>
                      )}
                    </div>
                    Services
                  </h3>
                  <ChevronDown
                    size={20}
                    style={{
                      transform: servicesExpanded ? "" : "rotate(-90deg)",
                      transition: "transform 0.3s ease",
                    }}
                  />
                </div>
                {servicesExpanded && (
                  <>
                    {/* DB Services */}
                    <div className="subsection">
                      <div
                        className="subsection-header"
                        onClick={() =>
                          setDbServicesExpanded(!dbServicesExpanded)
                        }
                        style={{
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "space-between",
                          cursor: "pointer",
                          marginTop: "10px",
                        }}
                      >
                        <h4
                          style={{
                            display: "flex",
                            alignItems: "center",
                            gap: "10px",
                            margin: 0,
                          }}
                        >
                          <div className="tooltip">
                            <Database size={18} />
                            {sidebarExpanded === false && (
                              <span className="tooltiptext">DB Services</span>
                            )}
                          </div>
                          DB Services
                        </h4>
                        <ChevronDown
                          size={18}
                          style={{
                            transform: dbServicesExpanded
                              ? ""
                              : "rotate(-90deg)",
                            transition: "transform 0.3s ease",
                          }}
                        />
                      </div>
                      {dbServicesExpanded && (
                        <div className="options">
                          {Object.keys(data)
                            .filter(
                              (service) =>
                                service.includes("db_test") &&
                                !service.includes("no_db_test")
                            )
                            .map((service) => (
                              <div
                                key={service}
                                className="option"
                                onClick={() => handleServiceChange(service)}
                                style={{
                                  display: "flex",
                                  alignItems: "center",
                                  padding: "8px",
                                  borderRadius: "4px",
                                  transition: "background-color 0.2s",
                                  backgroundColor: selectedServices.includes(
                                    service
                                  )
                                    ? colorPalette.accent
                                    : "transparent",
                                  fontWeight: selectedServices.includes(service)
                                    ? "bold"
                                    : "normal",
                                  cursor: "pointer",
                                  position: "relative",
                                }}
                              >
                                <input
                                  type="checkbox"
                                  checked={selectedServices.includes(service)}
                                  onChange={() => handleServiceChange(service)}
                                  style={{
                                    marginRight: "10px",
                                    marginLeft: "0",
                                  }}
                                />
                                <div
                                  style={{
                                    width: "12px",
                                    height: "12px",
                                    borderRadius: "50%",
                                    backgroundColor: getColor(service),
                                    marginRight: "10px",
                                    border: "2px solid white",
                                    boxShadow: `0 0 0 2px ${getColor(service)}`,
                                  }}
                                >
                                  {selectedServices.includes(service)}
                                </div>
                                <span
                                  style={{
                                    color: selectedServices.includes(service)
                                      ? "white"
                                      : colorPalette.text,
                                  }}
                                >
                                  {/* Text label */}
                                  {service
                                    .replace("no_db_test", "")
                                    .replace("db_test", "")
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
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "space-between",
                          cursor: "pointer",
                          marginTop: "10px",
                        }}
                      >
                        <h4
                          style={{
                            display: "flex",
                            alignItems: "center",
                            gap: "10px",
                            margin: 0,
                          }}
                        >
                          <div className="tooltip">
                            <Cpu size={18} />
                            {sidebarExpanded === false && (
                              <span className="tooltiptext">
                                No DB Services
                              </span>
                            )}
                          </div>
                          No DB Services
                        </h4>
                        <ChevronDown
                          size={18}
                          style={{
                            transform: noDbServicesExpanded
                              ? ""
                              : "rotate(-90deg)",
                            transition: "transform 0.3s ease",
                          }}
                        />
                      </div>
                      {noDbServicesExpanded && (
                        <div className="options">
                          {Object.keys(data)
                            .filter((service) => service.includes("no_db_test"))
                            .map((service) => (
                              <div
                                key={service}
                                className="option"
                                onClick={() => handleServiceChange(service)}
                                style={{
                                  display: "flex",
                                  alignItems: "center",
                                  padding: "8px",
                                  borderRadius: "4px",
                                  transition: "background-color 0.2s",
                                  backgroundColor: selectedServices.includes(
                                    service
                                  )
                                    ? colorPalette.accent
                                    : "transparent",
                                  fontWeight: selectedServices.includes(service)
                                    ? "bold"
                                    : "normal",
                                  cursor: "pointer",
                                }}
                              >
                                <input
                                  type="checkbox"
                                  checked={selectedServices.includes(service)}
                                  onChange={() => handleServiceChange(service)}
                                  style={{
                                    marginRight: "10px",
                                    marginLeft: "0",
                                  }}
                                />
                                <div
                                  style={{
                                    width: "12px",
                                    height: "12px",
                                    borderRadius: "50%",
                                    backgroundColor: getColor(service),
                                    marginRight: "10px",
                                    border: "2px solid white",
                                    boxShadow: `0 0 0 2px ${getColor(service)}`,
                                  }}
                                ></div>
                                <span
                                  style={{
                                    color: selectedServices.includes(service)
                                      ? "white"
                                      : colorPalette.text,
                                  }}
                                >
                                  {/* Text label */}
                                  {service
                                    .replace("no_db_test", "")
                                    .replace("db_test", "")
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
              <div className="section" style={{ marginTop: "20px" }}>
                <div
                  className="section-header"
                  onClick={() => setFieldsExpanded(!fieldsExpanded)}
                  style={{
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "space-between",
                    cursor: "pointer",
                    marginBottom: "10px",
                  }}
                >
                  <h3
                    style={{
                      display: "flex",
                      alignItems: "center",
                      gap: "10px",
                      margin: 0,
                    }}
                  >
                    <div className="tooltip">
                      <Filter size={20} />
                      {sidebarExpanded === false && (
                        <span className="tooltiptext">Fields</span>
                      )}
                    </div>
                    Fields
                  </h3>
                  <ChevronDown
                    size={20}
                    style={{
                      transform: fieldsExpanded ? "" : "rotate(-90deg)",
                      transition: "transform 0.3s ease",
                    }}
                  />
                </div>
                {fieldsExpanded && (
                  <div className="options">
                    {/* All Fields Checkbox */}
                    <div
                      className="option"
                      onClick={() => handleFieldChange("all")}
                      style={{
                        display: "flex",
                        alignItems: "center",
                        padding: "8px",
                        borderRadius: "4px",
                        transition: "background-color 0.2s",
                        backgroundColor: allFieldsSelected
                          ? colorPalette.gray
                          : "transparent",
                        cursor: "pointer",
                      }}
                    >
                      <input
                        type="checkbox"
                        checked={allFieldsSelected}
                        onChange={() => handleFieldChange("all")}
                        style={{ marginRight: "10px" }}
                      />
                      <span style={{ color: colorPalette.text }}>
                        All Fields
                      </span>
                    </div>

                    {/* Individual Field Checkboxes */}
                    {selectedServices.length > 0 &&
                      Object.keys(data[selectedServices[0]]?.data[0] || {})
                        .filter(
                          (field) =>
                            ![
                              "timestamp",
                              "Timestamp",
                              "Time Difference",
                              "Name",
                              "Type",
                            ].includes(field)
                        )
                        .map((field) => (
                          <div
                            key={field}
                            className="option"
                            onClick={() => handleFieldChange(field)}
                            style={{
                              display: "flex",
                              alignItems: "center",
                              padding: "8px",
                              borderRadius: "4px",
                              transition: "background-color 0.2s",
                              backgroundColor: selectedFields.includes(field)
                                ? colorPalette.accent
                                : "transparent",
                              fontWeight: selectedFields.includes(field)
                                ? "bold"
                                : "normal",
                              cursor: "pointer",
                            }}
                          >
                            <input
                              type="checkbox"
                              checked={selectedFields.includes(field)}
                              onChange={() => handleFieldChange(field)}
                              style={{ marginRight: "10px" }}
                            />
                            <div
                              style={{
                                width: "12px",
                                height: "12px",
                                borderRadius: "50%",
                                backgroundColor: selectedFields.includes(field)
                                  ? colorPalette.accent
                                  : colorPalette.gray,
                                marginRight: "10px",
                              }}
                            >
                              {selectedFields.includes(field)}
                            </div>
                            <span
                              style={{
                                color: selectedFields.includes(field)
                                  ? "white"
                                  : colorPalette.text,
                              }}
                            >
                              {/* Text label */}
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
            style={{ flex: 1, overflowY: "auto" }}
          >
            {loading ? (
              <div
                style={{
                  display: "flex",
                  justifyContent: "center",
                  alignItems: "center",
                  height: "100%",
                }}
              >
                <CircularProgressbar
                  value={progress}
                  text={`${progress}%`}
                  styles={buildStyles({
                    textSize: "16px",
                    pathColor: colorPalette.secondary,
                    textColor: colorPalette.text,
                    trailColor: colorPalette.gray,
                  })}
                />
              </div>
            ) : selectedServices.length > 0 && selectedFields.length > 0 ? (
              <div
                style={{
                  display: "grid",
                  gridTemplateColumns: "repeat(auto-fit, minmax(450px, 1fr))",
                  gap: "20px",
                }}
              >
                {selectedFields.map((field) => {
                  const chartRef = React.createRef();

                  // Check if any of the selected services have an error for this field
                  const hasError = selectedServices.some(
                    (service) => data[service]?.error
                  );

                  if (hasError) {
                    return (
                      <div key={field} className="chart-card">
                        <h2>{field}</h2>
                        <p className="error-message">
                          Error loading data for one or more selected services.
                        </p>
                      </div>
                    );
                  }

                  return (
                    <div key={field} className="chart-card">
                      <div
                        style={{
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "space-between",
                        }}
                      >
                        <h2
                          style={{
                            textAlign: "center",
                            color: colorPalette.primary,
                            marginBottom: "15px",
                            fontWeight: "600",
                          }}
                        >
                          {field}
                        </h2>
                        {/* Download Button */}
                        <button
                          onClick={() => downloadChart(chartRef, field)}
                          style={{
                            background: "none",
                            border: `1px solid ${
                              theme === "light"
                                ? colorPalette.text
                                : colorPalette.background
                            }`,
                            borderRadius: "5px",
                            padding: "5px 10px",
                            cursor: "pointer",
                            fontSize: "0.9rem",
                            color:
                              theme === "light"
                                ? colorPalette.text
                                : colorPalette.background,
                          }}
                        >
                          Download Chart
                        </button>
                      </div>
                      {/* Summary Statistics */}
                      {/* <div className="summary-stats">
                        <p>
                          Avg:{' '}
                          <span>
                            {calculateAverage(
                              generateChartDataForField(field).datasets
                            )}
                          </span>
                        </p>
                      </div> */}
                      <div style={{ height: "600px" }}>
                        <Line
                          ref={chartRef}
                          data={generateChartDataForField(field)}
                          options={{
                            responsive: true,
                            maintainAspectRatio: false,
                            plugins: {
                              legend: {
                                position: "bottom",
                                labels: {
                                  color:
                                    theme === "light"
                                      ? colorPalette.text
                                      : "white",
                                  boxWidth: 20,
                                  padding: 20,
                                },
                              },
                              title: {
                                display: false,
                                text: `${selectedServices.join(
                                  " vs "
                                )} - ${field}`,
                                color: colorPalette.text,
                                font: {
                                  size: 16,
                                  weight: "bold",
                                },
                                padding: {
                                  bottom: 20,
                                },
                              },
                              tooltip: {
                                enabled: true, // Enable tooltips
                                mode: "index", // Show tooltips for all datasets at a specific x-value
                                intersect: false, // Tooltips appear even when not directly over a data point
                                backgroundColor: "rgba(0, 0, 0, 0.8)", // Customize tooltip appearance
                                titleColor: "#fff",
                                bodyColor: "#fff",
                                borderColor: "rgba(0, 0, 0, 0.2)",
                                borderWidth: 1,
                              },
                              zoom: {
                                zoom: {
                                  wheel: {
                                    enabled: true, // Enable zooming with the mouse wheel
                                  },
                                  pinch: {
                                    enabled: true, // Enable pinch-to-zoom on touch devices
                                  },
                                  mode: "x", // Allow zooming only on the x-axis (time)
                                },
                                pan: {
                                  enabled: true, // Enable panning (dragging)
                                  mode: "x", // Allow panning only on the x-axis
                                },
                              },
                            },
                            scales: {
                              x: {
                                title: {
                                  display: true,
                                  text: "Time In Seconds",
                                  color: colorPalette.text,
                                  font: {
                                    size: 14,
                                    weight: "bold",
                                  },
                                },
                                ticks: {
                                  autoSkip: true,
                                  maxTicksLimit: 10,
                                  color:
                                    theme === "light"
                                      ? colorPalette.text
                                      : "white", // Dynamic axis tick color
                                },
                                grid: {
                                  color:
                                    theme === "light"
                                      ? colorPalette.gray
                                      : "rgba(255, 255, 255, 0.2)", // Dynamic grid color
                                },
                              },
                              y: {
                                title: {
                                  display: true,
                                  text: field,
                                  color: colorPalette.text,
                                  font: {
                                    size: 14,
                                    weight: "bold",
                                  },
                                },
                                beginAtZero: false,
                                ticks: {
                                  color:
                                    theme === "light"
                                      ? colorPalette.text
                                      : "white", // Dynamic axis tick color
                                },
                                grid: {
                                  color:
                                    theme === "light"
                                      ? colorPalette.gray
                                      : "rgba(255, 255, 255, 0.2)", // Dynamic grid color
                                },
                              },
                            },
                          }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div
                style={{
                  display: "flex",
                  justifyContent: "center",
                  alignItems: "center",
                  height: "100%",
                }}
              >
                <h2>
                  {selectedServices.length === 0
                    ? "Select services from the sidebar to start comparing."
                    : "Select fields to compare the selected services."}
                </h2>
              </div>
            )}
          </div>
        </div>
      </div>
    </ThemeContext.Provider>
  );
}

export default ImprovedBenchmarkApp;

const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

function getAdjustedFileName(filePath) {
    const ignoredParts = new Set(['tests','results','backend', 'benchmark', 'benchmarks', 'benchmark_stats_history.csv']);
    const parts = filePath.split(path.sep).map(part => part.toLowerCase());
    // console.log(parts)
    // Find the index of the first 'backend' to ignore all preceding parts
    const backendIndex = parts.indexOf('backends');
    if (backendIndex === -1) return ''; // If 'backend' is not found, return an empty string
  
    const relevantParts = parts.slice(backendIndex + 1).filter(part => !ignoredParts.has(part));
  
    return relevantParts.join(' ').replace(/-/g, ' ');
  }
  
function readCSVFiles() {
  const directoryPath = path.join(__dirname, '../backends');
  const filePaths = [];

  function findFiles(dir) {
    const files = fs.readdirSync(dir);
    files.forEach(file => {
      const fullPath = path.join(dir, file);
      if (fs.statSync(fullPath).isDirectory()) {
        findFiles(fullPath);
      } else if (file === 'benchmark_stats_history.csv') {
        filePaths.push(fullPath);
      }
    });
  }

  findFiles(directoryPath);

  const data = {};

  filePaths.forEach(filePath => {
    const serviceName = getAdjustedFileName(filePath);
    const results = [];
    fs.createReadStream(filePath)
      .pipe(csv())
      .on('data', data => results.push(data))
      .on('end', () => {
        data[serviceName] = results;
        fs.writeFileSync(path.join(__dirname, 'public/data.json'), JSON.stringify(data, null, 2));
      });
  });
}

readCSVFiles();

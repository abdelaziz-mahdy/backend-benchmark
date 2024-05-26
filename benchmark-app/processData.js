const fs = require('fs');
const path = require('path');
const csv = require('csv-parser');

function getAdjustedFileName(filePath) {
  const ignoredParts = new Set(['tests', 'results', 'backend', 'benchmark', 'benchmarks', 'benchmark_stats_history.csv']);
  const parts = filePath.split(path.sep).map(part => part.toLowerCase());

  // Find the index of the first 'backends' to ignore all preceding parts
  const backendIndex = parts.indexOf('backends');
  if (backendIndex === -1) return ''; // If 'backends' is not found, return an empty string

  const relevantParts = parts.slice(backendIndex + 1).filter(part => !ignoredParts.has(part));

  return relevantParts.join(' ').replace(/-/g, ' ');
}

function readCSVFiles() {
  const directoryPath = path.join(__dirname, '../backends');
  const filePaths = [];

  function findFiles(dir) {
    const files = fs.readdirSync(dir);
    files.forEach(file => {
      try{
      const fullPath = path.join(dir, file);
      if (fs.statSync(fullPath).isDirectory()) {
        findFiles(fullPath);
      } else if (file === 'benchmark_stats_history.csv') {
        filePaths.push(fullPath);
      }}
      catch{
        
      }
    });
  }

  findFiles(directoryPath);

  const data = {};

  filePaths.forEach(filePath => {
    const serviceName = getAdjustedFileName(filePath);
    if (serviceName) {
      const results = [];
      fs.createReadStream(filePath)
        .pipe(csv())
        .on('data', row => results.push(row))
        .on('end', () => {
          data[serviceName] = results;

          // Sort the data object by keys
          const sortedData = Object.keys(data)
            .sort()
            .reduce((acc, key) => {
              acc[key] = data[key];
              return acc;
            }, {});

          fs.writeFileSync(path.join(__dirname, 'public/data.json'), JSON.stringify(sortedData, null, 0));
        });
    }
  });
}

readCSVFiles();

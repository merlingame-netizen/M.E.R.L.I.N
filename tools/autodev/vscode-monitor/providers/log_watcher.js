// log_watcher.js — Incremental log tracking via byte position
// Reads only new bytes since last read, avoiding full re-reads

const fs = require('fs');
const path = require('path');

class LogTracker {
  constructor() {
    this._positions = new Map(); // filePath -> byte position
    this._domainLogFiles = new Map(); // domain -> latest log file path
  }

  /**
   * Read only new lines since last read from a log file.
   * @param {string} filePath - Absolute path to log file
   * @returns {string[]} New lines (empty if no new content)
   */
  readNewLines(filePath) {
    const pos = this._positions.get(filePath) || 0;
    try {
      const stat = fs.statSync(filePath);

      // File was truncated/recreated — reset position and re-read from start
      if (stat.size < pos) {
        this._positions.set(filePath, 0);
        return this.readNewLines(filePath);
      }

      // No new content
      if (stat.size === pos) return [];

      const fd = fs.openSync(filePath, 'r');
      const buffer = Buffer.alloc(stat.size - pos);
      fs.readSync(fd, buffer, 0, buffer.length, pos);
      fs.closeSync(fd);

      this._positions.set(filePath, stat.size);
      return buffer.toString('utf8').split('\n').filter(l => l.trim());
    } catch {
      return [];
    }
  }

  /**
   * Find the most recent log file for a domain in the logs directory.
   * Pattern: {domain}_{WAVE}_{YYYYMMDD}_{HHMMSS}.log
   * Falls back to {domain}.log (legacy format)
   * @param {string} logsDir - Absolute path to logs directory
   * @param {string} domain - Domain name (e.g. "gameplay")
   * @returns {string | null} Path to the latest log file
   */
  findLatestLog(logsDir, domain) {
    try {
      if (!fs.existsSync(logsDir)) return null;

      const files = fs.readdirSync(logsDir)
        .filter(f => f.startsWith(domain) && f.endsWith('.log'))
        .sort()
        .reverse(); // Most recent first (timestamp in name)

      if (files.length === 0) return null;
      return path.join(logsDir, files[0]);
    } catch {
      return null;
    }
  }

  /**
   * Get the latest log file for a domain and read new lines.
   * Caches the log file path per domain and detects file rotation.
   * @param {string} logsDir
   * @param {string} domain
   * @returns {{ filePath: string | null, lines: string[] }}
   */
  getNewLinesForDomain(logsDir, domain) {
    const latestFile = this.findLatestLog(logsDir, domain);
    const cachedFile = this._domainLogFiles.get(domain);

    // Log file rotated — reset position for old file
    if (latestFile && cachedFile && latestFile !== cachedFile) {
      this._positions.delete(cachedFile);
    }

    if (latestFile) {
      this._domainLogFiles.set(domain, latestFile);
      const lines = this.readNewLines(latestFile);
      return { filePath: latestFile, lines };
    }

    return { filePath: null, lines: [] };
  }

  /**
   * Read initial tail of a log file (last N lines) for first load.
   * @param {string} filePath
   * @param {number} maxLines
   * @returns {string[]}
   */
  tailFile(filePath, maxLines) {
    try {
      if (!fs.existsSync(filePath)) return [];
      const content = fs.readFileSync(filePath, 'utf8');
      const lines = content.split('\n').filter(l => l.trim());

      // Set position to end of file so subsequent readNewLines returns only new content
      const stat = fs.statSync(filePath);
      this._positions.set(filePath, stat.size);

      return lines.slice(-maxLines);
    } catch {
      return [];
    }
  }

  /**
   * Reset tracking for a specific file.
   * @param {string} filePath
   */
  reset(filePath) {
    this._positions.delete(filePath);
  }

  /** Reset all tracking state. */
  resetAll() {
    this._positions.clear();
    this._domainLogFiles.clear();
  }
}

module.exports = { LogTracker };

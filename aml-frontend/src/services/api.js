import axios from 'axios';
import toast from 'react-hot-toast';

const API_BASE_URL = process.env.REACT_APP_API_URL || '/api/v1';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor for auth
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    } else if (error.response?.status === 500) {
      toast.error('Server error. Please try again later.');
    }
    return Promise.reject(error);
  }
);

// Transaction Monitoring APIs
export const transactionAPI = {
  processTransaction: (data) => api.post('/webhook/suspicious', data),
  getMonitoringStatus: () => api.get('/monitoring/status'),
  toggleMonitoring: (enable) => api.post(`/monitoring/toggle?enable=${enable}`),
};

// Suspicious Cases APIs
export const suspiciousCasesAPI = {
  getAll: (params) => api.get('/suspicious-cases', { params }),
  getById: (caseNumber) => api.get(`/suspicious-cases/${caseNumber}`),
  updateStatus: (caseNumber, status) => api.patch(`/suspicious-cases/${caseNumber}/status`, { status }),
};

// Customer Profiles APIs
export const customerProfilesAPI = {
  getByAccountNumber: (accountNumber) => api.get(`/profiles/${accountNumber}`),
};

// Watchlist APIs
export const watchlistAPI = {
  getAll: (params) => api.get('/watchlist', { params }),
  add: (data) => api.post('/watchlist', data),
  remove: (accountNumber) => api.delete(`/watchlist/${accountNumber}`),
};

// Exemptions APIs
export const exemptionsAPI = {
  getAll: (params) => api.get('/exemptions', { params }),
  add: (data) => api.post('/exemptions', data),
  remove: (accountNumber) => api.delete(`/exemptions/${accountNumber}`),
};

// Transaction Limits APIs
export const limitsAPI = {
  getAll: (params) => api.get('/limits', { params }),
  create: (data) => api.post('/limits', data),
};

// Health Check
export const healthAPI = {
  check: () => api.get('/health'),
};

// Authentication APIs
export const authAPI = {
  login: (email, password) => {
    const formData = new URLSearchParams();
    formData.append('username', email); // OAuth2 expects 'username' field
    formData.append('password', password);
    return api.post('/auth/login', formData, {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });
  },
  register: (data) => api.post('/auth/register', data),
  getMe: () => api.get('/auth/me'),
  logout: () => api.post('/auth/logout'),
  changePassword: (oldPassword, newPassword) => 
    api.post('/auth/change-password', { old_password: oldPassword, new_password: newPassword }),
};

// Statistics APIs
export const statisticsAPI = {
  getDashboard: (period = 'today') => api.get('/statistics/dashboard', { params: { period } }),
  getTransactionVolume: (days = 30, groupBy = 'day') => api.get('/statistics/transactions/volume', { params: { days, group_by: groupBy } }),
  getRiskDistribution: () => api.get('/statistics/risk/distribution'),
  getComplianceMetrics: (startDate, endDate) => api.get('/statistics/compliance/metrics', { params: { start_date: startDate, end_date: endDate } }),
  getGeographicDistribution: () => api.get('/statistics/geographic/distribution'),
  getPerformanceKPIs: () => api.get('/statistics/performance/kpis'),
};

export default api;
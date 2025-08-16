import axios from 'axios';
import toast from 'react-hot-toast';

// Determine API base URL based on environment
const getApiBaseUrl = () => {
  // Check if we have an environment variable set
  if (process.env.REACT_APP_API_URL) {
    return process.env.REACT_APP_API_URL;
  }
  
  // In production, use relative path to avoid CORS issues
  if (process.env.NODE_ENV === 'production') {
    return '/api/v1';
  }
  
  // Development default
  return 'http://localhost:50000/api/v1';
};

const API_BASE_URL = getApiBaseUrl();

// Create axios instance with default config
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 30000, // 30 second timeout
  withCredentials: true, // Include cookies for CORS requests
});

// Request interceptor for auth and logging
api.interceptors.request.use(
  (config) => {
    // Add auth token if available
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    
    // Log request in development
    if (process.env.NODE_ENV === 'development') {
      console.log(`[API Request] ${config.method?.toUpperCase()} ${config.url}`, config.data);
    }
    
    return config;
  },
  (error) => {
    console.error('[API Request Error]', error);
    return Promise.reject(error);
  }
);

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => {
    // Log response in development
    if (process.env.NODE_ENV === 'development') {
      console.log(`[API Response] ${response.config.method?.toUpperCase()} ${response.config.url}`, response.data);
    }
    return response;
  },
  async (error) => {
    const originalRequest = error.config;
    
    // Log error details
    console.error('[API Error]', {
      url: originalRequest?.url,
      method: originalRequest?.method,
      status: error.response?.status,
      data: error.response?.data,
      message: error.message,
    });
    
    // Handle network errors
    if (!error.response) {
      if (error.code === 'ECONNABORTED') {
        toast.error('Request timeout. Please check your connection and try again.');
      } else if (error.message === 'Network Error') {
        toast.error('Network error. Please check your internet connection.');
      } else {
        toast.error('Unable to connect to the server. Please try again later.');
      }
      return Promise.reject(error);
    }
    
    // Handle specific HTTP status codes
    switch (error.response.status) {
      case 401:
        // Unauthorized - clear token and redirect to login
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        
        // Only redirect if not already on login page
        if (!window.location.pathname.includes('/login')) {
          toast.error('Session expired. Please login again.');
          window.location.href = '/login';
        }
        break;
        
      case 403:
        toast.error('You do not have permission to perform this action.');
        break;
        
      case 404:
        // Don't show toast for 404s by default (let calling code handle it)
        break;
        
      case 422:
        // Validation error
        const validationErrors = error.response.data?.detail;
        if (Array.isArray(validationErrors)) {
          validationErrors.forEach(err => {
            toast.error(`${err.loc.join('.')}: ${err.msg}`);
          });
        } else {
          toast.error(error.response.data?.detail || 'Validation error. Please check your input.');
        }
        break;
        
      case 429:
        toast.error('Too many requests. Please slow down and try again.');
        break;
        
      case 500:
        toast.error('Server error. Our team has been notified. Please try again later.');
        break;
        
      case 502:
        toast.error('Bad gateway. The server is temporarily unavailable.');
        break;
        
      case 503:
        toast.error('Service unavailable. Please try again later.');
        break;
        
      default:
        // Generic error message
        const errorMessage = error.response.data?.detail || 
                           error.response.data?.message || 
                           'An unexpected error occurred. Please try again.';
        toast.error(errorMessage);
    }
    
    return Promise.reject(error);
  }
);

// Helper function to handle API calls with loading states
export const apiCall = async (apiFunction, loadingMessage = 'Loading...') => {
  const toastId = toast.loading(loadingMessage);
  try {
    const response = await apiFunction();
    toast.dismiss(toastId);
    return response;
  } catch (error) {
    toast.dismiss(toastId);
    throw error;
  }
};

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
  // Add retry logic for health checks
  checkWithRetry: async (maxRetries = 3, delay = 1000) => {
    for (let i = 0; i < maxRetries; i++) {
      try {
        const response = await api.get('/health');
        return response;
      } catch (error) {
        if (i === maxRetries - 1) throw error;
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  },
};

// Authentication APIs with enhanced error handling
export const authAPI = {
  login: async (email, password) => {
    try {
      const formData = new URLSearchParams();
      formData.append('username', email); // OAuth2 expects 'username' field
      formData.append('password', password);
      
      const response = await api.post('/auth/login', formData, {
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
      });
      
      // Store token on successful login
      if (response.data?.access_token) {
        localStorage.setItem('token', response.data.access_token);
      }
      
      return response;
    } catch (error) {
      // Don't show generic toast for login errors, let the component handle it
      if (error.response?.status === 401) {
        throw new Error('Invalid email or password');
      }
      throw error;
    }
  },
  
  register: (data) => api.post('/auth/register', data),
  
  getMe: () => api.get('/auth/me'),
  
  logout: async () => {
    try {
      const response = await api.post('/auth/logout');
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      return response;
    } catch (error) {
      // Even if logout fails on server, clear local storage
      localStorage.removeItem('token');
      localStorage.removeItem('user');
      throw error;
    }
  },
  
  changePassword: (oldPassword, newPassword) => 
    api.post('/auth/change-password', { old_password: oldPassword, new_password: newPassword }),
};

// Statistics APIs
export const statisticsAPI = {
  getDashboard: (period = 'today') => api.get('/statistics/dashboard', { params: { period } }),
  getTransactionVolume: (days = 30, groupBy = 'day') => 
    api.get('/statistics/transactions/volume', { params: { days, group_by: groupBy } }),
  getRiskDistribution: () => api.get('/statistics/risk/distribution'),
  getComplianceMetrics: (startDate, endDate) => 
    api.get('/statistics/compliance/metrics', { params: { start_date: startDate, end_date: endDate } }),
  getGeographicDistribution: () => api.get('/statistics/geographic/distribution'),
  getPerformanceKPIs: () => api.get('/statistics/performance/kpis'),
};

// Export the axios instance for direct use if needed
export default api;
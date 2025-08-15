import React, { useState, useEffect } from 'react';
import { ArrowUpIcon, ArrowDownIcon } from '@heroicons/react/20/solid';
import {
  CurrencyDollarIcon,
  ExclamationTriangleIcon,
  UserGroupIcon,
  ChartBarIcon,
  ClockIcon,
  ShieldCheckIcon,
  EyeIcon,
  BanknotesIcon,
} from '@heroicons/react/24/outline';
import { LineChart, Line, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { transactionAPI, suspiciousCasesAPI, watchlistAPI, exemptionsAPI, statisticsAPI } from '../services/api';
import toast from 'react-hot-toast';

const stats = [
  { name: 'Total Transactions', value: '24,589', change: '+12.5%', changeType: 'increase', icon: BanknotesIcon },
  { name: 'Suspicious Cases', value: '142', change: '+4.2%', changeType: 'increase', icon: ExclamationTriangleIcon },
  { name: 'Customer Profiles', value: '8,234', change: '+2.1%', changeType: 'increase', icon: UserGroupIcon },
  { name: 'Watchlist Entries', value: '89', change: '-1.3%', changeType: 'decrease', icon: EyeIcon },
];

const transactionData = [
  { date: 'Mon', transactions: 4000, flagged: 20 },
  { date: 'Tue', transactions: 3800, flagged: 18 },
  { date: 'Wed', transactions: 4200, flagged: 25 },
  { date: 'Thu', transactions: 4500, flagged: 30 },
  { date: 'Fri', transactions: 5000, flagged: 45 },
  { date: 'Sat', transactions: 3200, flagged: 15 },
  { date: 'Sun', transactions: 2800, flagged: 12 },
];

const riskDistribution = [
  { name: 'Low Risk', value: 45, color: '#10b981' },
  { name: 'Medium Risk', value: 30, color: '#f59e0b' },
  { name: 'High Risk', value: 20, color: '#ef4444' },
  { name: 'Critical', value: 5, color: '#7c3aed' },
];

const recentAlerts = [
  { id: 1, type: 'High Value', account: 'ACC-2024-0142', amount: '$125,000', time: '5 minutes ago', status: 'pending' },
  { id: 2, type: 'Unusual Pattern', account: 'ACC-2024-0089', amount: '$45,000', time: '12 minutes ago', status: 'reviewing' },
  { id: 3, type: 'Watchlist Match', account: 'ACC-2024-0234', amount: '$18,500', time: '25 minutes ago', status: 'escalated' },
  { id: 4, type: 'Rapid Movement', account: 'ACC-2024-0567', amount: '$89,000', time: '1 hour ago', status: 'pending' },
  { id: 5, type: 'Structuring', account: 'ACC-2024-0789', amount: '$9,800', time: '2 hours ago', status: 'reviewing' },
];

function classNames(...classes) {
  return classes.filter(Boolean).join(' ');
}

export default function Dashboard() {
  const [loading, setLoading] = useState(true);
  const [dashboardStats, setDashboardStats] = useState(stats);
  const [suspiciousCases, setSuspiciousCases] = useState([]);
  const [transactionTrends, setTransactionTrends] = useState(transactionData);
  const [riskData, setRiskData] = useState(riskDistribution);
  const [recentCases, setRecentCases] = useState(recentAlerts);
  const [performanceKPIs, setPerformanceKPIs] = useState(null);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);
      
      // Fetch dashboard statistics
      const statsRes = await statisticsAPI.getDashboard('today');
      const statsData = statsRes.data;
      
      // Fetch monitoring status
      const statusRes = await transactionAPI.getMonitoringStatus();
      
      // Fetch performance KPIs
      const kpisRes = await statisticsAPI.getPerformanceKPIs();
      setPerformanceKPIs(kpisRes.data);
      
      // Fetch transaction volume for trends
      const volumeRes = await statisticsAPI.getTransactionVolume(7, 'day');
      const volumeData = volumeRes.data.volume_over_time.map(item => ({
        date: new Date(item.period).toLocaleDateString('en-US', { weekday: 'short' }),
        transactions: item.transaction_count,
        flagged: Math.floor(item.transaction_count * 0.05) // Estimate flagged as 5%
      }));
      setTransactionTrends(volumeData.length > 0 ? volumeData : transactionData);
      
      // Fetch risk distribution
      const riskRes = await statisticsAPI.getRiskDistribution();
      if (riskRes.data.distribution && riskRes.data.distribution.length > 0) {
        const riskColors = {
          'Very Low': '#10b981',
          'Low': '#3b82f6',
          'Medium': '#f59e0b',
          'High': '#ef4444',
          'Critical': '#7c3aed'
        };
        const riskDist = riskRes.data.distribution.map(item => ({
          name: item.risk_level,
          value: item.customer_count,
          color: riskColors[item.risk_level] || '#6b7280'
        }));
        setRiskData(riskDist);
      }
      
      // Update stats with real data
      const updatedStats = [
        { 
          name: 'Total Transactions', 
          value: statsData.transactions.total_count.toLocaleString(), 
          change: `${statsData.trends.direction === 'up' ? '+' : ''}${statsData.trends.suspicious_cases_change}%`, 
          changeType: statsData.trends.direction === 'up' ? 'increase' : 'decrease', 
          icon: BanknotesIcon 
        },
        { 
          name: 'Suspicious Cases', 
          value: statsData.cases.total.toString(), 
          change: `${statsData.trends.direction === 'up' ? '+' : ''}${statsData.trends.suspicious_cases_change}%`, 
          changeType: statsData.trends.direction === 'up' ? 'increase' : 'decrease', 
          icon: ExclamationTriangleIcon 
        },
        { 
          name: 'Watchlist Entries', 
          value: statsData.watchlist.active_entries.toString(), 
          change: '+0%', 
          changeType: 'increase', 
          icon: EyeIcon 
        },
        { 
          name: 'Risk Score', 
          value: statsData.cases.average_risk_score.toFixed(1), 
          change: '+0%', 
          changeType: 'increase', 
          icon: ShieldCheckIcon 
        },
      ];
      
      setDashboardStats(updatedStats);
      
      // Fetch recent suspicious cases for alerts table
      const casesRes = await suspiciousCasesAPI.getAll({ limit: 5 });
      if (casesRes.data && Array.isArray(casesRes.data)) {
        const formattedCases = casesRes.data.map((caseItem, index) => ({
          id: index + 1,
          type: caseItem.alert_type || 'Suspicious Activity',
          account: caseItem.acct_no || 'Unknown',
          amount: `$${(caseItem.amount || 0).toLocaleString()}`,
          time: new Date(caseItem.created_at).toLocaleString(),
          status: caseItem.status || 'pending'
        }));
        setRecentCases(formattedCases);
      }
      
    } catch (error) {
      console.error('Failed to fetch dashboard data:', error);
      toast.error('Failed to load dashboard data. Using sample data.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Dashboard</h1>
        <p className="mt-1 text-sm text-gray-500">
          Real-time overview of AML monitoring activities and system status
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {dashboardStats.map((stat) => (
          <div key={stat.name} className="card p-5">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium text-gray-600">{stat.name}</p>
                <p className="mt-1 text-3xl font-semibold text-gray-900">{stat.value}</p>
                <div className="mt-2 flex items-center text-sm">
                  <span
                    className={classNames(
                      stat.changeType === 'increase' ? 'text-success-600' : 'text-danger-600',
                      'flex items-center font-medium'
                    )}
                  >
                    {stat.changeType === 'increase' ? (
                      <ArrowUpIcon className="h-4 w-4 mr-1" />
                    ) : (
                      <ArrowDownIcon className="h-4 w-4 mr-1" />
                    )}
                    {stat.change}
                  </span>
                  <span className="ml-2 text-gray-500">from yesterday</span>
                </div>
              </div>
              <div className="flex-shrink-0">
                <stat.icon className="h-12 w-12 text-gray-400" />
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 gap-5 lg:grid-cols-3">
        {/* Transaction Trends */}
        <div className="lg:col-span-2 card p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Transaction Trends</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={transactionTrends}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="date" stroke="#6b7280" />
              <YAxis stroke="#6b7280" />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="transactions" stroke="#3b82f6" strokeWidth={2} name="Total Transactions" />
              <Line type="monotone" dataKey="flagged" stroke="#ef4444" strokeWidth={2} name="Flagged" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Risk Distribution */}
        <div className="card p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Risk Distribution</h3>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={riskData}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={100}
                paddingAngle={5}
                dataKey="value"
              >
                {riskData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Recent Alerts Table */}
      <div className="card">
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center justify-between">
            <h3 className="text-lg font-medium text-gray-900">Recent Alerts</h3>
            <button className="text-sm text-primary-600 hover:text-primary-700 font-medium">
              View all alerts →
            </button>
          </div>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Account
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Time
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="relative px-6 py-3">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {recentCases.map((alert) => (
                <tr key={alert.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {alert.type}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {alert.account}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 font-medium">
                    {alert.amount}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    <div className="flex items-center">
                      <ClockIcon className="h-4 w-4 mr-1 text-gray-400" />
                      {alert.time}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={classNames(
                      alert.status === 'pending' && 'bg-yellow-100 text-yellow-800',
                      alert.status === 'reviewing' && 'bg-blue-100 text-blue-800',
                      alert.status === 'escalated' && 'bg-red-100 text-red-800',
                      'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium'
                    )}>
                      {alert.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    <button className="text-primary-600 hover:text-primary-900">
                      Review
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Quick Stats Row */}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        <div className="card p-4">
          <div className="flex items-center">
            <div className="flex-shrink-0 p-3 bg-primary-100 rounded-lg">
              <ChartBarIcon className="h-6 w-6 text-primary-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-500">Today's Transactions</p>
              <p className="text-2xl font-semibold text-gray-900">
                {performanceKPIs?.real_time_metrics?.transactions_today || 0}
              </p>
            </div>
          </div>
        </div>
        
        <div className="card p-4">
          <div className="flex items-center">
            <div className="flex-shrink-0 p-3 bg-success-100 rounded-lg">
              <ShieldCheckIcon className="h-6 w-6 text-success-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-500">System Health</p>
              <p className="text-2xl font-semibold text-gray-900">
                {performanceKPIs?.system_health?.api_uptime || '99.9%'}
              </p>
            </div>
          </div>
        </div>
        
        <div className="card p-4">
          <div className="flex items-center">
            <div className="flex-shrink-0 p-3 bg-yellow-100 rounded-lg">
              <ClockIcon className="h-6 w-6 text-yellow-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-500">Cases Today</p>
              <p className="text-2xl font-semibold text-gray-900">
                {performanceKPIs?.real_time_metrics?.cases_today || 0}
              </p>
            </div>
          </div>
        </div>
        
        <div className="card p-4">
          <div className="flex items-center">
            <div className="flex-shrink-0 p-3 bg-purple-100 rounded-lg">
              <CurrencyDollarIcon className="h-6 w-6 text-purple-600" />
            </div>
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-500">STRs This Month</p>
              <p className="text-2xl font-semibold text-gray-900">
                {performanceKPIs?.monthly_kpis?.strs_filed || 0}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
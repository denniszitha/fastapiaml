import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { reportsAPI } from '../services/api';
import toast from 'react-hot-toast';
import {
  DocumentTextIcon,
  ChartBarIcon,
  ArrowDownTrayIcon,
  CalendarIcon,
  FunnelIcon,
  ClockIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon,
  DocumentArrowDownIcon,
  PresentationChartBarIcon,
  TableCellsIcon,
  DocumentChartBarIcon,
  PrinterIcon,
  EnvelopeIcon,
} from '@heroicons/react/24/outline';
import { LineChart, Line, BarChart, Bar, PieChart, Pie, Cell, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

const reportTypes = [
  {
    id: 'str',
    name: 'Suspicious Transaction Report (STR)',
    description: 'Generate STR for regulatory submission',
    icon: ExclamationTriangleIcon,
    color: 'text-red-600',
    bgColor: 'bg-red-100',
  },
  {
    id: 'monthly',
    name: 'Monthly Activity Report',
    description: 'Comprehensive monthly transaction analysis',
    icon: ChartBarIcon,
    color: 'text-blue-600',
    bgColor: 'bg-blue-100',
  },
  {
    id: 'risk',
    name: 'Risk Assessment Report',
    description: 'Customer risk profile analysis',
    icon: DocumentChartBarIcon,
    color: 'text-yellow-600',
    bgColor: 'bg-yellow-100',
  },
  {
    id: 'compliance',
    name: 'Compliance Summary',
    description: 'Regulatory compliance status overview',
    icon: CheckCircleIcon,
    color: 'text-green-600',
    bgColor: 'bg-green-100',
  },
  {
    id: 'watchlist',
    name: 'Watchlist Activity',
    description: 'Watchlisted accounts transaction summary',
    icon: DocumentTextIcon,
    color: 'text-purple-600',
    bgColor: 'bg-purple-100',
  },
  {
    id: 'audit',
    name: 'Audit Trail Report',
    description: 'System activity and user actions log',
    icon: TableCellsIcon,
    color: 'text-gray-600',
    bgColor: 'bg-gray-100',
  },
];

export default function Reports() {
  const [selectedReport, setSelectedReport] = useState(null);
  const [dateRange, setDateRange] = useState({
    start: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    end: new Date().toISOString().split('T')[0],
  });
  const [filters, setFilters] = useState({
    branch: 'all',
    riskLevel: 'all',
    status: 'all',
  });

  // Mock data for charts
  const transactionTrend = [
    { date: 'Jan 1', transactions: 450, flagged: 12 },
    { date: 'Jan 5', transactions: 520, flagged: 18 },
    { date: 'Jan 10', transactions: 480, flagged: 15 },
    { date: 'Jan 15', transactions: 610, flagged: 25 },
    { date: 'Jan 20', transactions: 550, flagged: 20 },
    { date: 'Jan 25', transactions: 590, flagged: 22 },
    { date: 'Jan 30', transactions: 625, flagged: 28 },
  ];

  const riskDistribution = [
    { name: 'Low Risk', value: 2450, color: '#10b981' },
    { name: 'Medium Risk', value: 1200, color: '#f59e0b' },
    { name: 'High Risk', value: 450, color: '#ef4444' },
    { name: 'Critical', value: 85, color: '#7c3aed' },
  ];

  const channelBreakdown = [
    { channel: 'Cash', amount: 1250000, count: 450 },
    { channel: 'Transfer', amount: 3200000, count: 820 },
    { channel: 'Wire', amount: 5500000, count: 340 },
    { channel: 'Card', amount: 890000, count: 1250 },
    { channel: 'Mobile', amount: 450000, count: 680 },
  ];

  // Mock recent reports
  const recentReports = [
    {
      id: 1,
      type: 'STR',
      name: 'STR-2024-001',
      date: '2024-01-15',
      status: 'submitted',
      generatedBy: 'John Doe',
    },
    {
      id: 2,
      type: 'Monthly',
      name: 'December 2023 Activity Report',
      date: '2024-01-01',
      status: 'completed',
      generatedBy: 'System',
    },
    {
      id: 3,
      type: 'Risk',
      name: 'Q4 2023 Risk Assessment',
      date: '2024-01-05',
      status: 'completed',
      generatedBy: 'Jane Smith',
    },
    {
      id: 4,
      type: 'Compliance',
      name: 'Weekly Compliance Summary',
      date: '2024-01-14',
      status: 'draft',
      generatedBy: 'Mike Johnson',
    },
  ];

  const handleGenerateReport = (reportType) => {
    setSelectedReport(reportType);
    toast.success(`Generating ${reportType.name}...`);
    // In production, this would call the API to generate the report
    setTimeout(() => {
      toast.success('Report generated successfully');
    }, 2000);
  };

  const handleExport = (format) => {
    toast.success(`Exporting report as ${format.toUpperCase()}...`);
    // In production, this would trigger actual export
  };

  const handleScheduleReport = () => {
    toast.success('Report scheduled successfully');
  };

  const getStatusBadge = (status) => {
    const badges = {
      submitted: 'bg-green-100 text-green-800',
      completed: 'bg-blue-100 text-blue-800',
      draft: 'bg-yellow-100 text-yellow-800',
      failed: 'bg-red-100 text-red-800',
    };
    return badges[status] || 'bg-gray-100 text-gray-800';
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Reports & Analytics</h1>
          <p className="mt-1 text-sm text-gray-500">
            Generate compliance reports and analyze transaction patterns
          </p>
        </div>
        <div className="mt-4 sm:mt-0 space-x-3">
          <button
            onClick={handleScheduleReport}
            className="btn btn-secondary"
          >
            <ClockIcon className="h-4 w-4 mr-2" />
            Schedule Report
          </button>
        </div>
      </div>

      {/* Date Range and Filters */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
          <div>
            <label className="label">Start Date</label>
            <input
              type="date"
              value={dateRange.start}
              onChange={(e) => setDateRange({ ...dateRange, start: e.target.value })}
              className="input"
            />
          </div>
          <div>
            <label className="label">End Date</label>
            <input
              type="date"
              value={dateRange.end}
              onChange={(e) => setDateRange({ ...dateRange, end: e.target.value })}
              className="input"
            />
          </div>
          <div>
            <label className="label">Branch</label>
            <select
              value={filters.branch}
              onChange={(e) => setFilters({ ...filters, branch: e.target.value })}
              className="input"
            >
              <option value="all">All Branches</option>
              <option value="main">Main Branch</option>
              <option value="west">West Branch</option>
              <option value="east">East Branch</option>
            </select>
          </div>
          <div>
            <label className="label">Risk Level</label>
            <select
              value={filters.riskLevel}
              onChange={(e) => setFilters({ ...filters, riskLevel: e.target.value })}
              className="input"
            >
              <option value="all">All Levels</option>
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
              <option value="critical">Critical</option>
            </select>
          </div>
        </div>
      </div>

      {/* Report Types Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {reportTypes.map((report) => {
          const Icon = report.icon;
          return (
            <div
              key={report.id}
              className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow cursor-pointer"
              onClick={() => handleGenerateReport(report)}
            >
              <div className="flex items-center">
                <div className={`p-3 rounded-lg ${report.bgColor} mr-4`}>
                  <Icon className={`h-6 w-6 ${report.color}`} />
                </div>
                <div className="flex-1">
                  <h3 className="text-lg font-medium text-gray-900">{report.name}</h3>
                  <p className="text-sm text-gray-500 mt-1">{report.description}</p>
                </div>
              </div>
              <div className="mt-4 flex justify-end">
                <button className="text-sm text-primary-600 hover:text-primary-900 font-medium">
                  Generate →
                </button>
              </div>
            </div>
          );
        })}
      </div>

      {/* Analytics Dashboard */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Transaction Trend */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Transaction Trend</h3>
          <ResponsiveContainer width="100%" height={250}>
            <LineChart data={transactionTrend}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="date" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Line type="monotone" dataKey="transactions" stroke="#3b82f6" strokeWidth={2} name="Total" />
              <Line type="monotone" dataKey="flagged" stroke="#ef4444" strokeWidth={2} name="Flagged" />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Risk Distribution */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Risk Distribution</h3>
          <ResponsiveContainer width="100%" height={250}>
            <PieChart>
              <Pie
                data={riskDistribution}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={80}
                paddingAngle={5}
                dataKey="value"
              >
                {riskDistribution.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Channel Breakdown */}
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6 lg:col-span-2">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Channel Activity</h3>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={channelBreakdown}>
              <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
              <XAxis dataKey="channel" />
              <YAxis />
              <Tooltip />
              <Legend />
              <Bar dataKey="amount" fill="#3b82f6" name="Amount ($)" />
              <Bar dataKey="count" fill="#10b981" name="Count" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Recent Reports */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div className="px-6 py-4 bg-gray-50 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Recent Reports</h3>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Report Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Generated Date
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Generated By
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {recentReports.map((report) => (
                <tr key={report.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <DocumentTextIcon className="h-5 w-5 text-gray-400 mr-2" />
                      <span className="text-sm font-medium text-gray-900">{report.name}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-sm text-gray-900">{report.type}</span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center text-sm text-gray-500">
                      <CalendarIcon className="h-4 w-4 mr-1 text-gray-400" />
                      {report.date}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="text-sm text-gray-900">{report.generatedBy}</span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${getStatusBadge(report.status)}`}>
                      {report.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center space-x-3">
                      <button
                        onClick={() => handleExport('pdf')}
                        className="text-gray-400 hover:text-gray-600"
                        title="Download PDF"
                      >
                        <ArrowDownTrayIcon className="h-5 w-5" />
                      </button>
                      <button
                        className="text-gray-400 hover:text-gray-600"
                        title="Print"
                      >
                        <PrinterIcon className="h-5 w-5" />
                      </button>
                      <button
                        className="text-gray-400 hover:text-gray-600"
                        title="Email"
                      >
                        <EnvelopeIcon className="h-5 w-5" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Export Options */}
      {selectedReport && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75" onClick={() => setSelectedReport(null)} />
            
            <div className="relative bg-white rounded-lg max-w-lg w-full p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">
                Export {selectedReport.name}
              </h3>
              
              <div className="space-y-4">
                <p className="text-sm text-gray-500">
                  Choose export format for your report:
                </p>
                
                <div className="grid grid-cols-2 gap-3">
                  <button
                    onClick={() => handleExport('pdf')}
                    className="flex items-center justify-center px-4 py-3 border border-gray-300 rounded-lg hover:bg-gray-50"
                  >
                    <DocumentArrowDownIcon className="h-5 w-5 text-red-600 mr-2" />
                    <span className="text-sm font-medium">PDF</span>
                  </button>
                  <button
                    onClick={() => handleExport('excel')}
                    className="flex items-center justify-center px-4 py-3 border border-gray-300 rounded-lg hover:bg-gray-50"
                  >
                    <TableCellsIcon className="h-5 w-5 text-green-600 mr-2" />
                    <span className="text-sm font-medium">Excel</span>
                  </button>
                  <button
                    onClick={() => handleExport('csv')}
                    className="flex items-center justify-center px-4 py-3 border border-gray-300 rounded-lg hover:bg-gray-50"
                  >
                    <DocumentTextIcon className="h-5 w-5 text-blue-600 mr-2" />
                    <span className="text-sm font-medium">CSV</span>
                  </button>
                  <button
                    onClick={() => handleExport('json')}
                    className="flex items-center justify-center px-4 py-3 border border-gray-300 rounded-lg hover:bg-gray-50"
                  >
                    <DocumentChartBarIcon className="h-5 w-5 text-purple-600 mr-2" />
                    <span className="text-sm font-medium">JSON</span>
                  </button>
                </div>
                
                <div className="flex justify-end space-x-3 mt-6">
                  <button
                    onClick={() => setSelectedReport(null)}
                    className="btn btn-secondary"
                  >
                    Cancel
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
import React, { useState, useEffect } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import { transactionAPI } from '../services/api';
import toast from 'react-hot-toast';
import {
  PlayIcon,
  PauseIcon,
  ArrowPathIcon,
  FunnelIcon,
  BellIcon,
  ChartBarIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon,
  XCircleIcon,
  ClockIcon,
  CurrencyDollarIcon,
  ArrowTrendingUpIcon,
  ArrowTrendingDownIcon,
} from '@heroicons/react/24/outline';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

export default function TransactionMonitoring() {
  const [isMonitoring, setIsMonitoring] = useState(true);
  const [filter, setFilter] = useState('all');
  const [selectedTransaction, setSelectedTransaction] = useState(null);
  const [realtimeData, setRealtimeData] = useState([]);
  const [stats, setStats] = useState({
    total: 0,
    flagged: 0,
    clean: 0,
    processing: 0,
  });

  // Fetch monitoring status
  const { data: monitoringStatus, refetch: refetchStatus } = useQuery({
    queryKey: ['monitoring-status'],
    queryFn: transactionAPI.getMonitoringStatus,
  });

  // Toggle monitoring mutation
  const toggleMutation = useMutation({
    mutationFn: (enable) => transactionAPI.toggleMonitoring(enable),
    onSuccess: () => {
      toast.success(`Monitoring ${isMonitoring ? 'disabled' : 'enabled'}`);
      setIsMonitoring(!isMonitoring);
      refetchStatus();
    },
    onError: () => {
      toast.error('Failed to toggle monitoring');
    },
  });

  // Simulate real-time transactions
  useEffect(() => {
    if (!isMonitoring) return;

    const interval = setInterval(() => {
      const newTransaction = generateMockTransaction();
      setRealtimeData(prev => [newTransaction, ...prev].slice(0, 100));
      
      // Update stats
      setStats(prev => ({
        total: prev.total + 1,
        flagged: newTransaction.status === 'flagged' ? prev.flagged + 1 : prev.flagged,
        clean: newTransaction.status === 'clean' ? prev.clean + 1 : prev.clean,
        processing: Math.floor(Math.random() * 10) + 5,
      }));
    }, 2000);

    return () => clearInterval(interval);
  }, [isMonitoring]);

  const generateMockTransaction = () => {
    const statuses = ['clean', 'flagged', 'reviewing'];
    const channels = ['CASH', 'TRANSFER', 'WIRE', 'ONLINE'];
    const riskLevels = ['low', 'medium', 'high', 'critical'];
    
    return {
      id: `TXN-${Date.now()}`,
      account: `ACC-${Math.floor(Math.random() * 10000)}`,
      amount: Math.floor(Math.random() * 100000),
      currency: 'USD',
      channel: channels[Math.floor(Math.random() * channels.length)],
      status: statuses[Math.floor(Math.random() * statuses.length)],
      riskScore: Math.floor(Math.random() * 100),
      riskLevel: riskLevels[Math.floor(Math.random() * riskLevels.length)],
      timestamp: new Date().toISOString(),
      merchant: `Merchant ${Math.floor(Math.random() * 100)}`,
    };
  };

  const filteredTransactions = realtimeData.filter(tx => {
    if (filter === 'all') return true;
    if (filter === 'flagged') return tx.status === 'flagged';
    if (filter === 'high-risk') return tx.riskScore > 70;
    if (filter === 'large') return tx.amount > 50000;
    return true;
  });

  // Chart data preparation
  const chartData = realtimeData.slice(0, 20).reverse().map((tx, index) => ({
    time: index,
    riskScore: tx.riskScore,
    amount: tx.amount / 1000,
  }));

  const handleProcessTransaction = async (transaction) => {
    try {
      const payload = {
        case_number: `CASE-${Date.now()}`,
        compliance_category: 'Real-time Monitoring',
        current_transaction: {
          acct_no: transaction.account,
          acct_name: `Account Holder ${transaction.account}`,
          tran_id: transaction.id,
          tran_amt: transaction.amount,
          tran_date: transaction.timestamp,
          tran_crncy_code: transaction.currency,
          dr_cr_indicator: transaction.amount > 0 ? 'CR' : 'DR',
          // Add other required fields with defaults
          branch: 'MAIN',
          address_line: 'Address',
          country: 'US',
          mobile_no: '1234567890',
          nrc_no: 'NRC123',
          tran_particular: transaction.merchant,
          // Limit fields
          a_cash_excp_amt_lim: 100000,
          a_clg_excp_amt_lim: 100000,
          a_xfer_excp_amt_lim: 100000,
          a_cash_cr_excp_amt_lim: 100000,
          a_clg_cr_excp_amt_lim: 100000,
          a_xfer_cr_excp_amt_lim: 100000,
          s_cash_abnrml_amt_lim: 50000,
          s_clg_abnrml_amt_lim: 50000,
          s_xfer_abnrml_amt_lim: 50000,
          s_cash_dr_lim: 50000,
          s_xfer_dr_lim: 50000,
          s_clg_dr_lim: 50000,
          s_cash_cr_lim: 50000,
          s_xfer_cr_lim: 50000,
          s_clg_cr_lim: 50000,
          s_cash_dr_abnrml_lim: 25000,
          s_clg_dr_abnrml_lim: 25000,
          s_xfer_dr_abnrml_lim: 25000,
          s_new_acct_abnrml_tran_amt: 10000,
        },
        perm: localStorage.getItem('webhook_token') || 'test-token',
      };

      await transactionAPI.processTransaction(payload);
      toast.success('Transaction processed for review');
    } catch (error) {
      toast.error('Failed to process transaction');
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Transaction Monitoring</h1>
          <p className="mt-1 text-sm text-gray-500">
            Real-time transaction monitoring and analysis
          </p>
        </div>
        <div className="flex items-center space-x-3">
          <button
            onClick={() => toggleMutation.mutate(!isMonitoring)}
            className={`btn ${isMonitoring ? 'btn-danger' : 'btn-primary'}`}
          >
            {isMonitoring ? (
              <>
                <PauseIcon className="h-4 w-4 mr-2" />
                Stop Monitoring
              </>
            ) : (
              <>
                <PlayIcon className="h-4 w-4 mr-2" />
                Start Monitoring
              </>
            )}
          </button>
          <button className="btn btn-secondary">
            <ArrowPathIcon className="h-4 w-4 mr-2" />
            Refresh
          </button>
        </div>
      </div>

      {/* Monitoring Status */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center">
            <div className={`h-3 w-3 rounded-full ${isMonitoring ? 'bg-green-500' : 'bg-gray-400'} mr-3`}>
              {isMonitoring && (
                <div className="h-3 w-3 rounded-full bg-green-500 animate-ping" />
              )}
            </div>
            <span className="text-sm font-medium text-gray-900">
              Monitoring Status: {isMonitoring ? 'Active' : 'Inactive'}
            </span>
          </div>
          <div className="flex items-center space-x-6 text-sm">
            <div className="flex items-center">
              <ClockIcon className="h-4 w-4 text-gray-400 mr-1" />
              <span className="text-gray-600">Update Interval: 2s</span>
            </div>
            <div className="flex items-center">
              <BellIcon className="h-4 w-4 text-gray-400 mr-1" />
              <span className="text-gray-600">Alerts Enabled</span>
            </div>
          </div>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Transactions</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.total}</p>
            </div>
            <ChartBarIcon className="h-8 w-8 text-blue-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Flagged</p>
              <p className="text-2xl font-semibold text-red-600">{stats.flagged}</p>
            </div>
            <ExclamationTriangleIcon className="h-8 w-8 text-red-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Clean</p>
              <p className="text-2xl font-semibold text-green-600">{stats.clean}</p>
            </div>
            <CheckCircleIcon className="h-8 w-8 text-green-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Processing</p>
              <p className="text-2xl font-semibold text-yellow-600">{stats.processing}</p>
            </div>
            <ClockIcon className="h-8 w-8 text-yellow-500" />
          </div>
        </div>
      </div>

      {/* Risk Trend Chart */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Risk Score Trend</h3>
        <ResponsiveContainer width="100%" height={200}>
          <LineChart data={chartData}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
            <XAxis dataKey="time" />
            <YAxis />
            <Tooltip />
            <Line type="monotone" dataKey="riskScore" stroke="#ef4444" strokeWidth={2} name="Risk Score" />
            <Line type="monotone" dataKey="amount" stroke="#3b82f6" strokeWidth={2} name="Amount (K)" />
          </LineChart>
        </ResponsiveContainer>
      </div>

      {/* Filters */}
      <div className="flex items-center space-x-4">
        <FunnelIcon className="h-5 w-5 text-gray-400" />
        <select
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          className="input"
        >
          <option value="all">All Transactions</option>
          <option value="flagged">Flagged Only</option>
          <option value="high-risk">High Risk (70+)</option>
          <option value="large">Large Amounts (50K+)</option>
        </select>
        <span className="text-sm text-gray-500">
          Showing {filteredTransactions.length} transactions
        </span>
      </div>

      {/* Transactions Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Transaction ID
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Account
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Channel
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Risk Score
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Time
                </th>
                <th className="relative px-6 py-3">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {filteredTransactions.map((tx) => (
                <tr key={tx.id} className="hover:bg-gray-50">
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                    {tx.id}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {tx.account}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center text-sm font-medium text-gray-900">
                      <CurrencyDollarIcon className="h-4 w-4 text-gray-400 mr-1" />
                      {tx.amount.toLocaleString()}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      {tx.channel}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="w-16 bg-gray-200 rounded-full h-2 mr-2">
                        <div
                          className={`h-2 rounded-full ${
                            tx.riskScore > 70 ? 'bg-red-500' :
                            tx.riskScore > 40 ? 'bg-yellow-500' : 'bg-green-500'
                          }`}
                          style={{ width: `${tx.riskScore}%` }}
                        />
                      </div>
                      <span className="text-sm text-gray-900">{tx.riskScore}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                      tx.status === 'flagged' ? 'bg-red-100 text-red-800' :
                      tx.status === 'reviewing' ? 'bg-yellow-100 text-yellow-800' :
                      'bg-green-100 text-green-800'
                    }`}>
                      {tx.status}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                    {new Date(tx.timestamp).toLocaleTimeString()}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                    {tx.status === 'flagged' && (
                      <button
                        onClick={() => handleProcessTransaction(tx)}
                        className="text-primary-600 hover:text-primary-900"
                      >
                        Review
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
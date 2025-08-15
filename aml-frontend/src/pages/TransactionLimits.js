import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { limitsAPI } from '../services/api';
import toast from 'react-hot-toast';
import {
  AdjustmentsHorizontalIcon,
  CurrencyDollarIcon,
  ArrowPathIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon,
  InformationCircleIcon,
  BanknotesIcon,
  CreditCardIcon,
  ArrowsRightLeftIcon,
  DevicePhoneMobileIcon,
  GlobeAltIcon,
} from '@heroicons/react/24/outline';

const channelIcons = {
  cash: BanknotesIcon,
  transfer: ArrowsRightLeftIcon,
  wire: GlobeAltIcon,
  card: CreditCardIcon,
  mobile: DevicePhoneMobileIcon,
};

const channelColors = {
  cash: 'text-green-600',
  transfer: 'text-blue-600',
  wire: 'text-purple-600',
  card: 'text-orange-600',
  mobile: 'text-pink-600',
};

export default function TransactionLimits() {
  const [selectedChannel, setSelectedChannel] = useState('all');
  const [editMode, setEditMode] = useState(false);
  const queryClient = useQueryClient();

  // Mock data for limits
  const [limits, setLimits] = useState({
    cash: {
      daily: {
        single: 10000,
        cumulative: 50000,
        threshold: 8000,
      },
      weekly: {
        single: 50000,
        cumulative: 200000,
        threshold: 40000,
      },
      monthly: {
        single: 100000,
        cumulative: 500000,
        threshold: 80000,
      },
    },
    transfer: {
      daily: {
        single: 25000,
        cumulative: 100000,
        threshold: 20000,
      },
      weekly: {
        single: 100000,
        cumulative: 400000,
        threshold: 80000,
      },
      monthly: {
        single: 250000,
        cumulative: 1000000,
        threshold: 200000,
      },
    },
    wire: {
      daily: {
        single: 50000,
        cumulative: 200000,
        threshold: 40000,
      },
      weekly: {
        single: 200000,
        cumulative: 800000,
        threshold: 160000,
      },
      monthly: {
        single: 500000,
        cumulative: 2000000,
        threshold: 400000,
      },
    },
    card: {
      daily: {
        single: 5000,
        cumulative: 25000,
        threshold: 4000,
      },
      weekly: {
        single: 25000,
        cumulative: 100000,
        threshold: 20000,
      },
      monthly: {
        single: 50000,
        cumulative: 250000,
        threshold: 40000,
      },
    },
    mobile: {
      daily: {
        single: 2000,
        cumulative: 10000,
        threshold: 1500,
      },
      weekly: {
        single: 10000,
        cumulative: 40000,
        threshold: 8000,
      },
      monthly: {
        single: 20000,
        cumulative: 100000,
        threshold: 16000,
      },
    },
  });

  const [tempLimits, setTempLimits] = useState(limits);

  const handleSave = () => {
    // In production, this would call the API
    setLimits(tempLimits);
    setEditMode(false);
    toast.success('Transaction limits updated successfully');
  };

  const handleCancel = () => {
    setTempLimits(limits);
    setEditMode(false);
  };

  const handleReset = () => {
    const defaultLimits = {
      cash: {
        daily: { single: 10000, cumulative: 50000, threshold: 8000 },
        weekly: { single: 50000, cumulative: 200000, threshold: 40000 },
        monthly: { single: 100000, cumulative: 500000, threshold: 80000 },
      },
      transfer: {
        daily: { single: 25000, cumulative: 100000, threshold: 20000 },
        weekly: { single: 100000, cumulative: 400000, threshold: 80000 },
        monthly: { single: 250000, cumulative: 1000000, threshold: 200000 },
      },
      wire: {
        daily: { single: 50000, cumulative: 200000, threshold: 40000 },
        weekly: { single: 200000, cumulative: 800000, threshold: 160000 },
        monthly: { single: 500000, cumulative: 2000000, threshold: 400000 },
      },
      card: {
        daily: { single: 5000, cumulative: 25000, threshold: 4000 },
        weekly: { single: 25000, cumulative: 100000, threshold: 20000 },
        monthly: { single: 50000, cumulative: 250000, threshold: 40000 },
      },
      mobile: {
        daily: { single: 2000, cumulative: 10000, threshold: 1500 },
        weekly: { single: 10000, cumulative: 40000, threshold: 8000 },
        monthly: { single: 20000, cumulative: 100000, threshold: 16000 },
      },
    };
    setTempLimits(defaultLimits);
    toast.success('Limits reset to defaults');
  };

  const updateLimit = (channel, period, type, value) => {
    setTempLimits(prev => ({
      ...prev,
      [channel]: {
        ...prev[channel],
        [period]: {
          ...prev[channel][period],
          [type]: parseInt(value) || 0,
        },
      },
    }));
  };

  const channels = ['cash', 'transfer', 'wire', 'card', 'mobile'];
  const periods = ['daily', 'weekly', 'monthly'];
  const displayChannel = selectedChannel === 'all' ? channels : [selectedChannel];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Transaction Limits</h1>
          <p className="mt-1 text-sm text-gray-500">
            Configure monitoring thresholds and transaction limits by channel
          </p>
        </div>
        <div className="mt-4 sm:mt-0 space-x-3">
          {editMode ? (
            <>
              <button
                onClick={handleCancel}
                className="btn btn-secondary"
              >
                Cancel
              </button>
              <button
                onClick={handleReset}
                className="btn btn-secondary"
              >
                <ArrowPathIcon className="h-4 w-4 mr-2" />
                Reset to Defaults
              </button>
              <button
                onClick={handleSave}
                className="btn btn-primary"
              >
                <CheckCircleIcon className="h-4 w-4 mr-2" />
                Save Changes
              </button>
            </>
          ) : (
            <button
              onClick={() => setEditMode(true)}
              className="btn btn-primary"
            >
              <AdjustmentsHorizontalIcon className="h-4 w-4 mr-2" />
              Edit Limits
            </button>
          )}
        </div>
      </div>

      {/* Info Alert */}
      <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
        <div className="flex">
          <InformationCircleIcon className="h-5 w-5 text-blue-400 mt-0.5" />
          <div className="ml-3">
            <h3 className="text-sm font-medium text-blue-800">How Transaction Limits Work</h3>
            <div className="mt-2 text-sm text-blue-700">
              <ul className="list-disc pl-5 space-y-1">
                <li><strong>Single Transaction Limit:</strong> Maximum amount allowed for a single transaction</li>
                <li><strong>Cumulative Limit:</strong> Maximum total amount allowed within the time period</li>
                <li><strong>Alert Threshold:</strong> Amount that triggers monitoring alerts (typically 80% of limit)</li>
              </ul>
            </div>
          </div>
        </div>
      </div>

      {/* Channel Filter */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
        <div className="flex items-center space-x-4">
          <label className="text-sm font-medium text-gray-700">Channel:</label>
          <select
            value={selectedChannel}
            onChange={(e) => setSelectedChannel(e.target.value)}
            className="input"
          >
            <option value="all">All Channels</option>
            <option value="cash">Cash</option>
            <option value="transfer">Transfer</option>
            <option value="wire">Wire</option>
            <option value="card">Card</option>
            <option value="mobile">Mobile</option>
          </select>
        </div>
      </div>

      {/* Limits Tables */}
      {displayChannel.map(channel => {
        const Icon = channelIcons[channel];
        const colorClass = channelColors[channel];
        
        return (
          <div key={channel} className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
            <div className="px-6 py-4 bg-gray-50 border-b border-gray-200">
              <div className="flex items-center">
                <Icon className={`h-6 w-6 ${colorClass} mr-3`} />
                <h3 className="text-lg font-medium text-gray-900 capitalize">
                  {channel} Transaction Limits
                </h3>
              </div>
            </div>
            
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Period
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Single Transaction Limit
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Cumulative Limit
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Alert Threshold
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {periods.map(period => {
                    const periodLimits = editMode ? tempLimits[channel][period] : limits[channel][period];
                    const isNearThreshold = periodLimits.threshold >= periodLimits.single * 0.8;
                    
                    return (
                      <tr key={period} className="hover:bg-gray-50">
                        <td className="px-6 py-4 whitespace-nowrap">
                          <span className="text-sm font-medium text-gray-900 capitalize">
                            {period}
                          </span>
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {editMode ? (
                            <div className="flex items-center">
                              <span className="text-gray-500 mr-2">$</span>
                              <input
                                type="number"
                                value={periodLimits.single}
                                onChange={(e) => updateLimit(channel, period, 'single', e.target.value)}
                                className="input w-32"
                              />
                            </div>
                          ) : (
                            <div className="flex items-center text-sm text-gray-900">
                              <CurrencyDollarIcon className="h-4 w-4 text-gray-400 mr-1" />
                              {periodLimits.single.toLocaleString()}
                            </div>
                          )}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {editMode ? (
                            <div className="flex items-center">
                              <span className="text-gray-500 mr-2">$</span>
                              <input
                                type="number"
                                value={periodLimits.cumulative}
                                onChange={(e) => updateLimit(channel, period, 'cumulative', e.target.value)}
                                className="input w-32"
                              />
                            </div>
                          ) : (
                            <div className="flex items-center text-sm text-gray-900">
                              <CurrencyDollarIcon className="h-4 w-4 text-gray-400 mr-1" />
                              {periodLimits.cumulative.toLocaleString()}
                            </div>
                          )}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {editMode ? (
                            <div className="flex items-center">
                              <span className="text-gray-500 mr-2">$</span>
                              <input
                                type="number"
                                value={periodLimits.threshold}
                                onChange={(e) => updateLimit(channel, period, 'threshold', e.target.value)}
                                className="input w-32"
                              />
                            </div>
                          ) : (
                            <div className="flex items-center text-sm text-gray-900">
                              <CurrencyDollarIcon className="h-4 w-4 text-gray-400 mr-1" />
                              {periodLimits.threshold.toLocaleString()}
                            </div>
                          )}
                        </td>
                        <td className="px-6 py-4 whitespace-nowrap">
                          {isNearThreshold ? (
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                              <ExclamationTriangleIcon className="h-3 w-3 mr-1" />
                              Near Limit
                            </span>
                          ) : (
                            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                              <CheckCircleIcon className="h-3 w-3 mr-1" />
                              Normal
                            </span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          </div>
        );
      })}

      {/* Recent Changes */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">Recent Limit Changes</h3>
        <div className="space-y-3">
          <div className="flex items-center justify-between py-2 border-b border-gray-100">
            <div>
              <p className="text-sm font-medium text-gray-900">Cash Daily Limit Increased</p>
              <p className="text-sm text-gray-500">Changed from $8,000 to $10,000</p>
            </div>
            <div className="text-right">
              <p className="text-sm text-gray-500">Jan 10, 2024</p>
              <p className="text-xs text-gray-400">by Admin</p>
            </div>
          </div>
          <div className="flex items-center justify-between py-2 border-b border-gray-100">
            <div>
              <p className="text-sm font-medium text-gray-900">Wire Monthly Threshold Adjusted</p>
              <p className="text-sm text-gray-500">Changed from $350,000 to $400,000</p>
            </div>
            <div className="text-right">
              <p className="text-sm text-gray-500">Jan 8, 2024</p>
              <p className="text-xs text-gray-400">by System</p>
            </div>
          </div>
          <div className="flex items-center justify-between py-2">
            <div>
              <p className="text-sm font-medium text-gray-900">Mobile Limits Updated</p>
              <p className="text-sm text-gray-500">All mobile transaction limits revised</p>
            </div>
            <div className="text-right">
              <p className="text-sm text-gray-500">Jan 5, 2024</p>
              <p className="text-xs text-gray-400">by Compliance</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
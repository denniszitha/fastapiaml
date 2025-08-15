import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { exemptionsAPI } from '../services/api';
import toast from 'react-hot-toast';
import {
  ShieldCheckIcon,
  PlusIcon,
  TrashIcon,
  MagnifyingGlassIcon,
  CalendarIcon,
  ClockIcon,
  UserIcon,
  DocumentTextIcon,
  ExclamationTriangleIcon,
  CheckCircleIcon,
  XCircleIcon,
  ArrowPathIcon,
} from '@heroicons/react/24/outline';

const exemptionTypes = {
  'temporary': 'bg-yellow-100 text-yellow-800',
  'permanent': 'bg-green-100 text-green-800',
  'conditional': 'bg-blue-100 text-blue-800',
  'review': 'bg-purple-100 text-purple-800',
};

export default function Exemptions() {
  const [searchTerm, setSearchTerm] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);
  const [typeFilter, setTypeFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('active');
  const queryClient = useQueryClient();

  const [formData, setFormData] = useState({
    account_number: '',
    exemption_type: 'temporary',
    reason: '',
    start_date: new Date().toISOString().split('T')[0],
    end_date: '',
    approved_by: 'Admin',
    conditions: '',
  });

  // Mock data for demonstration
  const mockExemptions = [
    {
      id: 1,
      account_number: 'ACC-2024-0045',
      account_name: 'Government Agency ABC',
      exemption_type: 'permanent',
      reason: 'Government entity - regulatory reporting exemption',
      start_date: '2024-01-01',
      end_date: null,
      is_active: true,
      approved_by: 'John Doe',
      created_at: '2024-01-01T09:00:00',
      conditions: 'Monthly compliance review required',
      used_count: 45,
    },
    {
      id: 2,
      account_number: 'ACC-2024-0089',
      account_name: 'Charity Foundation XYZ',
      exemption_type: 'temporary',
      reason: 'Registered charity - fundraising campaign exemption',
      start_date: '2024-01-10',
      end_date: '2024-03-31',
      is_active: true,
      approved_by: 'Jane Smith',
      created_at: '2024-01-09T14:30:00',
      conditions: 'Maximum transaction amount: $100,000',
      used_count: 23,
    },
    {
      id: 3,
      account_number: 'ACC-2024-0156',
      account_name: 'Embassy of Country X',
      exemption_type: 'permanent',
      reason: 'Diplomatic immunity - embassy operations',
      start_date: '2023-06-15',
      end_date: null,
      is_active: true,
      approved_by: 'Mike Johnson',
      created_at: '2023-06-14T10:00:00',
      conditions: 'Quarterly audit required',
      used_count: 128,
    },
    {
      id: 4,
      account_number: 'ACC-2024-0234',
      account_name: 'Medical Research Institute',
      exemption_type: 'conditional',
      reason: 'Research grant transfers - specific project exemption',
      start_date: '2024-01-15',
      end_date: '2024-12-31',
      is_active: true,
      approved_by: 'Sarah Wilson',
      created_at: '2024-01-14T11:45:00',
      conditions: 'Only for transactions with approved research partners',
      used_count: 8,
    },
    {
      id: 5,
      account_number: 'ACC-2024-0091',
      account_name: 'International NGO',
      exemption_type: 'review',
      reason: 'Under review - pending documentation',
      start_date: '2024-01-20',
      end_date: '2024-02-20',
      is_active: false,
      approved_by: 'Tom Anderson',
      created_at: '2024-01-19T16:20:00',
      conditions: 'Awaiting additional compliance documentation',
      used_count: 0,
    },
  ];

  const exemptions = mockExemptions;

  const filteredExemptions = exemptions.filter(exemption => {
    const matchesSearch = 
      exemption.account_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      exemption.account_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      exemption.reason.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesType = 
      typeFilter === 'all' || exemption.exemption_type === typeFilter;
    
    const matchesStatus = 
      (statusFilter === 'active' && exemption.is_active) ||
      (statusFilter === 'inactive' && !exemption.is_active) ||
      (statusFilter === 'expired' && exemption.end_date && new Date(exemption.end_date) < new Date()) ||
      statusFilter === 'all';
    
    return matchesSearch && matchesType && matchesStatus;
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    // In production, this would call the API
    toast.success('Exemption added successfully');
    setShowAddModal(false);
    setFormData({
      account_number: '',
      exemption_type: 'temporary',
      reason: '',
      start_date: new Date().toISOString().split('T')[0],
      end_date: '',
      approved_by: 'Admin',
      conditions: '',
    });
  };

  const handleRemove = (id) => {
    // In production, this would call the API
    toast.success('Exemption removed');
  };

  const stats = {
    total: exemptions.length,
    active: exemptions.filter(e => e.is_active).length,
    expiring: exemptions.filter(e => {
      if (!e.end_date) return false;
      const daysUntilExpiry = Math.ceil((new Date(e.end_date) - new Date()) / (1000 * 60 * 60 * 24));
      return daysUntilExpiry > 0 && daysUntilExpiry <= 30;
    }).length,
    expired: exemptions.filter(e => e.end_date && new Date(e.end_date) < new Date()).length,
  };

  const isExpiringSoon = (endDate) => {
    if (!endDate) return false;
    const daysUntilExpiry = Math.ceil((new Date(endDate) - new Date()) / (1000 * 60 * 60 * 24));
    return daysUntilExpiry > 0 && daysUntilExpiry <= 30;
  };

  const isExpired = (endDate) => {
    if (!endDate) return false;
    return new Date(endDate) < new Date();
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Exemption Management</h1>
          <p className="mt-1 text-sm text-gray-500">
            Manage transaction monitoring exemptions for special accounts
          </p>
        </div>
        <div className="mt-4 sm:mt-0 space-x-3">
          <button className="btn btn-secondary">
            <DocumentTextIcon className="h-4 w-4 mr-2" />
            Export List
          </button>
          <button
            onClick={() => setShowAddModal(true)}
            className="btn btn-primary"
          >
            <PlusIcon className="h-4 w-4 mr-2" />
            Add Exemption
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Exemptions</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.total}</p>
            </div>
            <ShieldCheckIcon className="h-8 w-8 text-blue-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Active</p>
              <p className="text-2xl font-semibold text-green-600">{stats.active}</p>
            </div>
            <CheckCircleIcon className="h-8 w-8 text-green-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Expiring Soon</p>
              <p className="text-2xl font-semibold text-yellow-600">{stats.expiring}</p>
              <p className="text-xs text-gray-500 mt-1">Next 30 days</p>
            </div>
            <ExclamationTriangleIcon className="h-8 w-8 text-yellow-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Expired</p>
              <p className="text-2xl font-semibold text-red-600">{stats.expired}</p>
            </div>
            <XCircleIcon className="h-8 w-8 text-red-500" />
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
        <div className="sm:flex sm:items-center sm:justify-between space-y-3 sm:space-y-0">
          <div className="flex-1 max-w-lg">
            <div className="relative">
              <MagnifyingGlassIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Search accounts, names, or reasons..."
                className="input pl-10"
              />
            </div>
          </div>
          <div className="flex items-center space-x-3">
            <div className="flex items-center space-x-2">
              <label className="text-sm font-medium text-gray-700">Type:</label>
              <select
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
                className="input"
              >
                <option value="all">All Types</option>
                <option value="temporary">Temporary</option>
                <option value="permanent">Permanent</option>
                <option value="conditional">Conditional</option>
                <option value="review">Under Review</option>
              </select>
            </div>
            <div className="flex items-center space-x-2">
              <label className="text-sm font-medium text-gray-700">Status:</label>
              <select
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="input"
              >
                <option value="active">Active</option>
                <option value="inactive">Inactive</option>
                <option value="expired">Expired</option>
                <option value="all">All</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* Exemptions Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Account
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Type
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Reason
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Validity Period
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Conditions
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Usage
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
              {filteredExemptions.length === 0 ? (
                <tr>
                  <td colSpan="8" className="px-6 py-4 text-center text-gray-500">
                    No exemptions found
                  </td>
                </tr>
              ) : (
                filteredExemptions.map((exemption) => (
                  <tr key={exemption.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4">
                      <div>
                        <div className="text-sm font-medium text-gray-900">
                          {exemption.account_number}
                        </div>
                        <div className="text-sm text-gray-500">
                          {exemption.account_name}
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${exemptionTypes[exemption.exemption_type]}`}>
                        {exemption.exemption_type}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900 max-w-xs truncate">
                        {exemption.reason}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm">
                        <div className="flex items-center text-gray-900">
                          <CalendarIcon className="h-4 w-4 mr-1 text-gray-400" />
                          {new Date(exemption.start_date).toLocaleDateString()}
                        </div>
                        {exemption.end_date && (
                          <div className="flex items-center text-gray-500 mt-1">
                            <ClockIcon className="h-4 w-4 mr-1 text-gray-400" />
                            {new Date(exemption.end_date).toLocaleDateString()}
                          </div>
                        )}
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900 max-w-xs truncate">
                        {exemption.conditions}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">
                        {exemption.used_count} times
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      {isExpired(exemption.end_date) ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800">
                          Expired
                        </span>
                      ) : isExpiringSoon(exemption.end_date) ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                          Expiring Soon
                        </span>
                      ) : exemption.is_active ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                          Active
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                          Inactive
                        </span>
                      )}
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={() => handleRemove(exemption.id)}
                        className="text-red-600 hover:text-red-900"
                      >
                        <TrashIcon className="h-5 w-5" />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Exemption Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75" onClick={() => setShowAddModal(false)} />
            
            <div className="relative bg-white rounded-lg max-w-lg w-full p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">
                Add New Exemption
              </h3>
              
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label className="label">Account Number</label>
                  <input
                    type="text"
                    value={formData.account_number}
                    onChange={(e) => setFormData({ ...formData, account_number: e.target.value })}
                    className="input"
                    required
                  />
                </div>
                
                <div>
                  <label className="label">Exemption Type</label>
                  <select
                    value={formData.exemption_type}
                    onChange={(e) => setFormData({ ...formData, exemption_type: e.target.value })}
                    className="input"
                    required
                  >
                    <option value="temporary">Temporary</option>
                    <option value="permanent">Permanent</option>
                    <option value="conditional">Conditional</option>
                    <option value="review">Under Review</option>
                  </select>
                </div>
                
                <div>
                  <label className="label">Reason</label>
                  <textarea
                    value={formData.reason}
                    onChange={(e) => setFormData({ ...formData, reason: e.target.value })}
                    className="input"
                    rows="3"
                    required
                  />
                </div>
                
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="label">Start Date</label>
                    <input
                      type="date"
                      value={formData.start_date}
                      onChange={(e) => setFormData({ ...formData, start_date: e.target.value })}
                      className="input"
                      required
                    />
                  </div>
                  
                  <div>
                    <label className="label">End Date</label>
                    <input
                      type="date"
                      value={formData.end_date}
                      onChange={(e) => setFormData({ ...formData, end_date: e.target.value })}
                      className="input"
                      disabled={formData.exemption_type === 'permanent'}
                    />
                  </div>
                </div>
                
                <div>
                  <label className="label">Conditions (Optional)</label>
                  <textarea
                    value={formData.conditions}
                    onChange={(e) => setFormData({ ...formData, conditions: e.target.value })}
                    className="input"
                    rows="2"
                  />
                </div>
                
                <div className="flex justify-end space-x-3 mt-6">
                  <button
                    type="button"
                    onClick={() => setShowAddModal(false)}
                    className="btn btn-secondary"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="btn btn-primary"
                  >
                    Add Exemption
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
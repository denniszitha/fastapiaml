import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { watchlistAPI } from '../services/api';
import toast from 'react-hot-toast';
import {
  EyeIcon,
  PlusIcon,
  TrashIcon,
  MagnifyingGlassIcon,
  ExclamationTriangleIcon,
  UserIcon,
  CalendarIcon,
  TagIcon,
  DocumentTextIcon,
  CheckCircleIcon,
} from '@heroicons/react/24/outline';

const categoryColors = {
  'high-risk': 'bg-red-100 text-red-800',
  'pep': 'bg-purple-100 text-purple-800',
  'sanctions': 'bg-orange-100 text-orange-800',
  'adverse-media': 'bg-yellow-100 text-yellow-800',
  'internal': 'bg-blue-100 text-blue-800',
  'other': 'bg-gray-100 text-gray-800',
};

export default function Watchlist() {
  const [searchTerm, setSearchTerm] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);
  const [categoryFilter, setCategoryFilter] = useState('all');
  const queryClient = useQueryClient();

  const [formData, setFormData] = useState({
    account_number: '',
    account_name: '',
    reason_for_monitoring: '',
    category: 'high-risk',
    added_by: 'Admin',
  });

  // Fetch watchlist data
  const { data: watchlistData, isLoading } = useQuery({
    queryKey: ['watchlist'],
    queryFn: () => watchlistAPI.getAll({ is_active: true }),
  });

  // Add to watchlist mutation
  const addMutation = useMutation({
    mutationFn: (data) => watchlistAPI.add(data),
    onSuccess: () => {
      toast.success('Account added to watchlist');
      queryClient.invalidateQueries(['watchlist']);
      setShowAddModal(false);
      setFormData({
        account_number: '',
        account_name: '',
        reason_for_monitoring: '',
        category: 'high-risk',
        added_by: 'Admin',
      });
    },
    onError: () => {
      toast.error('Failed to add to watchlist');
    },
  });

  // Remove from watchlist mutation
  const removeMutation = useMutation({
    mutationFn: (accountNumber) => watchlistAPI.remove(accountNumber),
    onSuccess: () => {
      toast.success('Account removed from watchlist');
      queryClient.invalidateQueries(['watchlist']);
    },
    onError: () => {
      toast.error('Failed to remove from watchlist');
    },
  });

  // Mock data for demonstration
  const mockWatchlist = [
    {
      id: 1,
      account_number: 'ACC-2024-0089',
      account_name: 'Suspicious Trading LLC',
      reason_for_monitoring: 'Multiple large cash deposits exceeding reporting thresholds',
      category: 'high-risk',
      added_by: 'John Doe',
      is_active: true,
      created_at: '2024-01-10T10:30:00',
    },
    {
      id: 2,
      account_number: 'ACC-2024-0142',
      account_name: 'International Holdings Corp',
      reason_for_monitoring: 'PEP - Politically Exposed Person connection identified',
      category: 'pep',
      added_by: 'Jane Smith',
      is_active: true,
      created_at: '2024-01-08T14:20:00',
    },
    {
      id: 3,
      account_number: 'ACC-2024-0234',
      account_name: 'Global Ventures Ltd',
      reason_for_monitoring: 'Sanctions list match - subsidiary of sanctioned entity',
      category: 'sanctions',
      added_by: 'Mike Johnson',
      is_active: true,
      created_at: '2024-01-05T09:15:00',
    },
  ];

  const watchlistItems = watchlistData?.data || mockWatchlist;

  const filteredItems = watchlistItems.filter(item => {
    const matchesSearch = 
      item.account_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.account_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      item.reason_for_monitoring.toLowerCase().includes(searchTerm.toLowerCase());
    
    const matchesCategory = 
      categoryFilter === 'all' || item.category === categoryFilter;
    
    return matchesSearch && matchesCategory;
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    addMutation.mutate(formData);
  };

  const stats = {
    total: watchlistItems.length,
    highRisk: watchlistItems.filter(i => i.category === 'high-risk').length,
    pep: watchlistItems.filter(i => i.category === 'pep').length,
    sanctions: watchlistItems.filter(i => i.category === 'sanctions').length,
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Watchlist Management</h1>
          <p className="mt-1 text-sm text-gray-500">
            Monitor high-risk accounts and entities requiring enhanced due diligence
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
            Add to Watchlist
          </button>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total Monitored</p>
              <p className="text-2xl font-semibold text-gray-900">{stats.total}</p>
            </div>
            <EyeIcon className="h-8 w-8 text-blue-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">High Risk</p>
              <p className="text-2xl font-semibold text-red-600">{stats.highRisk}</p>
            </div>
            <ExclamationTriangleIcon className="h-8 w-8 text-red-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">PEP</p>
              <p className="text-2xl font-semibold text-purple-600">{stats.pep}</p>
            </div>
            <UserIcon className="h-8 w-8 text-purple-500" />
          </div>
        </div>
        <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Sanctions</p>
              <p className="text-2xl font-semibold text-orange-600">{stats.sanctions}</p>
            </div>
            <ExclamationTriangleIcon className="h-8 w-8 text-orange-500" />
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
          <div className="flex items-center space-x-2">
            <label className="text-sm font-medium text-gray-700">Category:</label>
            <select
              value={categoryFilter}
              onChange={(e) => setCategoryFilter(e.target.value)}
              className="input"
            >
              <option value="all">All Categories</option>
              <option value="high-risk">High Risk</option>
              <option value="pep">PEP</option>
              <option value="sanctions">Sanctions</option>
              <option value="adverse-media">Adverse Media</option>
              <option value="internal">Internal</option>
              <option value="other">Other</option>
            </select>
          </div>
        </div>
      </div>

      {/* Watchlist Table */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Account
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Name
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Category
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Reason for Monitoring
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Added By
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Date Added
                </th>
                <th className="relative px-6 py-3">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {isLoading ? (
                <tr>
                  <td colSpan="7" className="px-6 py-4 text-center text-gray-500">
                    Loading watchlist...
                  </td>
                </tr>
              ) : filteredItems.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-4 text-center text-gray-500">
                    No watchlist entries found
                  </td>
                </tr>
              ) : (
                filteredItems.map((item) => (
                  <tr key={item.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <EyeIcon className="h-5 w-5 text-yellow-500 mr-2" />
                        <span className="text-sm font-medium text-gray-900">
                          {item.account_number}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900">{item.account_name}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${categoryColors[item.category] || categoryColors['other']}`}>
                        {item.category}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900 max-w-xs truncate">
                        {item.reason_for_monitoring}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{item.added_by}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center text-sm text-gray-500">
                        <CalendarIcon className="h-4 w-4 mr-1 text-gray-400" />
                        {new Date(item.created_at).toLocaleDateString()}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={() => removeMutation.mutate(item.account_number)}
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

      {/* Add to Watchlist Modal */}
      {showAddModal && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75" onClick={() => setShowAddModal(false)} />
            
            <div className="relative bg-white rounded-lg max-w-lg w-full p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">
                Add Account to Watchlist
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
                  <label className="label">Account Name</label>
                  <input
                    type="text"
                    value={formData.account_name}
                    onChange={(e) => setFormData({ ...formData, account_name: e.target.value })}
                    className="input"
                  />
                </div>
                
                <div>
                  <label className="label">Category</label>
                  <select
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                    className="input"
                    required
                  >
                    <option value="high-risk">High Risk</option>
                    <option value="pep">PEP</option>
                    <option value="sanctions">Sanctions</option>
                    <option value="adverse-media">Adverse Media</option>
                    <option value="internal">Internal</option>
                    <option value="other">Other</option>
                  </select>
                </div>
                
                <div>
                  <label className="label">Reason for Monitoring</label>
                  <textarea
                    value={formData.reason_for_monitoring}
                    onChange={(e) => setFormData({ ...formData, reason_for_monitoring: e.target.value })}
                    className="input"
                    rows="3"
                    required
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
                    Add to Watchlist
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
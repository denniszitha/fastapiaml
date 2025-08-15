import React, { useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';
import { suspiciousCasesAPI } from '../services/api';
import { 
  ExclamationTriangleIcon, 
  MagnifyingGlassIcon, 
  FunnelIcon,
  DocumentTextIcon,
  ChevronRightIcon 
} from '@heroicons/react/24/outline';
import toast from 'react-hot-toast';

const statusColors = {
  suspicious: 'bg-yellow-100 text-yellow-800',
  'not compliant': 'bg-red-100 text-red-800',
  pending: 'bg-gray-100 text-gray-800',
  reviewed: 'bg-green-100 text-green-800',
  escalated: 'bg-purple-100 text-purple-800',
};

export default function SuspiciousCases() {
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedCase, setSelectedCase] = useState(null);

  const { data: cases, isLoading, refetch } = useQuery({
    queryKey: ['suspicious-cases', statusFilter],
    queryFn: () => suspiciousCasesAPI.getAll({ 
      status: statusFilter === 'all' ? undefined : statusFilter 
    }),
  });

  const handleStatusUpdate = async (caseNumber, newStatus) => {
    try {
      await suspiciousCasesAPI.updateStatus(caseNumber, newStatus);
      toast.success('Case status updated successfully');
      refetch();
    } catch (error) {
      toast.error('Failed to update case status');
    }
  };

  const casesData = Array.isArray(cases?.data) ? cases.data : [];
  
  const filteredCases = casesData.filter(case_ => {
    const searchLower = searchTerm.toLowerCase();
    return (
      (case_.case_number || '').toLowerCase().includes(searchLower) ||
      (case_.acct_no || '').toLowerCase().includes(searchLower) ||
      (case_.acct_name || '').toLowerCase().includes(searchLower)
    );
  });

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="sm:flex sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Suspicious Cases</h1>
          <p className="mt-1 text-sm text-gray-500">
            Monitor and investigate flagged transactions requiring review
          </p>
        </div>
        <div className="mt-4 sm:mt-0">
          <button className="btn btn-primary">
            <DocumentTextIcon className="h-4 w-4 mr-2" />
            Generate STR Report
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="card p-4">
        <div className="sm:flex sm:items-center sm:justify-between space-y-3 sm:space-y-0">
          {/* Search */}
          <div className="flex-1 max-w-lg">
            <div className="relative">
              <MagnifyingGlassIcon className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
              <input
                type="text"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                placeholder="Search by case number, account number, or name..."
                className="input pl-10"
              />
            </div>
          </div>

          {/* Status Filter */}
          <div className="flex items-center space-x-2">
            <FunnelIcon className="h-5 w-5 text-gray-400" />
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="input"
            >
              <option value="all">All Status</option>
              <option value="suspicious">Suspicious</option>
              <option value="not compliant">Not Compliant</option>
              <option value="pending">Pending</option>
              <option value="reviewed">Reviewed</option>
              <option value="escalated">Escalated</option>
            </select>
          </div>
        </div>
      </div>

      {/* Cases List */}
      <div className="card overflow-hidden">
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Case Number
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Account
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Transaction
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Amount
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Risk Score
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Status
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Flagging Reason
                </th>
                <th className="relative px-6 py-3">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {isLoading ? (
                <tr>
                  <td colSpan="8" className="px-6 py-4 text-center text-gray-500">
                    Loading cases...
                  </td>
                </tr>
              ) : filteredCases.length === 0 ? (
                <tr>
                  <td colSpan="8" className="px-6 py-4 text-center text-gray-500">
                    No suspicious cases found
                  </td>
                </tr>
              ) : (
                filteredCases.map((case_) => (
                  <tr key={case_.id} className="hover:bg-gray-50">
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <ExclamationTriangleIcon className="h-5 w-5 text-yellow-500 mr-2" />
                        <span className="text-sm font-medium text-gray-900">
                          {case_.case_number || `CASE-${case_.id}`}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900">{case_.acct_no}</div>
                      <div className="text-sm text-gray-500">{case_.acct_name}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-900">{case_.transaction_ref || 'N/A'}</div>
                      <div className="text-sm text-gray-500">
                        {new Date(case_.created_at).toLocaleDateString()}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">
                        ${case_.amount?.toLocaleString()}
                      </div>
                      <div className="text-sm text-gray-500">{case_.currency}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="flex items-center">
                        <div className="w-16 bg-gray-200 rounded-full h-2">
                          <div 
                            className={`h-2 rounded-full ${
                              case_.risk_score > 75 ? 'bg-red-500' :
                              case_.risk_score > 50 ? 'bg-yellow-500' :
                              case_.risk_score > 25 ? 'bg-blue-500' : 'bg-green-500'
                            }`}
                            style={{ width: `${case_.risk_score}%` }}
                          />
                        </div>
                        <span className="ml-2 text-sm text-gray-900">
                          {case_.risk_score || 0}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${statusColors[case_.status]}`}>
                        {case_.status}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <div className="text-sm text-gray-900 max-w-xs truncate">
                        {case_.flagging_reason}
                      </div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={() => setSelectedCase(case_)}
                        className="text-primary-600 hover:text-primary-900"
                      >
                        Review
                        <ChevronRightIcon className="inline h-4 w-4 ml-1" />
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Case Detail Modal */}
      {selectedCase && (
        <div className="fixed inset-0 z-50 overflow-y-auto">
          <div className="flex items-center justify-center min-h-screen px-4">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75" onClick={() => setSelectedCase(null)} />
            
            <div className="relative bg-white rounded-lg max-w-3xl w-full p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">
                Case Details: {selectedCase.case_number || `CASE-${selectedCase.id}`}
              </h3>
              
              <div className="grid grid-cols-2 gap-4 mb-6">
                <div>
                  <p className="text-sm font-medium text-gray-500">Account</p>
                  <p className="mt-1 text-sm text-gray-900">
                    {selectedCase.acct_no} - {selectedCase.acct_name}
                  </p>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500">Transaction</p>
                  <p className="mt-1 text-sm text-gray-900">
                    {selectedCase.transaction_ref || 'N/A'}
                  </p>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500">Amount</p>
                  <p className="mt-1 text-sm text-gray-900">
                    {selectedCase.currency} ${selectedCase.amount?.toLocaleString()}
                  </p>
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500">Date</p>
                  <p className="mt-1 text-sm text-gray-900">
                    {new Date(selectedCase.transaction_date).toLocaleString()}
                  </p>
                </div>
                <div className="col-span-2">
                  <p className="text-sm font-medium text-gray-500">Flagging Reason</p>
                  <p className="mt-1 text-sm text-gray-900">
                    {selectedCase.flagging_reason}
                  </p>
                </div>
              </div>

              <div className="flex justify-between">
                <select
                  value={selectedCase.status}
                  onChange={(e) => {
                    handleStatusUpdate(selectedCase.case_number, e.target.value);
                    setSelectedCase(null);
                  }}
                  className="input"
                >
                  <option value="suspicious">Suspicious</option>
                  <option value="not compliant">Not Compliant</option>
                  <option value="pending">Pending</option>
                  <option value="reviewed">Reviewed</option>
                  <option value="escalated">Escalated</option>
                </select>

                <div className="space-x-3">
                  <button
                    onClick={() => setSelectedCase(null)}
                    className="btn btn-secondary"
                  >
                    Close
                  </button>
                  <button className="btn btn-primary">
                    Generate STR
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